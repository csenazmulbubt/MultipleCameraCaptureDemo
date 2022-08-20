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
        vc.maximumPhotoCaptureLimit = 5
        vc.backgroundColor = .white
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true, completion: nil)
    }
    
    private func exceedMaximumPhotoCaptureAlert() -> Void {
        
        let title = "Exceeded Maximum Limit"
        //let message = "This app requires access to your device's Camera.\n\nPlease enable Camera access for this app in Settings / Privacy / Camera"
        
        let alertController = UIAlertController(title: title, message: "", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "OK",
                                                style: .default) { action -> Void in
            //self.gotoAppPrivacySettings()
        })
        /* alertController.addAction(UIAlertAction(title: "Cancel",
         style: .cancel) { action -> Void in
         self.dismiss(animated: true, completion: nil)
         })*/
        guard let viewController = UIViewController.topMostViewController() else { return }
        viewController.present(alertController, animated: true, completion: nil)
    }

}

extension ViewController: CameraVCDelegate{
    func maximumPhotoCaptureAlert(maximumPhotoCaptureLimit: Int) {
        self.exceedMaximumPhotoCaptureAlert()
    }
    
    func dismissWithPhotosUrl(photosUrl: [URL]) {
        
        for purl in photosUrl{
            let img = UIImage(contentsOfFile: purl.path)
            print("IMG",img?.size)
        }
    }
}


extension UIViewController {
    static func topMostViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.keyWindow
        return keyWindow?.rootViewController?.topMostViewController()
    }
    
    func topMostViewController() -> UIViewController? {
        if let navigationController = self as? UINavigationController {
            return navigationController.topViewController?.topMostViewController()
        }
        else if let tabBarController = self as? UITabBarController {
            if let selectedViewController = tabBarController.selectedViewController {
                return selectedViewController.topMostViewController()
            }
            return tabBarController.topMostViewController()
        }
        
        else if let presentedViewController = self.presentedViewController {
            return presentedViewController.topMostViewController()
        }
        
        else {
            return self
        }
    }
}

extension UIApplication {
    
    var keyWindow: UIWindow? {
        // Get connected scenes
        return UIApplication.shared.connectedScenes
            // Keep only active scenes, onscreen and visible to the user
            .filter { $0.activationState == .foregroundActive }
            // Keep only the first `UIWindowScene`
            .first(where: { $0 is UIWindowScene })
            // Get its associated windows
            .flatMap({ $0 as? UIWindowScene })?.windows
            // Finally, keep only the key window
            .first(where: \.isKeyWindow)
    }
    
}
