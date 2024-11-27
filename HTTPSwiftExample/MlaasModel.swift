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
    var server_ip:String = "192.168.1.144"
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
    
    func sendData(_ array: [Double], withLabel label: String, modelType: String) {
        let baseURL = "http://\(server_ip):8000/labeled_data/"
        guard let postURL = URL(string: "\(baseURL)") else { return }
        
        var request = URLRequest(url: postURL)
        let requestBody: Data = try! JSONSerialization.data(withJSONObject: [
            "feature": array,
            "label": label,
            "dsid": self.dsid,
            "modelType": modelType
        ])
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        
        let postTask: URLSessionDataTask = self.session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            guard let data = data else { return }
            let jsonDictionary = self.convertDataToDictionary(with: data)
            print(jsonDictionary)
        }
        postTask.resume()
    }
    func trainModel() {
        let baseURL = "http://\(server_ip):8000/train_model_turi/\(dsid)"
        let postUrl = URL(string: "\(baseURL)")
        
        var request = URLRequest(url: postUrl!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = self.session.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error in GET request: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status code: \(httpResponse.statusCode)")
                }
                
                if let data = data {
                    do {
                        // Decode the JSON response
                        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("Training Response: \(jsonResponse)")
                        } else {
                            print("Unable to decode training response")
                        }
                    } catch {
                        print("Error decoding JSON: \(error.localizedDescription)")
                    }
                }
            }
            task.resume()
    }
    
    func sendData(_ array: [Double], modelType: String) {
        let baseURL = "http://\(server_ip):8000/predict_turi/"
        guard let postUrl = URL(string: "\(baseURL)") else { return }
        
        var request = URLRequest(url: postUrl)
        let requestBody: Data = try! JSONSerialization.data(withJSONObject: [
            "feature": array,
            "dsid": self.dsid,
            "modelType": modelType
        ])
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        
        let postTask: URLSessionDataTask = self.session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            guard let data = data else { return }
            if let delegate = self.delegate {
                let jsonDictionary = self.convertDataToDictionary(with: data)
                delegate.receivedPrediction(jsonDictionary as! [String: Any])
            }
        }
        postTask.resume()
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
        
        /*if let pixelArray = pixelBufferToDoubleArray(pixelBuffer: buffer) {
                print("Pixel array: \(pixelArray)")  // This will print the array
            }*/

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

    
    // Function that combines our preprocessing functions and sends to server
    func uploadImageWithLabel(image: UIImage, label: String, server_ip: String, modelType: String) {
        
        
        guard let pixelBuffer = preprocessImage(image) else {
                print("Error: Could not preprocess image")
                return
            }

            // Convert pixel buffer to an array of doubles
        guard let dataVector = pixelBufferToDoubleArray(pixelBuffer: pixelBuffer) else {
                print("Error: Could not convert pixel buffer to data vector")
                return
            }
        
        if dataVector.isEmpty {
            print("Error: Data vector is empty")
            return
        }
        
        if !label.isEmpty {
               sendData(dataVector, withLabel: label, modelType: modelType)
           } else {
               sendData(dataVector, modelType: modelType)
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
