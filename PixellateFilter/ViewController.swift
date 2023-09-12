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
    
        self.view.addSubview(enterButton)
        enterButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        enterButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        enterButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        enterButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    
    @objc func tap(){
        let cameraVC = CameraViewController()
        cameraVC.modalPresentationStyle = .overFullScreen
        self.present(cameraVC, animated: true)
    }
    
    lazy var enterButton: UIButton = {
        let btn = UIButton()
        btn.setTitle("Enter", for: .normal)
        btn.setTitleColor(UIColor.black, for: .normal)
        btn.backgroundColor = .yellow
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(tap), for: .touchUpInside)
        btn.clipsToBounds = true
        btn.layer.cornerRadius = 25
        return btn
    }()


}

