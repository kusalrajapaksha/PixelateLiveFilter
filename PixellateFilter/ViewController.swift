//
//  ViewController.swift
//  PixellateFilter
//
//  Created by Kusal Rajapaksha on 2023-06-08.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = .red
        
        let button = UIButton()
        button.backgroundColor = .green
        button.frame = CGRect(x: 40, y: 100, width: 100, height: 50)
        self.view.addSubview(button)
        
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
        
    }
    
    
    @objc func tap(){
        let cameraVC = CameraViewController()
        cameraVC.modalPresentationStyle = .overFullScreen
        self.present(cameraVC, animated: true)
    }


}

