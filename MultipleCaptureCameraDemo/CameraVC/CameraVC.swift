//
//  CameraVC.swift
//  MultipleCaptureCameraDemo
//
//  Created by Nazmul on 14/08/2022.
//

import UIKit
import Foundation

public enum CameraVCBackgroundColor{
    case black,white
}

protocol CameraVCDelegate: NSObjectProtocol {
    func dismissWithPhotosUrl(photosUrl: [URL])
    func maximumPhotoCaptureAlert(maximumPhotoCaptureLimit: Int)
}

class CameraVC: UIViewController, UICollectionViewDelegateFlowLayout{
    
    @IBOutlet weak var cameraCaptureButton: TriggerButton!
    @IBOutlet weak var previewLayerView: UIView!
    @IBOutlet weak var flashBarButton: UIBarButtonItem!
    @IBOutlet weak var cameraPhotoCollectionView: UICollectionView!
    
    weak var cameraVCDelegate: CameraVCDelegate?
    
    private let captureManager = CaptureManager()
    private var isfirst = true
    private let photoStorage = PhotoStorage()
    private var photosUrl = [URL]()
    private let maxLowResolutionSideLength = CGFloat(200)
    private let imageCache = NSCache<NSString, UIImage>()
    private var currentPhotoCaptureCount = 0
    
    public var maximumPhotoCaptureLimit = 5
    public var backgroundColor : CameraVCBackgroundColor = .black
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupCollectionView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setCollectionViewPhotoLayout()
            self.cameraCaptureButton.layer.cornerRadius = self.cameraCaptureButton.bounds.size.height / 2.0
            self.setUpNavigationLeftBarButton()
        }
        self.setUpBackGroundColor()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let previewLayer = captureManager.previewLayer
        previewLayer.frame = self.previewLayerView.bounds
        self.previewLayerView.layer.addSublayer(previewLayer)
        captureManager.prepare { [weak self] isPermitted in
            if isPermitted == nil{
                self?.showCameraPermissionAlert()
            }
        }
        captureManager.delegate = self
    }
    
    override var prefersStatusBarHidden: Bool{
        return true
    }
    
    private func setUpBackGroundColor() {
        var navigationBgColor = UIColor.black
        var navigationTintColor = UIColor.white
        if backgroundColor == .white{
            navigationTintColor = .black
            navigationBgColor = .white
        }
        self.view.backgroundColor = navigationBgColor
        cameraCaptureButton.buttonColor = navigationTintColor
        if let nav = navigationController {
            nav.navigationBar.tintColor = navigationTintColor
            nav.navigationBar.isTranslucent = false
            self.setNavigationBarAppearance(navigationController: nav, withNavigationBarBackgroundColor: navigationBgColor , andNavigationTitleColor:  navigationTintColor)
        }
    }
    
    private func setUpNavigationLeftBarButton(){
        let flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(named: "LightningIcon"), for: .normal)
        flashButton.setTitle("Auto", for: .normal)
        flashButton.sizeToFit()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: flashButton)
        flashButton.addTarget(self, action: #selector(self.tappedOnFlashBtnAction), for: .touchUpInside)
    }
    
    private func setNavigationBarAppearance(navigationController navController: UINavigationController, withNavigationBarBackgroundColor navBGColor: UIColor, andNavigationTitleColor titleColor: UIColor) {
        
        navController.navigationBar.shadowImage = UIImage()
        
        if #available(iOS 15.0, *) {
            // if only change background color
            //navigationController?.view.backgroundColor = UIColor(named: "appOrangeColor")
            //if need to change title color
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: titleColor]
            appearance.backgroundColor = navBGColor
            navController.navigationBar.standardAppearance = appearance
            navController.navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    private func setupCollectionView() {
        cameraPhotoCollectionView.alwaysBounceHorizontal = true
        cameraPhotoCollectionView.dragInteractionEnabled = true
        let nib = UINib(nibName: "CameraCollectionViewCell",bundle: nil)
        self.cameraPhotoCollectionView.register(nib, forCellWithReuseIdentifier: "cameracell")
    }
    
    func setCollectionViewPhotoLayout() -> Void {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        //total item show 4.5 spaceing 10*4
        let sizeG = cameraPhotoCollectionView.bounds.size
        layout.itemSize = CGSize(width: (sizeG.width - 52) / 4.5 , height: sizeG.height - 0.5)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.scrollDirection = .horizontal
        self.cameraPhotoCollectionView!.collectionViewLayout = layout
    }
    
    @IBAction func switchCameraBtnAction(_ sender: UIButton) {
        if captureManager.selectedCameraType == .back{
            captureManager.selectedCameraType = .front
        }
        else{
            captureManager.selectedCameraType = .back
        }
    }
    
    @IBAction func tappedOnDoneBtn(_ sender: UIBarButtonItem) {
        self.captureManager.stop(nil)
        cameraVCDelegate?.dismissWithPhotosUrl(photosUrl: self.photosUrl)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func tappedOnCaptureBtn(_ sender: TriggerButton) {
        if currentPhotoCaptureCount == maximumPhotoCaptureLimit {
            cameraVCDelegate?.maximumPhotoCaptureAlert(maximumPhotoCaptureLimit: maximumPhotoCaptureLimit)
            return
        }
        sender.isEnabled = false
        captureManager.captureImage()
        currentPhotoCaptureCount += 1
    }
    
    @objc func tappedOnFlashBtnAction() {
        let mode = captureManager.nextAvailableFlashMode() ?? .off
        let item = self.navigationItem.leftBarButtonItem!
        let button = item.customView as! UIButton
        captureManager.changeFlashMode(mode) {
            switch mode {
            case .off:
                button.setTitle("Off", for: .normal)
            case .on:
                button.setTitle("On", for: .normal)
            case .auto:
                button.setTitle("Auto", for: .normal)
            @unknown default:
                break
            }
        }
    }
    
    private func didAddAsset() {
        DispatchQueue.main.async {
            self.cameraPhotoCollectionView.performBatchUpdates({
                let insertedIndexPath: IndexPath
                insertedIndexPath = IndexPath(item: self.photosUrl.count - 1, section: 0)
                self.cameraPhotoCollectionView.insertItems(at: [insertedIndexPath])
            }, completion: { _ in
                self.scrollToLastAddedAssetAnimated(true)
            })
        }
    }
    
    private func resizeImageForCollectionViewShow(imagePath: String) -> UIImage {
        
        autoreleasepool {
            if let image = UIImage(contentsOfFile: imagePath) {
                if image.size.width > maxLowResolutionSideLength || image.size.height > maxLowResolutionSideLength  {
                    let scale: CGFloat
                    
                    if(image.size.width > image.size.height) {
                        scale = maxLowResolutionSideLength / image.size.width
                    } else {
                        scale = maxLowResolutionSideLength / image.size.height
                    }
                    let newWidth  = CGFloat(roundf(Float(image.size.width) * Float(scale)))
                    let newHeight = CGFloat(roundf(Float(image.size.height) * Float(scale)))
                    let resizeImg = image.imgly_normalizedImageOfSize(CGSize(width: newWidth, height: newHeight))
                    self.imageCache.setObject(resizeImg, forKey: imagePath as NSString)
                    return resizeImg
                }
            }
            return UIImage()
        }
    }
    
    private func scrollToLastAddedAssetAnimated(_ animated: Bool) {
        if photosUrl.count > 0 {
            cameraPhotoCollectionView.scrollToItem(at: IndexPath(item: photosUrl.count - 1, section: 0), at: .left, animated: animated)
        }
    }
    
    private func showCameraPermissionAlert() -> Void {
        
        let title = "Camera Access Denied"
        let message = "This app requires access to your device's Camera.\n\nPlease enable Camera access for this app in Settings / Privacy / Camera"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Settings",
                                                style: .destructive) { action -> Void in
            self.gotoAppPrivacySettings()
        })
        alertController.addAction(UIAlertAction(title: "Cancel",
                                                style: .cancel) { action -> Void in
            self.dismiss(animated: true, completion: nil)
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func gotoAppPrivacySettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
                  return
              }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
}

//MARK : - UICollectionViewDataSource , UICollectionViewDelegate
extension CameraVC: UICollectionViewDataSource, UICollectionViewDelegate{
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photosUrl.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cameracell", for: indexPath) as? CameraCollectionViewCell
        
        let itemPath = photosUrl[indexPath.item]
        var image = UIImage()
        
        if let cachedImage = imageCache.object(forKey: itemPath.path as NSString) {
            image = cachedImage
        }
        else{
            image = self.resizeImageForCollectionViewShow(imagePath: itemPath.path)
        }
        cell?.imageView.image = image
        cell?.deleteBtn.tag = indexPath.item
        cell?.cameraCellDelegate = self
        return cell!
    }
    
}

//MARK: - UICollectionViewDragDelegate,UICollectionViewDropDelegate
extension CameraVC: UICollectionViewDragDelegate,UICollectionViewDropDelegate{
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        let itemProvider = NSItemProvider(object: "\(indexPath)" as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = photosUrl[indexPath.item]
        return [dragItem]
        
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return true
    }
    
    //UICollectionViewDropDelegate
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession,withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        let destinationIndexPath: IndexPath
        
        if let indexPath = coordinator.destinationIndexPath {
            
            destinationIndexPath = indexPath
        }
        
        else {
            let row = collectionView.numberOfItems(inSection: 0)
            destinationIndexPath = IndexPath(item: row - 1, section: 0)
        }
        
        if coordinator.proposal.operation == .move {
            
            self.reorderItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
        }
        //self.cameraPhotoCollectionView.reloadData()
    }
    
    fileprivate func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView){
        if let item = coordinator.items.first, let sourceIndexPth = item.sourceIndexPath {
            collectionView.performBatchUpdates({
                self.photosUrl.remove(at: sourceIndexPth.item)
                self.photosUrl.insert(item.dragItem.localObject as! URL, at: destinationIndexPath.item)
                collectionView.deleteItems(at: [sourceIndexPth])
                collectionView.insertItems(at: [destinationIndexPath])
            }, completion: nil)
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
        }
    }
    
}

//MARK: - CameraCollectionViewDelegate
extension CameraVC: CameraCollectionViewDelegate{
    func tappedOnDeleteBtn(cell: CameraCollectionViewCell) {
        if let indexPath = cameraPhotoCollectionView.indexPath(for: cell) {
            let url = self.photosUrl[indexPath.item]
            currentPhotoCaptureCount -= 1
            self.photosUrl.remove(at: indexPath.item)
            self.imageCache.removeObject(forKey: url.path as NSString)
            cameraPhotoCollectionView.performBatchUpdates({
                self.cameraPhotoCollectionView.deleteItems(at: [indexPath])
            }, completion: { _ in
                self.photoStorage.deleteAsset(url, completion: {})
            })
        }
    }
}

//MARK: - CaptureManagerDelegate
extension CameraVC: CaptureManagerDelegate {
    func captureManager(_ manager: CaptureManager, didCaptureImageData data: Data) {
        cameraCaptureButton.isEnabled = true
        autoreleasepool {
            photoStorage.createAssetFromImageData(data) { [weak self] imgUrl in
                self?.photosUrl.append(imgUrl)
                DispatchQueue.main.async {
                    let _ = self?.resizeImageForCollectionViewShow(imagePath: imgUrl.path)
                    self?.didAddAsset()
                }
            }
        }
    }
    
    func captureManager(_ manager: CaptureManager, didDetectLightingCondition: LightingCondition) {
        
    }
    
    func captureManager(_ manager: CaptureManager, didFailWithError error: NSError) {
        
    }
}


private extension UIImage{
    func imgly_normalizedImageOfSize(_ size: CGSize) -> UIImage {
        autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            draw(in: CGRect(origin: CGPoint.zero, size: size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return normalizedImage!
        }
    }
}
