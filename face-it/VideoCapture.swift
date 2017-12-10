//
//  VideoCapture.swift
//  face-it
//
//  Created by Derek Andre on 4/21/16.
//  Copyright © 2016 Derek Andre. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import CoreMotion
import ImageIO

protocol VideoCaptureDelegate: class {
    func captureDidFindFace(_ videoCapture: VideoCapture)
    func captureDidLoseFace(_ videoCapture: VideoCapture)
    func captureDidGenerateFrame(_ image: CIImage)
}

class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var isCapturing: Bool = false
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureInput?
    weak var delegate: VideoCaptureDelegate?
    var faceDetector: FaceDetector?
    var dataOutput: AVCaptureVideoDataOutput?
    var dataOutputQueue: DispatchQueue?

    enum VideoCaptureError: Error {
        case sessionPresetNotAvailable
        case inputDeviceNotAvailable
        case inputCouldNotBeAddedToSession
        case dataOutputCouldNotBeAddedToSession
    }
    
    override init() {
        super.init()
        
        device = VideoCaptureDevice.create()
        
        faceDetector = FaceDetector()
    }

    fileprivate lazy var heartImage: CIImage = {
        return CIImage(image: #imageLiteral(resourceName: "heart"))!
    }()
    
    fileprivate func setSessionPreset() throws {
        if (session!.canSetSessionPreset(AVCaptureSessionPresetPhoto)) {
            session!.sessionPreset = AVCaptureSessionPresetPhoto
        }
        else {
            throw VideoCaptureError.sessionPresetNotAvailable
        }
    }
    
    fileprivate func setDeviceInput() throws {
        do {
            self.input = try AVCaptureDeviceInput(device: self.device)
        }
        catch {
            throw VideoCaptureError.inputDeviceNotAvailable
        }
    }
    
    fileprivate func addInputToSession() throws {
        if (session!.canAddInput(self.input)) {
            session!.addInput(self.input)
        }
        else {
            throw VideoCaptureError.inputCouldNotBeAddedToSession
        }
    }

    fileprivate func stopSession() {
        if let runningSession = session {
            runningSession.stopRunning()
        }
    }
    
    fileprivate func setDataOutput() {
        self.dataOutput = AVCaptureVideoDataOutput()
        
        var videoSettings = [AnyHashable: Any]()
        videoSettings[kCVPixelBufferPixelFormatTypeKey as AnyHashable] = Int(CInt(kCVPixelFormatType_32BGRA))
        
//        self.dataOutput!.videoSettings = videoSettings
//        self.dataOutput!.alwaysDiscardsLateVideoFrames = true
        
        self.dataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue", attributes: [])
        
        self.dataOutput!.setSampleBufferDelegate(self, queue: self.dataOutputQueue!)
    }
    
    fileprivate func addDataOutputToSession() throws {
        if (self.session!.canAddOutput(self.dataOutput!)) {
            self.session!.addOutput(self.dataOutput!)
        }
        else {
            throw VideoCaptureError.dataOutputCouldNotBeAddedToSession
        }
    }
    
    fileprivate func getImageFromBuffer(_ buffer: CMSampleBuffer) -> CIImage {
        let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, buffer, kCMAttachmentMode_ShouldPropagate)
      
        let image = CIImage(cvPixelBuffer: pixelBuffer!, options: attachments as? [String : AnyObject])
        
        return image
    }
    
    fileprivate func getFacialFeaturesFromImage(_ image: CIImage) -> [CIFeature] {
        let imageOptions = [CIDetectorImageOrientation : NSNumber(value: 6)]
        
        return self.faceDetector!.getFacialFeaturesFromImage(image, options: imageOptions)
    }
    
    fileprivate func transformFacialFeature(position: CGPoint, videoRect: CGRect, previewRect: CGRect, isMirrored: Bool) -> CGRect {
    
        var featureRect = CGRect(origin: position, size: CGSize(width: 0, height: 0))
        let widthScale = previewRect.size.width / videoRect.size.height
        let heightScale = previewRect.size.height / videoRect.size.width
        
        let transform = isMirrored ? CGAffineTransform(a: 0, b: heightScale, c: -widthScale, d: 0, tx: previewRect.size.width, ty: 0) :
            CGAffineTransform(a: 0, b: heightScale, c: widthScale, d: 0, tx: 0, ty: 0)
        
        featureRect = featureRect.applying(transform)
        
        featureRect = featureRect.offsetBy(dx: previewRect.origin.x, dy: previewRect.origin.y)
        
        return featureRect
    }

    func modifyImage(base: CIImage?, hasEye: Bool, position: CGPoint) -> CIImage? {
        let halfWidth = heartImage.extent.width / 2
        let halfHeight = heartImage.extent.height / 2

        if hasEye {
            let transform = CGAffineTransform(translationX: position.x - halfWidth, y: position.y - halfHeight)
            let transformFilter = CIFilter(name: "CIAffineTransform")!

            transformFilter.setValue(heartImage, forKey: kCIInputImageKey)
            transformFilter.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)

            if let transformResult = transformFilter.value(forKey: kCIOutputImageKey) as? CIImage {
                let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
                compositeFilter.setValue(transformResult, forKey: kCIInputImageKey)
                compositeFilter.setValue(base, forKey: kCIInputBackgroundImageKey)
                return compositeFilter.value(forKey: kCIOutputImageKey) as? CIImage
            }
        }

        return base
    }

    func updateWithImage(_ image: CIImage?) {
        guard let image = image else { return }
        DispatchQueue.main.async {
            self.delegate?.captureDidGenerateFrame(image)
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {

        connection.videoOrientation = .portrait

        let image = getImageFromBuffer(sampleBuffer)

        let features = getFacialFeaturesFromImage(image)

        if let faceFeature = features.first as? CIFaceFeature {
            DispatchQueue.main.async {
                self.delegate?.captureDidFindFace(self)
            }
            let imageWithLeftEye = modifyImage(base: image, hasEye: faceFeature.hasLeftEyePosition, position: faceFeature.leftEyePosition)
            let imageWithBothEyes = modifyImage(base: imageWithLeftEye, hasEye: faceFeature.hasRightEyePosition, position: faceFeature.rightEyePosition)

            updateWithImage(imageWithBothEyes)
        } else {
            DispatchQueue.main.async {
                self.delegate?.captureDidLoseFace(self)
            }
            updateWithImage(image)
        }
    }
    
    func startCapturing() throws {
        isCapturing = true
        
        self.session = AVCaptureSession()
        
        try setSessionPreset()
        
        try setDeviceInput()
        
        try addInputToSession()
        
        setDataOutput()
        
        try addDataOutputToSession()
        
        session!.startRunning()
    }
    
    func stopCapturing() {
        isCapturing = false
        
        stopSession()

        dataOutput = nil
        dataOutputQueue = nil
        session = nil
    }
}







