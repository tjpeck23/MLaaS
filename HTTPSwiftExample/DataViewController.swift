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
    @IBOutlet weak var authName: UITextField!
    
    let mlaasmodel = MlaasModel()
    
    var selectedImages: [UIImage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toAuth" {
            let destination = segue.destination as! AuthViewController
            destination.receivedText = authName.text!
        }
    }
    
    @IBAction func sendDataButton(_ sender: Any) {
        
        guard !self.selectedImages.isEmpty
            else {
            print("No image selected")
            return
        }
        
        
        //let userip = ipOutlet.text ?? ""
        let label = dataLabelOutlet.text ?? ""
        
        mlaasmodel.uploadImageWithLabel(images: self.selectedImages, label: label)
        
        
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
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        authName.text = textField.text
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
