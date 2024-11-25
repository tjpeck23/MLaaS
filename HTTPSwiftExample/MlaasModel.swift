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
    
    func preprocessImage(_ image: UIImage, targetSize: CGSize=CGSize(width:224, height:224)) -> CVPixelBuffer? {
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = resizedImage?.cgImage else {return nil}
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelBuffer: CVPixelBuffer?
        
        CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        
        guard let buffer = pixelBuffer else {return nil}
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        context.render(ciImage, to: buffer, bounds: CGRect(x: 0, y:0, width: targetSize.width, height: targetSize.height), colorSpace: colorSpace)
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        
        return buffer
    }
    
    // Extracing feature vectors with CoreML MobileNetV2
    func extractFeatureVector(from image: UIImage) {
        guard let pixelBuffer = preprocessImage(image) else {
            print("Error: could not extract features")
            return}
        
        guard let featureModel = try? MobileNetV2(configuration: MLModelConfiguration()) else{
            print("Failed to load MobileNetV2 model")
            return
        }
        
        do {
            let prediction = try featureModel.prediction(image: pixelBuffer)
        } catch {
            print("Error during feature extraction: \(error)")
            return
        }
    }
    
    func uploadImageWithLabel(image: UIImage, label: String, server_ip: String) {
        guard let pixelBuffer: CVPixelBuffer = preprocessImage(image) else {
            print("Failed to preprocess image")
            return
        }
        
        guard let featureVector = extractFeatureVector(from: pixelBuffer) else {
            print("Failed to extract feature vector")
            return
        }
        
        let dataToSend = [
            "features": featureVector,
            "label": label
        ]
        
        let jsonData = try? convertDictionaryToData(with: dataToSend)
        
        sendData(_: jsonData, withLabel: label)
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
