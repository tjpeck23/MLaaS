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

class FaceScanViewController: UIViewController, AVCapturePhotoCaptureDelegate  {
    
    // Main view for showing camera content.
    @IBOutlet weak var previewView: UIView?
    
    @IBOutlet weak var capturePhotoButton: UIButton!
    //@IBOutlet weak var gazeSlider: UISlider!
    // AVCapture variables to hold sequence data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    
    var photoDataOutput: AVCapturePhotoOutput?
    
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Layer UI for drawing Vision results
    var rootLayer: CALayer?
    var detectionOverlayLayer: CALayer?
    var detectedFaceRectangleShapeLayer: CAShapeLayer?
    var detectedFaceLandmarksShapeLayer: CAShapeLayer?
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // Left Eye Extrema
    var leftEyeX: (min: CGFloat, max: CGFloat) = (CGFloat.infinity, -CGFloat.infinity)
    var leftEyeY: (min: CGFloat, max: CGFloat) = (CGFloat.infinity, -CGFloat.infinity)
    
    // isBlinking

    var isBlinking: Bool = false
    
    // MARK: UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup video for high resolution, drop frames when busy, and front camera
        self.session = self.setupAVCaptureSession()
        
        // setup the vision objects for (1) detection and (2) tracking
        self.prepareVisionRequest()
        
        // start the capture session and get processing a face!
        self.session?.startRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func takePhoto(_ sender: Any) {
        /*let myShotOrientation = UIDevice.current.orientation.rawValue
        if let photoOutputConnection = self.photoDataOutput!.connection(with: .video) {
                photoOutputConnection.videoOrientation = myShotOrientation
            }*/

        let photoSettings = AVCapturePhotoSettings()
        //photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        self.photoDataOutput?.capturePhoto(with: photoSettings, delegate: self)

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        session?.stopRunning()
        
        guard let data = photo.fileDataRepresentation() else { return }
        let image = UIImage(data: data)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.frame = view.bounds
        
        DispatchQueue.main.async { [weak self] in
            self?.view.addSubview(imageView)
            // Save to the Gallery
            UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
            
            // Recognize text
            //self?.recognizeImage(image!)
        }
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    
    
    // MARK: Performing Vision Requests
    
    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {
        
        self.trackingRequests = []
        
        // create a detection request that processes an image and returns face features
        // completion handler does not run immediately, it is run
        // after a face is detected
        let faceDetectionRequest:VNDetectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: self.faceDetectionCompletionHandler)
        
        // Save this detection request for later processing
        self.detectionRequests = [faceDetectionRequest]
        
        // setup the tracking of a sequence of features from detection
        self.sequenceRequestHandler = VNSequenceRequestHandler()
        

    }
    
    // define behavior for when we detect a face
    func faceDetectionCompletionHandler(request:VNRequest, error: Error?){
        // any errors? If yes, show and try to keep going
        if error != nil {
            print("FaceDetection error: \(String(describing: error)).")
        }
        
        // see if we can get any face features, this will fail if no faces detected
        // try to save the face observations to a results vector
        guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
            let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
        }
        
        if !results.isEmpty{
            print("Initial Face found... setting up tracking.")
            
            
        }
        
        // if we got here, then a face was detected and we have its features saved
        // The above face detection was the most computational part of what we did
        // the remaining tracking only needs the results vector of face features
        // so we can process it in the main queue (because we will us it to update UI)
        DispatchQueue.main.async {
            // Add the face features to the tracking list
            for observation in results {
                let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                // the array starts empty, but this will constantly add to it
                // since on the main queue, there are no race conditions
                // everything is from a single thread
                // once we add this, it kicks off tracking in another function
                self.trackingRequests?.append(faceTrackingRequest)
                
                // NOTE: if the initial face detection is actually not a face,
                // then the app will continually mess up trying to perform tracking
            }
        }
        
    }
    
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    // This is where we get the pixel buffer from the camera and need to
    // generate the vision requests
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        // see if camera has any instrinsic transforms on it
        // if it does, add these to the options for requests
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        // check to see if we can get the pixels for processing, else return
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        // get portrait orientation for UI
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests else {
            print("Tracking request array not setup, aborting.")
            return
        }
        
        
        // check to see if the tracking request is empty (no face currently detected)
        // if it is empty,
        if requests.isEmpty{
            // No tracking object detected, so perform initial detection
            // the initial detection takes some time to perform
            // so we special case it here
            
            self.performInitialDetection(pixelBuffer: pixelBuffer,
                                         exifOrientation: exifOrientation,
                                         requestHandlerOptions: requestHandlerOptions)
            
            return  // just perform the initial request
        }
        
        // if tracking was not empty, it means we have detected a face very recently
        // so no we can process the sequence of tracking face features
        
        self.performTracking(requests: requests,
                             pixelBuffer: pixelBuffer,
                             exifOrientation: exifOrientation)
        
        
        // if there are no valid observations, then this will be empty
        // the function above will empty out all the elements
        // in our tracking if nothing is high confidence in the output
        if let newTrackingRequests = self.trackingRequests {
            
            if newTrackingRequests.isEmpty {
                // Nothing was high enough confidence to track, just abort.
                print("Face object lost, resetting detection...")
                return
            }
            
            self.performLandmarkDetection(newTrackingRequests: newTrackingRequests,
                                          pixelBuffer: pixelBuffer,
                                          exifOrientation: exifOrientation,
                                          requestHandlerOptions: requestHandlerOptions)
            
        }
        
        
    }
    
    // functionality to run the image detection on pixel buffer
    // This is an involved computation, so beware of running too often
    func performInitialDetection(pixelBuffer:CVPixelBuffer, exifOrientation:CGImagePropertyOrientation, requestHandlerOptions:[VNImageOption: AnyObject]) {
        // create request
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: exifOrientation,
                                                        options: requestHandlerOptions)
        
        do {
            if let detectRequests = self.detectionRequests{
                // try to detect face and add it to tracking buffer
                try imageRequestHandler.perform(detectRequests)
            }
        } catch let error as NSError {
            NSLog("Failed to perform FaceRectangleRequest: %@", error)
        }
    }
    
    
    // this function performs all the tracking of the face sequence
    func performTracking(requests:[VNTrackObjectRequest],
                         pixelBuffer:CVPixelBuffer, exifOrientation:CGImagePropertyOrientation)
    {
        do {
            // perform tracking on the pixel buffer, which is
            // less computational than fully detecting a face
            // if a face was not correct initially, this tracking
            //   will also be not great... but it is fast!
            try self.sequenceRequestHandler.perform(requests,
                                                    on: pixelBuffer,
                                                    orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // if there are any tracking results, let's process them here
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            // any valid results in the request?
            // if so, grab the first request
            if let results = trackingRequest.results,
               let observation = results[0] as? VNDetectedObjectObservation {
                
                
                // is this tracking request of high confidence?
                // If it is, then we should add it to processing buffer
                // the threshold is arbitrary. You can adjust to you liking
                if !trackingRequest.isLastFrame {
                    if observation.confidence > 0.3 {
                        trackingRequest.inputObservation = observation
                    }
                    else {
                        
                        // once below thresh, make it last frame
                        // this will stop the processing of tracker
                        trackingRequest.isLastFrame = true
                    }
                    // add to running tally of high confidence observations
                    newTrackingRequests.append(trackingRequest)
                }
                
            }
            
        }
        self.trackingRequests = newTrackingRequests
        
        
    }
    
    func performLandmarkDetection(newTrackingRequests:[VNTrackObjectRequest], pixelBuffer:CVPixelBuffer, exifOrientation:CGImagePropertyOrientation, requestHandlerOptions:[VNImageOption: AnyObject]) {
        // Perform face landmark tracking on detected faces.
        // setup an empty arry for now
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        // Perform landmark detection on tracked faces.
        for trackingRequest in newTrackingRequests {
            
            // create a request for facial landmarks
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: self.landmarksCompletionHandler)
            
            // get tracking result and observation for result
            if let trackingResults = trackingRequest.results,
               let observation = trackingResults[0] as? VNDetectedObjectObservation{
                
                // save the observation info
                let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
                
                // set information for face
                faceLandmarksRequest.inputFaceObservations = [faceObservation]
                
                // Continue to track detected facial landmarks.
                faceLandmarkRequests.append(faceLandmarksRequest)
                
                // setup for performing landmark detection
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                                orientation: exifOrientation,
                                                                options: requestHandlerOptions)
                
                do {
                    // try to find landmarks in face, then display in completion handler
                    try imageRequestHandler.perform(faceLandmarkRequests)
                    
                    // completion handler will now take over and finish the job!
                } catch let error as NSError {
                    NSLog("Failed to perform FaceLandmarkRequest: %@", error)
                }
                
                
            }
        }
    }
    
    
    // Interpret the output of our facial landmark detector
    // this code is called upon succesful completion of landmark detection
    func landmarksCompletionHandler(request:VNRequest, error:Error?){
        
        if error != nil {
            print("FaceLandmarks error: \(String(describing: error)).")
        }
        
        // any landmarks found that we can display? If not, return
        guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
              let results = landmarksRequest.results as? [VNFaceObservation] else {
            return
        }
        

        // Flipped Module Part 1.1, 1.2, 1.3

        // The points of the landmarks are normalized to be resolution independent. By putting the coordinates of the landmarks on a scale of 0.0-1.0, they are easily translatable across various resolutions. The points are normalized to the dimensions of the face observation's bounding box
        for observation in results {
            if let landmarks = observation.landmarks {
                if let leftEye = landmarks.leftEye {
                    let leftEyePoints = leftEye.normalizedPoints
                    
                    let minX = leftEyePoints.map { $0.x}.min() ?? 0.0
                    let maxX = leftEyePoints.map { $0.x}.max() ?? 0.0
                    let minY = leftEyePoints.map { $0.y}.min() ?? 0.0
                    let maxY = leftEyePoints.map { $0.y}.max() ?? 0.0
                    

                    let currentDiff:CGFloat = maxY-minY

                    
                    // Flipped Module part 2.1
                    
                    // This is the current difference between your left eye's Y max and Y min.

                    print("Current Y Difference: \(currentDiff)")
                    
                    print("Left Eye - Min X: \(minX), Max X: \(maxX), Min Y: \(minY), Max Y: \(maxY)")
                    
                    if minX < leftEyeX.min { leftEyeX.min = minX }
                    if maxX > leftEyeX.max { leftEyeX.max = maxX }
                    if minY < leftEyeY.min { leftEyeY.min = minY }
                    if maxY > leftEyeY.max { leftEyeY.max = maxY }
                    
                    // Global Y axis difference

                    print("Greatest Y Difference: \(leftEyeY.max-leftEyeY.min)")
                    
                    // If the difference is below a finetuned threshold, then set the property isBlinking to true

                    if currentDiff <= 0.038 {
                        self.isBlinking = true
                    }else{
                        self.isBlinking = false
                    }

                    // Printing for debugging and ease of use
                    print("Is Blinking: \(self.isBlinking)")
                    
                }

            }
        }
        
        // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
        DispatchQueue.main.async {

        }
        }
        
        
    }
    
    
    // MARK: Helper Methods
    extension UIViewController{
        
        // Helper Methods for Error Presentation
        
        fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            //self.present(alertController, animated: true)
            self.view.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
        
        fileprivate func presentError(_ error: NSError) {
            self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
        }
        
        // Helper Methods for Handling Device Orientation & EXIF
        
        fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
            return CGFloat(Double(degrees) * Double.pi / 180.0)
        }
        
        func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
            
            switch deviceOrientation {
            case .portraitUpsideDown:
                return .rightMirrored
                
            case .landscapeLeft:
                return .downMirrored
                
            case .landscapeRight:
                return .upMirrored
                
            default:
                return .leftMirrored
            }
        }
        
        func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
            return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
        }
        

    }
    
    
    // MARK: Extension for AVCapture Setup
    extension FaceScanViewController:AVCaptureVideoDataOutputSampleBufferDelegate{
        
        
        /// - Tag: CreateCaptureSession
        fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
            let captureSession = AVCaptureSession()
            do {
                let inputDevice = try self.configureFrontCamera(for: captureSession)
                self.configurePhotoDataOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
                self.designatePreviewLayer(for: captureSession)
                return captureSession
            } catch let executionError as NSError {
                self.presentError(executionError)
            } catch {
                self.presentErrorAlert(message: "An unexpected failure has occured")
            }
            
            self.teardownAVCapture()
            
            return nil
        }
        
        /// - Tag: ConfigureDeviceResolution
        fileprivate func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
            var highestResolutionFormat: AVCaptureDevice.Format? = nil
            var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
            
            for format in device.formats {
                let deviceFormat = format as AVCaptureDevice.Format
                
                let deviceFormatDescription = deviceFormat.formatDescription
                if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                    let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                    if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                        highestResolutionFormat = deviceFormat
                        highestResolutionDimensions = candidateDimensions
                    }
                }
            }
            
            if highestResolutionFormat != nil {
                let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
                return (highestResolutionFormat!, resolution)
            }
            
            return nil
        }
        
        fileprivate func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
            print("got here1")
            if let device = deviceDiscoverySession.devices.first {
                if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                    if captureSession.canAddInput(deviceInput) {
                        captureSession.addInput(deviceInput)
                        print("got here2")
                    }
                    
                    if let highestResolution = self.highestResolution420Format(for: device) {
                        try device.lockForConfiguration()
                        device.activeFormat = highestResolution.format
                        device.unlockForConfiguration()
                        print("got here3")
                        return (device, highestResolution.resolution)
                    }
                }
            }
            
            throw NSError(domain: "ViewController", code: 1, userInfo: nil)
        }
        
        /// - Tag: CreateSerialDispatchQueue
        fileprivate func configurePhotoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
            
            let photoDataOutput = AVCapturePhotoOutput()

            
            if captureSession.canAddOutput(photoDataOutput) {
                captureSession.addOutput(photoDataOutput)
            }
            
            photoDataOutput.connection(with: .video)?.isEnabled = true
            
            if let captureConnection = photoDataOutput.connection(with: AVMediaType.video) {
                if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                    captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
                }
            }
            
            self.photoDataOutput = photoDataOutput
            
            self.captureDevice = inputDevice
            self.captureDeviceResolution = resolution
        }
        
        
        
        /// - Tag: DesignatePreviewLayer
        fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
            let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            self.previewLayer = videoPreviewLayer
            
            videoPreviewLayer.name = "CameraPreview"
            videoPreviewLayer.backgroundColor = UIColor.black.cgColor
            videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            
            if let previewRootLayer = self.previewView?.layer {
                self.rootLayer = previewRootLayer
                
                previewRootLayer.masksToBounds = true
                videoPreviewLayer.frame = previewRootLayer.bounds
                previewRootLayer.addSublayer(videoPreviewLayer)
            }
        }
        
        // Removes infrastructure for AVCapture as part of cleanup.
        fileprivate func teardownAVCapture() {
            self.videoDataOutput = nil
            self.videoDataOutputQueue = nil
            
            if let previewLayer = self.previewLayer {
                previewLayer.removeFromSuperlayer()
                self.previewLayer = nil
            }
        }
    }

    

    




    
