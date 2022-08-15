//
//  CameraVC.swift
//  MultipleCaptureCameraDemo
//
//  Created by Nazmul on 14/08/2022.
//

import UIKit

class CameraVC: UIViewController, UICollectionViewDelegateFlowLayout{
   
    
    
    @IBOutlet weak var cameraCaptureButton: TriggerButton!
    
    @IBOutlet weak var previewLayer: UIView!
    
    @IBOutlet weak var flashButton: UIButton!
    
    @IBOutlet weak var cameraPhotoCollectionView: UICollectionView!
    
    private let captureManager = CaptureManager()
    private var isfirst = true
    private let photoStorage = PhotoStorage()
    private var photosUrl = [URL]()
    private let maxLowResolutionSideLength = CGFloat(200)
    private let imageCache = NSCache<NSString, UIImage>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraPhotoCollectionView.delegate = self
        cameraPhotoCollectionView.dataSource = self
        
        let nib = UINib(nibName: "CameraCollectionViewCell",bundle: nil)
        self.cameraPhotoCollectionView.register(nib, forCellWithReuseIdentifier: "cameracell")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setCollectionViewPhotoLayout()
            self.cameraCaptureButton.layer.cornerRadius = self.cameraCaptureButton.bounds.size.height / 2.0
            print("Preview layer",self.previewLayer.bounds)
        }
        flashButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        flashButton.tintColor = UIColor.white
        flashButton.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.roundifyButton(flashButton)
        // Do any additional setup after loading the view.
    }
    
    override var prefersStatusBarHidden: Bool{
        return true
    }
    
    func setCollectionViewPhotoLayout() -> Void {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        //total item show 4.5 spaceing 10*4
        let sizeG = cameraPhotoCollectionView.bounds.size
        layout.itemSize = CGSize(width: (sizeG.width - 52) / 4.5 , height: sizeG.height - 5)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.scrollDirection = .horizontal
        self.cameraPhotoCollectionView!.collectionViewLayout = layout
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let previewLayer = captureManager.previewLayer
        previewLayer.frame = self.previewLayer.bounds
        self.previewLayer.layer.addSublayer(previewLayer)
        
        captureManager.prepare { [weak self] erro in
            if let err = erro{
              
            }
        }
        captureManager.delegate = self
    }
    
    @IBAction func switchCameraBtnAction(_ sender: UIButton) {
        if captureManager.selectedCameraType == .back{
            captureManager.selectedCameraType = .front
        }
        else{
            captureManager.selectedCameraType = .back
        }
    }
    
    
    //MARK: - tapped on done btn
    @IBAction func tappedOnDoneBtn(_ sender: UIButton) {
        self.captureManager.stop(nil)
        self.dismiss(animated: true, completion: nil)
    }
    
    
    @IBAction func tappedOnCaptureBtn(_ sender: TriggerButton) {
        
        //TODO: Must be btn disable enable
        sender.isEnabled = false
        captureManager.captureImage()
        
    }
    
    @IBAction func tappedOnFlashBtn(_ sender: UIButton) {
        
        let mode = captureManager.nextAvailableFlashMode() ?? .off
        captureManager.changeFlashMode(mode) {
            switch mode {
            case .off:
                self.flashButton.setTitle("off", for: .normal)
            case .on:
                self.flashButton.setTitle("on", for: .normal)
            case .auto:
                self.flashButton.setTitle("auto", for: .normal)
            @unknown default:
                break
            }
        }
    }
    
    private func roundifyButton(_ button: UIButton, inset: CGFloat = 16) {
        button.tintColor = UIColor.white

        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.layer.borderColor = button.tintColor!.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = button.bounds.height / 2
        button.configuration?.imagePadding -= inset
    }
    
    fileprivate func didAddAsset() {
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
    
    func resizeImageForCollectionViewShow(imagePath: String) -> UIImage {
        
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
    
    fileprivate func scrollToLastAddedAssetAnimated(_ animated: Bool) {
        if photosUrl.count > 0 {
            cameraPhotoCollectionView.scrollToItem(at: IndexPath(item: photosUrl.count - 1, section: 0), at: .left, animated: animated)
        }
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
        return cell!
    }
    
}

//MARK: - CaptureManagerDelegate
extension CameraVC: CaptureManagerDelegate{
    
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


extension UIImage{
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
