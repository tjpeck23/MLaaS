//
//  AuthViewController.swift
//  HTTPSwiftExample
//
//  Created by Travis Peck on 12/15/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit
import Vision
import AVFoundation


class AuthViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var timer: Timer?
    var receivedText = ""
    let mlaasmodel = MlaasModel()
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var featureImage: [UIImage] = []
    
    var detectedFaces: [String] = []
    var currentPixelBuffer: CVPixelBuffer?
    
    private var detectionRequests: [VNRequest] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        self.prepareVisionRequest()
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
        
        
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Pixel buffer not available")
            return
        }
        
        self.currentPixelBuffer = pixelBuffer
        
        let exifOrientation = CGImagePropertyOrientation.right
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        
        do {
            try imageRequestHandler.perform(detectionRequests)
        } catch {
            print("Failed to perform Vision request: \(error.localizedDescription)")
        }
        
        guard let results = detectionRequests.first?.results as? [VNFaceObservation] else {
            print("no results from face detection")
            return
        }
        
        DispatchQueue.main.async {
            if results.count > 1 {
                exit(0)
            } else if results.isEmpty {
                exit(0)
            }
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let uiImage = UIImage(ciImage: ciImage)
        
        DispatchQueue.main.async {
            self.featureImage = [uiImage]
        }
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateTask), userInfo: nil, repeats: true)
    }
    
    @objc func updateTask() {
        DispatchQueue.main.async {
            self.mlaasmodel.uploadImageWithLabel(images: self.featureImage, label: "")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.receivedText != self.mlaasmodel.pred {
                    print(self.receivedText, " is not ", "\(self.mlaasmodel.pred)!")
                    exit(0)
                }
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func resetApp() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let initialViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "InitialViewController")
            appDelegate.window?.rootViewController = initialViewController
        }
    }
    
    // Prepare Vision request
    fileprivate func prepareVisionRequest() {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            self?.handleFaceDetectionResults(request: request, error: error)
        }
        self.detectionRequests = [faceDetectionRequest]
    }
    
    // Handle Vision face detection results
    private func handleFaceDetectionResults(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNFaceObservation] else {
            print("No faces detected.")
            return
        }
        
        detectedFaces.removeAll() 
        
        for (index, face) in results.enumerated() {
            if let pixelBuffer = self.currentPixelBuffer { // Ensure currentPixelBuffer exists
                processFace(observation: face, pixelBuffer: pixelBuffer, index: index) // Pass pixelBuffer
            } else {
                print("Error: No valid pixel buffer available.")
            }
        }
        
        DispatchQueue.main.async {
            self.updateUIWithDetectedFaces()
        }
    }
    
    
    func processFace(observation: VNFaceObservation, pixelBuffer: CVPixelBuffer, index: Int) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let size = ciImage.extent.size

        
        let x = observation.boundingBox.origin.x * size.width
        let y = (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * size.height
        let width = observation.boundingBox.width * size.width
        let height = observation.boundingBox.height * size.height

        let faceRect = CGRect(x: x, y: y, width: width, height: height).integral

        
        let croppedFace = ciImage.cropped(to: faceRect)
        let faceImage = UIImage(ciImage: croppedFace)
        
    }
    
    private func sendFaceToServer(image: UIImage, faceIndex: Int) {
        let label = "Face \(faceIndex + 1)"
        mlaasmodel.uploadImageWithLabel(images: [image], label: label)
        detectedFaces.append(label)
    }
    
    private func updateUIWithDetectedFaces() {
    }
    

}
