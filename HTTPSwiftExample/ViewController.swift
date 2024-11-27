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
let SERVER_URL = "http://192.168.1.144:8000" // change this for your server name!!!

import UIKit

class ViewController: UIViewController, URLSessionDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    let model = MlaasModel()
    var floatValue = 5.5
    let operationQueue = OperationQueue()
    let imagePicker = UIImagePickerController()
    var featureImage: UIImage?
    
    @IBOutlet weak var mainTextView: UITextView!
    
    @IBOutlet weak var modelTypeSegmentedControl: UISegmentedControl! // Connect the segmented control from the storyboard for mod B
    
    @IBOutlet weak var checkFaceButton: UIButton!
    let animation = CATransition()
    
    var selectedModelType: String = "KNN" // Default model type
    
    //MARK: Setup Session and Animation
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // setup URL Session
        modelTypeSegmentedControl.addTarget(self, action: #selector(modelTypeChanged(_:)), for: .valueChanged)
        
        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.reveal
        animation.duration = 0.5
        
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDataViewController" {  // Ensure this matches the identifier in the storyboard
            if let dataVC = segue.destination as? DataViewController {
                // Pass data to DataViewController
                dataVC.featureImage = self.featureImage
            }
        }
    }

    //chatgpt helped me with this code for Mod B because I was confused and getting errors
    @objc func modelTypeChanged(_ sender: UISegmentedControl) {
           switch sender.selectedSegmentIndex {
           case 0:
               selectedModelType = "KNN"
           case 1:
               selectedModelType = "XGBoost"
           default:
               selectedModelType = "KNN" // Default fallback
           }
           print("Selected model type: \(selectedModelType)")
       }
    
    @IBAction func uploadButtonTapped(_ sender: UIButton) {
           guard let image = UIImage(named: "sample_image") else { return }
           let label = "ExampleLabel" // Replace with user input if applicable
           
           // Pass the selected model type to uploadImageWithLabel
           let mlModel = MlaasModel()
        mlModel.uploadImageWithLabel(image: image, label: label, server_ip: <#String#>, modelType: selectedModelType)
       }
   
    
    @IBAction func pickImageButton(_ sender: UIButton) {
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true, completion: nil)
    }
    
    
    @IBAction func checkIfFaceMatchesPrediction(_ sender: Any) {
        //performSegue(withIdentifier: "FaceScanViewControllerSegue", sender: self)
    }
    
    @IBAction func DataButton(_ sender: UIButton) {
    }
    
    
    //MARK: Get Request
    @IBAction func sendGetRequest(_ sender: AnyObject)  {
        // Create GET request
        let baseURL = "\(SERVER_URL)/GetExample"
        let query = "?arg=\(self.floatValue)"
        guard let getUrl = URL(string: "\(baseURL)\(query)") else { return }
        let request = URLRequest(url: getUrl)
        
        model.sendGetRequest(request: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.mainTextView.text = "Error: \(error.localizedDescription)"
                }
                return
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.mainTextView.layer.add(self.animation, forKey: nil)
                    self.mainTextView.text = "Response: \(response!) \n==================\n\(responseString)"
                }
            }
        }
    }
        //dataTask.resume() // start the task
        
    
    
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
        
        model.sendPostRequest(request: request) { [weak self] data, response, error in
            guard let self = self else { return}
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            let jsonDictionary = model.convertDataToDictionary(with: data)
            
            DispatchQueue.main.async{
                self.mainTextView.layer.add(self.animation, forKey: nil)
                self.mainTextView.text = """
                ResponseL \(response!)
                ===============
                \(jsonDictionary)
                """
            }
        }
        //let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            //completionHandler:{(data, response, error) in
                // TODO: handle error!
                //print("Response:\n%@",response!)
                //let jsonDictionary = self.convertDataToDictionary(with: data)
                
                // show to screen
                //DispatchQueue.main.async{
                    //self.mainTextView.layer.add(self.animation, forKey: nil)
                    //self.mainTextView.text = "\(response!) \n==================\n\(jsonDictionary)"
            
        
        
        //postTask.resume() // start the task
    }
    
    //MARK: Post Request, args in request body (preferred)
    @IBAction func sendPostWithJsonInBody(_ sender: AnyObject) {
        
        let baseURL = "\(SERVER_URL)/PostWithJson"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["arg":[3.2,self.floatValue*2,self.floatValue]]
        
        
        let requestBody:Data? = model.convertDictionaryToData(with:jsonUpload)
    
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        model.sendPostWithJsonInBody(request: request) { [weak self] data, response, error in
            guard let self else { return }
            
            if let error = error{
                print("Error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received.")
                return
            }
            
            let jsonDictionary = model.convertDataToDictionary(with: data)
            
            DispatchQueue.main.async{
                self.mainTextView.layer.add(self.animation, forKey: nil)
                self.mainTextView.text = "\(response!) \n==================\n\(jsonDictionary)"
            }
        }
        
        //let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                        //completionHandler:{(data, response, error) in
                            //print("Response:\n%@",response!)
                            //let jsonDictionary = self.convertDataToDictionary(with: data)
                            
                            //DispatchQueue.main.async{
                                //self.mainTextView.layer.add(self.animation, forKey: nil)
                                //self.mainTextView.text = "\(response!) \n==================\n\(jsonDictionary)"
                            //}
        //})
        
        //postTask.resume() // start the task
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            featureImage = image
            mainTextView.text = "Image Successfully Uploaded"
        } else {
            print("No valid image found.")
        }
        picker.dismiss(animated: true, completion: nil) // Dismiss the picker after selection
    }
    
    // Create function to upload feature data with label
    
    /*override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "FaceScanViewController" {
            if let faceScanVC = segue.destination as? FaceScanViewController {
                faceScanVC.delegate = self
            }
        }
    }*/
    
    
}

//MARK: Protocol Required Functions
extension ViewController {
    func updateDsid(_ newDsid:Int){
        // delegate function completion handler
    }
    
    
}





