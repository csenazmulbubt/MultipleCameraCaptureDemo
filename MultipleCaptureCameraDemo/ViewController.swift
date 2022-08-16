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
        let storyboard = UIStoryboard(name: "Camera", bundle: nil)
        guard let navController = storyboard.instantiateViewController(withIdentifier: "navCameraVC") as? UINavigationController else {return}
        let vc = navController.viewControllers.first as! CameraVC
        vc.cameraVCDelegate = self
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true, completion: nil)
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

