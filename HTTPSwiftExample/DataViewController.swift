//
//  DataViewController.swift
//  HTTPSwiftExample
//
//  Created by Travis Peck on 11/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class DataViewController: UIViewController, PredictionDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    @IBOutlet weak var ipOutlet: UITextField!
    @IBOutlet weak var dataLabelOutlet: UITextField!
    @IBOutlet weak var predictLabel: UILabel!
    
    let mlaasmodel = MlaasModel()
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var featureImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        // Do any additional setup after loading the view.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.view.addGestureRecognizer(tapGesture)
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
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
            self.mlaasmodel.uploadImageWithLabel(image: uiImage, label: "", modelType: "KNN")
        }
    }
    
    @IBAction func sendDataButton(_ sender: Any) {
        
        guard let selectedImage = featureImage
            else {
            print("No image selected")
            return
        }
        
        let vector = selectedImage
        
        //let userip = ipOutlet.text ?? ""
        let label = dataLabelOutlet.text ?? ""
        
        mlaasmodel.uploadImageWithLabel(image: vector, label: label, modelType: "KNN")
        
        
    }
    @IBAction func trainButton(_ sender: UIButton) {
        mlaasmodel.trainModel()
    }
    
    
    @objc func dismissKeyboard() {
        // Resign first responder on the text fields to dismiss the keyboard
        ipOutlet.resignFirstResponder()
        dataLabelOutlet.resignFirstResponder()
    }
    
    func updateLabel(with text: String) {
        DispatchQueue.main.async {
            self.predictLabel.text = text
        }
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
