//
//  AuthViewController.swift
//  HTTPSwiftExample
//
//  Created by Travis Peck on 12/15/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation


class AuthViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var timer: Timer?
    var receivedText = ""
    let mlaasmodel = MlaasModel()
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var featureImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        // Do any additional setup after loading the view.
        startTimer()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("No camera is available")
            return
        }
        
        let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
        if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Pixel buffer not available")
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let uiImage = UIImage(ciImage: ciImage)
        
        DispatchQueue.main.async {
            self.featureImage = uiImage
        }
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTask), userInfo: nil, repeats: true)
    }
    
    @objc func updateTask() {
        DispatchQueue.main.async {
            //task
            self.mlaasmodel.uploadImageWithLabel(image: self.featureImage!, label: "")
            if self.receivedText != self.mlaasmodel.pred {
                print(self.receivedText, " is not ", "\(self.mlaasmodel.pred)!")
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
