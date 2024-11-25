//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

// This exampe is meant to be run with the python example:
//              tornado_example.py
//              from the course GitHub repository: tornado_bare, branch sklearn_example


// if you do not know your local sharing server name try:
//    ifconfig |grep inet
// to see what your public facing IP address is, the ip address can be used here
//let SERVER_URL = "http://erics-macbook-pro.local:8000" // change this for your server name!!!
let SERVER_URL = "http://127.0.0.1:8000" // change this for your server name!!!

import UIKit

class ViewController: UIViewController, URLSessionDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    var session = URLSession()
    var floatValue = 5.5
    let operationQueue = OperationQueue()
    let imagePicker = UIImagePickerController()
    
    @IBOutlet weak var mainTextView: UITextView!
    
    let animation = CATransition()
    
    //MARK: Setup Session and Animation
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // setup URL Session
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        self.session = URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
        
        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.reveal
        animation.duration = 0.5
        
        
    }

    @IBAction func pickImageButton(_ sender: UIButton) {
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true, completion: nil)
    }
    
    //MARK: Get Request
    @IBAction func sendGetRequest(_ sender: AnyObject) {
        // create a GET request and get the reponse back as NSData
        let baseURL = "\(SERVER_URL)/GetExample"
        let query = "?arg=\(self.floatValue)"
        
        let getUrl = URL(string: "\(baseURL)\(query)")
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                // TODO: handle error!
                print("Response:\n%@",response!)
                let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                
                // show to screen
                DispatchQueue.main.async{
                    self.mainTextView.layer.add(self.animation, forKey: nil)
                    self.mainTextView.text = "\(response!) \n==================\n\(strData!)"
                }
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: Post Request, args in url
    @IBAction func sendPostRequest(_ sender: AnyObject) {
        
        let baseURL = "\(SERVER_URL)/DoPost"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (style of get arguments)
        let requestBody:Data? = "arg1=\(self.floatValue)".data(using: String.Encoding.utf8, allowLossyConversion: false)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                // TODO: handle error!
                print("Response:\n%@",response!)
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                // show to screen
                DispatchQueue.main.async{
                    self.mainTextView.layer.add(self.animation, forKey: nil)
                    self.mainTextView.text = "\(response!) \n==================\n\(jsonDictionary)"
                }
        })
        
        postTask.resume() // start the task
    }
    
    //MARK: Post Request, args in request body (preferred)
    @IBAction func sendPostWithJsonInBody(_ sender: AnyObject) {
        
        let baseURL = "\(SERVER_URL)/PostWithJson"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["arg":[3.2,self.floatValue*2,self.floatValue]]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
    
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                        completionHandler:{(data, response, error) in
                            print("Response:\n%@",response!)
                            let jsonDictionary = self.convertDataToDictionary(with: data)
                            
                            DispatchQueue.main.async{
                                self.mainTextView.layer.add(self.animation, forKey: nil)
                                self.mainTextView.text = "\(response!) \n==================\n\(jsonDictionary)"
                            }
        })
        
        postTask.resume() // start the task
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            print("Image Selected: \(image)")
        } else {
            print("No valid image found.")
        }
        picker.dismiss(animated: true, completion: nil) // Dismiss the picker after selection
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
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            print("json error: \(error.localizedDescription)")
            return NSDictionary() // just return empty
        }
    }

}





