//
//  VideoCaptureController.swift
//  face-it
//
//  Created by Derek Andre on 4/21/16.
//  Copyright © 2016 Derek Andre. All rights reserved.
//

import Foundation
import GLKit
import UIKit

class VideoCaptureController: UIViewController, VideoCaptureDelegate {
    @IBOutlet weak var statusLabel: UILabel!

    let eaglContext = EAGLContext(api: .openGLES2)!
    var videoCapture: VideoCapture?
    fileprivate var latestImage: CIImage?

    var imageView: GLKView?

    lazy var ciContext: CIContext = { [unowned self] in
        return CIContext(eaglContext: self.eaglContext)
    }()
    
    override func viewDidLoad() {
        imageView = GLKView(frame: view.bounds, context: eaglContext)
        imageView?.delegate = self
        view.addSubview(imageView!)
        videoCapture = VideoCapture()
        videoCapture?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        statusLabel.layer.zPosition = 1
        startCapturing()
    }
    
    override func didReceiveMemoryWarning() {
        stopCapturing()
    }
    
    func startCapturing() {
        do {
            try videoCapture!.startCapturing(self.view)
        }
        catch let ex {
            NSLog("Unable to start capturing \(ex)")
        }
    }
    
    func stopCapturing() {
        videoCapture!.stopCapturing()
    }
    
    @IBAction func touchUp(_ sender: AnyObject) {
        let button = sender as! UIButton
        if videoCapture!.isCapturing {
            button.setTitle("Start", for: .normal)
            stopCapturing()
        } else {
            button.setTitle("Stop", for: .normal)
            startCapturing()
        }
    }

    // MARK - VideoCaptureDelegate

    func captureDidFindFace(_ videoCapture: VideoCapture) {
        statusLabel.text = " Found a face! "
    }

    func captureDidLoseFace(_ videoCapture: VideoCapture) {
        statusLabel.text = " Looking . . . "
    }

    func captureDidGenerateFrame(_ image: CIImage) {
        latestImage = image
        imageView?.setNeedsDisplay()
    }
}

extension VideoCaptureController: GLKViewDelegate {
    func glkView(_ view: GLKView, drawIn rect: CGRect) {
        guard let latestImage = latestImage else { return }
        ciContext.draw(latestImage, in: CGRect(x: 0, y: 0, width: view.drawableWidth, height: view.drawableHeight), from: latestImage.extent)
    }
}
