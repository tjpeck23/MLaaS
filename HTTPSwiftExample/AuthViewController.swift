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
    var featureImage: UIImage? // Store the captured image
    var label: String = "DefaultLabel" // Define a label for the image

    override func viewDidLoad() {
            super.viewDidLoad()
            setupCamera()
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
                self.featureImage = uiImage // Update featureImage with the captured frame
            }
        }
        
        func startTimer() {
            timer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateTask), userInfo: nil, repeats: true)
        }
        
        @objc func updateTask() {
            guard let image = self.featureImage else {
                print("No image captured yet")
                return
            }
            
            DispatchQueue.main.async {
                // Pass the image and label to the MlaasModel method
                self.mlaasmodel.uploadMultipleImagesWithLabel(images: [image], label: self.label)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.receivedText != self.mlaasmodel.pred {
                        print(self.receivedText, " is not ", "\(self.mlaasmodel.pred)!")
                        self.resetApp()
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
        
        detectedFaces.removeAll() // Clear previous results
        
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
    
    // Process individual face observations
    func processFace(observation: VNFaceObservation, pixelBuffer: CVPixelBuffer, index: Int) {
        // Convert the pixel buffer to a CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let size = ciImage.extent.size

        // Calculate the face bounding box in image coordinates
        let x = observation.boundingBox.origin.x * size.width
        let y = (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * size.height
        let width = observation.boundingBox.width * size.width
        let height = observation.boundingBox.height * size.height

        let faceRect = CGRect(x: x, y: y, width: width, height: height).integral

        // Crop and process the face region
        let croppedFace = ciImage.cropped(to: faceRect)
        let faceImage = UIImage(ciImage: croppedFace)
        //sendFaceToServer(image: faceImage, faceIndex: Travis)
        
    }
    
    // Send the cropped face to the server
    private func sendFaceToServer(image: UIImage, faceIndex: Int) {
        let label = "Face \(faceIndex + 1)"
        mlaasmodel.uploadImageWithLabel(images: [image], label: label)
        detectedFaces.append(label)
    }
    
    // Update the UI with detected faces
    private func updateUIWithDetectedFaces() {
        
        // Add UI updates here, such as updating a label or table view
    }
    

}
