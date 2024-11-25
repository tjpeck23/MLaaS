//
//  MlaasModel.swift
//  HTTPSwiftExample
//
//  Created by Travis Peck on 11/25/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import Foundation
import UIKit

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
    
    
    //MARK: These are older methods below. Not sure if we will use them
    
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
