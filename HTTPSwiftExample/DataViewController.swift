//
//  DataViewController.swift
//  HTTPSwiftExample
//
//  Created by Travis Peck on 11/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

class DataViewController: UIViewController {
    
    
    @IBOutlet weak var ipOutlet: UITextField!
    @IBOutlet weak var dataLabelOutlet: UITextField!

    let mlaasmodel = MlaasModel()
    var featureImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            self.view.addGestureRecognizer(tapGesture)
    }
    
    @IBAction func sendDataButton(_ sender: Any) {
        
        guard let selectedImage = featureImage
            else {
            print("No image selected")
            return
        }
        
        let vector = selectedImage
        
        let userip = ipOutlet.text ?? ""
        let label = dataLabelOutlet.text ?? ""
        
        mlaasmodel.uploadImageWithLabel(image: vector, label: label, server_ip: userip)
        
    }
    @IBAction func trainButton(_ sender: UIButton) {
        mlaasmodel.trainModel()
    }
    
    
    @objc func dismissKeyboard() {
        // Resign first responder on the text fields to dismiss the keyboard
        ipOutlet.resignFirstResponder()
        dataLabelOutlet.resignFirstResponder()
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
