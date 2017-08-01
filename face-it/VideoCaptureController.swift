//
//  VideoCaptureController.swift
//  face-it
//
//  Created by Derek Andre on 4/21/16.
//  Copyright © 2016 Derek Andre. All rights reserved.
//

import Foundation
import UIKit

class VideoCaptureController: UIViewController, VideoCaptureDelegate {
    @IBOutlet weak var statusLabel: UILabel!

    var videoCapture: VideoCapture?
    
    override func viewDidLoad() {
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
}
