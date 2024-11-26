//
//  MlaasModel.swift
//  HTTPSwiftExample
//
//  Created by Travis Peck on 11/25/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import Foundation
import UIKit
import CoreML
import Vision

protocol ClientDelegate {
    func updateDsid(_ dsid:Int)
    func receivedPrediction(_ prediction:[String:Any])
}

enum RequestEnum:String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}


// We can put methods here to convert photo to feature data and send to the server

class MlaasModel: NSObject, URLSessionDelegate {
    
    private let operationQueue = OperationQueue()
    var server_ip:String = "127.0.0.1"
    private var  dsid:Int = 3
    var delegate:ClientDelegate?
    
    // public access methods
    func updateDsid(_ newDsid:Int){
        dsid = newDsid
    }
    func getDsid()->(Int){
        return dsid
    }
    
    private let session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 10
        return URLSession(configuration: sessionConfig)
    }()
    
    func sendData(_ array:[Double], withLabel label:String) {
        let baseURL = "http://\(server_ip):8000/labeled_data/"
        let postURL = URL(string: "\(baseURL)")
        
        var request = URLRequest(url: postURL!)
        
        let requestBody:Data = try! JSONSerialization.data(withJSONObject:
                                                            ["feature": array,
                                                             "label":"\(label)",
                                                             "dsid": self.dsid])
        
        request.httpMethod = "POST"
        request.setValue("applicataion/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler: {(data, response, error) in
            if(error != nil) {
                if let res = response {
                    print("Response: \(res)")
                }
            }
            else {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                print(jsonDictionary["feature"]!)
                print(jsonDictionary["label"]!)
            }
        })
        postTask.resume()
    }
    
    func sendData(_ array:[Double]){
        let baseURL = "http://\(server_ip):8000/predict_turi/"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // utility method to use from below
        let requestBody:Data = try! JSONSerialization.data(withJSONObject: ["feature":array,
            "dsid":self.dsid])
        
        // The Type of the request is given here
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                        completionHandler:{(data, response, error) in
            
            if(error != nil){
                print("Error from server")
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                
                if let delegate = self.delegate {
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    delegate.receivedPrediction(jsonDictionary as! [String : Any])
                }
            }
        })
        
        postTask.resume() // start the task
    }
    
    func getNewDsid(){
        let baseURL = "http://\(server_ip):8000/max_dsid/"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let getTask : URLSessionDataTask = self.session.dataTask(with: request,
                        completionHandler:{(data, response, error) in
            
            let jsonDictionary = self.convertDataToDictionary(with: data)
                            
            if let delegate = self.delegate,
                let resp=response,
                let dsid = jsonDictionary["dsid"] as? Int {
                // tell delegate to update interface for the Dsid
                self.dsid = dsid+1
                delegate.updateDsid(self.dsid)
                
                print(resp)
            }

        })
        
        getTask.resume() // start the task
        
    }
    
    // Converts image to pixel buffer
    /*func preprocessImage(_ image: UIImage, targetSize: CGSize=CGSize(width:224, height:224)) -> CVPixelBuffer? {
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = resizedImage?.cgImage else {
            print("Could not convert image to cgimage")
            return nil}
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelBuffer: CVPixelBuffer?
        
        CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        
        guard let buffer = pixelBuffer else {
            print("Could not convert image to pixel buffer")
            return nil}
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        context.render(ciImage, to: buffer, bounds: CGRect(x: 0, y:0, width: targetSize.width, height: targetSize.height), colorSpace: colorSpace)
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        return buffer
    }*/
    func preprocessImage(_ image: UIImage, targetSize: CGSize = CGSize(width: 224, height: 224)) -> CVPixelBuffer? {
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = resizedImage?.cgImage else {
            print("Could not convert image to CGImage")
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixelBuffer: CVPixelBuffer?

        // Create the pixel buffer with the appropriate dimensions and color format
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(targetSize.width),
                                         Int(targetSize.height),
                                         kCVPixelFormatType_32ARGB,
                                         nil,
                                         &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Could not convert image to pixel buffer")
            return nil
        }

        // Lock the buffer base address for read-only access
        CVPixelBufferLockBaseAddress(buffer, .readOnly)

        // Render the CIImage into the pixel buffer
        context.render(ciImage, to: buffer, bounds: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height), colorSpace: colorSpace)

        // Unlock the base address after rendering
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)

        return buffer
    }
    
    func pixelBufferToDoubleArray(pixelBuffer: CVPixelBuffer) -> [Double]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Get the raw pixel data as an array of bytes
        let bufferPointer = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        var doubleArray: [Double] = []
        
        for row in 0..<height {
            for col in 0..<width {
                let offset = row * bytesPerRow + col * 4  // Assuming ARGB (4 bytes per pixel)
                
                // Get the ARGB values from the pixel buffer
                let blue = Double(bufferPointer[offset])
                let green = Double(bufferPointer[offset + 1])
                let red = Double(bufferPointer[offset + 2])
                let alpha = Double(bufferPointer[offset + 3])
                
                // Add the ARGB values to the array (or use any other logic you need)
                doubleArray.append(contentsOf: [red, green, blue, alpha])
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        return doubleArray
    }


    
    
    // Extracing feature vectors with CoreML MobileNetV2
    /* func extractFeatureVector(from image: UIImage) -> [Double]? {
        guard let pixelBuffer = preprocessImage(image) else {
            print("Error: could not extract features")
            return nil}
        
        guard let featureModel = try? MobileNetV2(configuration: MLModelConfiguration()) else{
            print("Failed to load MobileNetV2 model")
            return nil
        }
        
        
        do {
            let prediction = try featureModel.prediction(image: pixelBuffer)
            print("Model Description: \(featureModel.model.modelDescription)")


            // This is where the error is happening
            if let featureArray = prediction.featureValue(for: "feature")?.multiArrayValue {
                print(featureArray.toDoubleArray())
                return featureArray.toDoubleArray()
            } else {
                print("Could not get feature vector from model")
                return nil
            }
        } catch {
            print("Error during feature extraction: \(error)")
            return nil
        }
        
    }
    */
    
    // Function that combines our preprocessing functions and sends to server
    func uploadImageWithLabel(image: UIImage, label: String, server_ip: String) {
        
        
        guard let pixelBuffer = preprocessImage(image) else {
                print("Error: Could not preprocess image")
                return
            }

            // Convert pixel buffer to an array of doubles
        guard let dataVector = pixelBufferToDoubleArray(pixelBuffer: pixelBuffer) else {
                print("Error: Could not convert pixel buffer to data vector")
                return
            }
        
        
        let dataToSend = [
            "features": dataVector,
            "label": label
        ] as [String : Any]
        
        
        if !label.isEmpty {
                // If label exists, send data with label
                sendData(dataVector, withLabel: label)
            } else {
                // If no label, send data without label
                sendData(dataVector)
            }
    }
    
    
    //MARK: These are older methods below. Not sure if we will use them. Getdata seems more intuitive to me - Travis
    
    func sendGetRequest(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
            let dataTask = session.dataTask(with: request) { data, response, error in
                completion(data, response, error)
            }
            dataTask.resume()
    }
    
    func sendPostRequest(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
            let postTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
                completion(data, response, error)
            }
        postTask.resume()
    }
    
    func sendPostWithJsonInBody(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
            let postTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
                completion(data, response, error)
        }
        postTask.resume()
    }
     
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // adding convert data to dictionary
    func convertDataToDictionary(with data:Data?)->NSDictionary {
        do {
            let jsonDictionary: NSDictionary = try
            JSONSerialization.jsonObject(with: data!, options: JSONSerialization
                .ReadingOptions
                .mutableContainers) as!
                NSDictionary
            return jsonDictionary
        } catch {
            print("json error: \(error.localizedDescription)")
            return NSDictionary()
        }
    }
}

extension MLMultiArray {
    func toDoubleArray() -> [Double]? {
        let count = self.count
        var doubleArray = [Double](repeating: 0.0, count: count)
        for i in 0..<count {
            doubleArray[i] = self[i].doubleValue
        }
        return doubleArray
    }
}
