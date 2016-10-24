//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

let SERVER_URL = "http://erics-macbook-pro.local:8000"

import UIKit

class ViewController: UIViewController, URLSessionDelegate {
    
    var session = URLSession()
    var floatValue = 1.5
    let operationQueue = OperationQueue()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        self.session = URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)

        
    }

    @IBAction func sendGetRequest(_ sender: AnyObject) {
        // create a GET request and get the reponse back as NSData
        let baseURL = "\(SERVER_URL)/GetExample"
        let query = "?arg=\(self.floatValue)"
        
        let getUrl = URL(string: "\(baseURL)\(query)")
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                
                // TODO: handle error
                NSLog("Response:\n%@",response)
                let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
                NSLog("\n\nData:\n%@",strData!)
        })
        
        dataTask.resume() // start the task
        
    }
    
    @IBAction func sendPostRequest(_ sender: AnyObject) {
        
        let baseURL = "\(SERVER_URL)/DoPost"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = NSMutableURLRequest(url: postUrl!)
        
        // data to send in body of post request (style of get arguments)
        let requestBody:Data? = "arg1=\(self.floatValue)".data(using: String.Encoding.utf8, allowLossyConversion: false)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                // TODO: handle error
                NSLog("Response:\n%@",response)
                var jsonError: NSError?
                var jsonDictionary: NSDictionary = JSONSerialization.JSONObjectWithData(data, options: JSONSerialization.ReadingOptions.MutableContainers, error: &jsonError) as NSDictionary
                
                NSLog("\n\nJSON Data:\n%@",jsonDictionary)
        })
        
        postTask.resume() // start the task
    }
    
    
    @IBAction func sendPostWithJsonInBody(_ sender: AnyObject) {
        
        let baseURL = "\(SERVER_URL)/PostWithJson"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = NSMutableURLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        var jsonError: NSError? = nil;
        var jsonUpload:NSDictionary = ["arg":[3.2,self.floatValue*2,self.floatValue]]
        var requestBody:Data? = JSONSerialization.dataWithJSONObject(jsonUpload,
            options:JSONSerialization.WritingOptions.PrettyPrinted,
            error:&jsonError);
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                NSLog("Response:\n%@",response)
                // TODO: handle error
                var jsonError: NSError?
                var jsonDictionary: NSDictionary = JSONSerialization.JSONObjectWithData(data, options: JSONSerialization.ReadingOptions.MutableContainers, error: &jsonError) as NSDictionary
                
                NSLog("\n\nJSON Data:\n%@",jsonDictionary)
        })
        
        postTask.resume() // start the task
        
    }

}





