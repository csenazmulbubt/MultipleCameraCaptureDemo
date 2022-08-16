//
//  ViewController.swift
//  MultipleCaptureCameraDemo
//
//  Created by Nazmul on 14/08/2022.
//

import UIKit

class ViewController: UIViewController{

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          
        }
    }
    
    @IBAction func tappedOnOpenCamera(_ sender: UIButton) {
        let vc = CameraVC()
        vc.modalPresentationStyle = .fullScreen
        vc.cameraVCDelegate = self
        self.present(vc, animated: true, completion: nil)
    }

}

extension ViewController: CameraVCDelegate{
    func dismissWithPhotosUrl(photosUrl: [URL]) {
        
        for purl in photosUrl{
            let img = UIImage(contentsOfFile: purl.path)
            print("IMG",img?.size)
        }
    }
}

