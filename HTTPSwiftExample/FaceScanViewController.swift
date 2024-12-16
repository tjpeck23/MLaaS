//
//  FaceScanViewController.swift
//  HTTPSwiftExample
//
//  Created by Christian Melendez on 11/25/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit
import AVKit
import Vision

class FaceScanViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // Main view for showing camera content
    @IBOutlet weak var previewView: UIView?
    
    let mlaasModel = MlaasModel() // For sending data to the server
    
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var detectedFaces: [String] = [] // Store detected face labels
    var currentPixelBuffer: CVPixelBuffer?
    
    // Vision requests
    private var detectionRequests: [VNRequest] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the camera session
        self.session = self.setupAVCaptureSession()
        self.prepareVisionRequest()
        
        // Start the session
        session?.startRunning()
    }
    
    // Setup camera session
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("Failed to set up video device.")
            return nil
        }
        captureSession.addInput(videoInput)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.layer.bounds
        if let previewLayer = previewLayer {
            previewView?.layer.addSublayer(previewLayer)
        }
        
        return captureSession
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
        sendFaceToServer(image: faceImage, faceIndex: index)
        
    }
    
    // Send the cropped face to the server
    private func sendFaceToServer(image: UIImage, faceIndex: Int) {
        let label = "Face \(faceIndex + 1)"
        mlaasModel.uploadMultipleImagesWithLabel(images: [image], label: label)
        detectedFaces.append(label)
    }
    
    // Update the UI with detected faces
    private func updateUIWithDetectedFaces() {
        print("Detected Faces: \(detectedFaces.joined(separator: ", "))")
        // Add UI updates here, such as updating a label or table view
    }
    
    // Capture video frames and process them
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to retrieve pixel buffer.")
            return
        }
        
        // Save the pixel buffer for other uses if needed
        self.currentPixelBuffer = pixelBuffer
        
        let exifOrientation = CGImagePropertyOrientation.right
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        
        do {
            try imageRequestHandler.perform(detectionRequests)
        } catch {
            print("Failed to perform Vision request: \(error.localizedDescription)")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
    }
}
