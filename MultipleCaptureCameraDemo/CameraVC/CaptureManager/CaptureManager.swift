//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//


import UIKit
import AVFoundation
import Photos
import ImageIO
import MobileCoreServices
import Photos
import CoreLocation

enum CaptureManagerViewfinderMode {
    case fullScreen
    case window
}

public enum CameraType {
    case front, back
}


protocol CaptureManagerDelegate: AnyObject {
    func captureManager(_ manager: CaptureManager, didCaptureImageData data: Data)
    func captureManager(_ manager: CaptureManager, didDetectLightingCondition: LightingCondition)
    func captureManager(_ manager: CaptureManager, didFailWithError error: NSError)
}

extension CaptureManagerDelegate {
    func captureManager(_ manager: CaptureManager, didFailWithError error: NSError) {}
}



class CaptureManager: NSObject {
    weak var delegate: CaptureManagerDelegate?
    
    let previewLayer: AVCaptureVideoPreviewLayer
    let viewfinderMode: CaptureManagerViewfinderMode
    
    var flashMode: AVCaptureDevice.FlashMode = .auto
    
    var hasFlash: Bool {
        return cameraDevice?.hasFlash ?? false && cameraDevice?.isFlashAvailable ?? false
    }
    
    var supportedFlashModes: [AVCaptureDevice.FlashMode] {
        var modes: [AVCaptureDevice.FlashMode] = []
        for mode in [AVCaptureDevice.FlashMode.off, AVCaptureDevice.FlashMode.auto, AVCaptureDevice.FlashMode.on] {
#if !targetEnvironment(simulator)
            if cameraOutput.supportedFlashModes.contains(mode) {
                modes.append(mode)
            }
#endif
        }
        return modes
    }
    
    open var hasFrontCamera: Bool = {
        guard let _ = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video, position: .front) else {
            return false
        }
        return true
    }()
    
    fileprivate lazy var frontCameraDevice: AVCaptureDevice? = {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    fileprivate lazy var backCameraDevice: AVCaptureDevice? = {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)
    }()
    
    
    private let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "no.finn.finjinon-captures", attributes: [])
    private var cameraDevice: AVCaptureDevice?
    private var cameraOutput: AVCapturePhotoOutput
    private var cameraSettings: AVCapturePhotoSettings?
    private var orientation = AVCaptureVideoOrientation.portrait
    private var lastVideoCaptureTime = CMTime()
    private let lowLightService = LowLightService()
    
    var cameraIsSetup = false
    
    /// Array of vision requests
    
    override init() {
        session.sessionPreset = AVCaptureSession.Preset.photo
        var viewfinderMode: CaptureManagerViewfinderMode {
            let screenBounds = UIScreen.main.nativeBounds
            let ratio = screenBounds.height / screenBounds.width
            return ratio <= 1.5 ? .fullScreen : .window
        }
        self.viewfinderMode = viewfinderMode
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = self.viewfinderMode == .fullScreen ? AVLayerVideoGravity.resizeAspectFill : AVLayerVideoGravity.resize
        cameraOutput = AVCapturePhotoOutput()
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(changedOrientationNotification(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        changedOrientationNotification(nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - API
    
    func authorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    }
    
    // Prepares the capture session, possibly asking the user for camera access.
    func prepare(_ completion: @escaping (Bool?) -> Void) {
        switch authorizationStatus() {
        case .authorized:
            configure(completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { granted in
                if granted {
                    self.configure(completion)
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            })
        case .denied, .restricted:
            completion(nil)
        @unknown default:
            return
        }
    }
    
    func stop(_ completion: (() -> Void)?) {
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
            }
            completion?()
        }
    }
    
    func captureImage() {
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            guard let connection = self.cameraOutput.connection(with: .video) else { return }
            
            connection.videoOrientation = self.orientation
            self.cameraSettings = self.createCapturePhotoSettingsObject()
            
            guard let cameraSettings = self.cameraSettings else { return }
#if !targetEnvironment(simulator)
            if !self.cameraOutput.supportedFlashModes.contains(cameraSettings.flashMode) {
                cameraSettings.flashMode = .off
            }
#endif
            self.cameraOutput.capturePhoto(with: cameraSettings, delegate: self)
        }
    }
    
    func lockFocusAtPointOfInterest(_ pointInLayer: CGPoint) {
        let pointInCamera = previewLayer.captureDevicePointConverted(fromLayerPoint: pointInLayer)
        lockCurrentCameraDeviceForConfiguration { cameraDevice in
            if let cameraDevice = self.cameraDevice, cameraDevice.isFocusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = pointInCamera
                cameraDevice.focusMode = .autoFocus
            }
        }
    }
    
    func changeFlashMode(_ newMode: AVCaptureDevice.FlashMode, completion: @escaping () -> Void) {
        flashMode = newMode
        cameraSettings = createCapturePhotoSettingsObject()
        DispatchQueue.main.async(execute: completion)
    }
    
    // Next available flash mode, or nil if flash is unsupported
    func nextAvailableFlashMode() -> AVCaptureDevice.FlashMode? {
        if !hasFlash {
            return nil
        }
        
        // Find the next available mode, or wrap around
        var nextIndex = 0
        if let idx = supportedFlashModes.firstIndex(of: flashMode) {
            nextIndex = idx + 1
        }
        
        let startIndex = min(nextIndex, supportedFlashModes.count)
        let next = supportedFlashModes[startIndex ..< supportedFlashModes.count].first ?? supportedFlashModes.first
        if let nextFlashMode = next { flashMode = nextFlashMode }
        
        return next
    }
    
    open var selectedCameraType = CameraType.back {
        didSet {
            if cameraIsSetup {
                if selectedCameraType != oldValue {
                    //if animateCameraDeviceChange {
                    // _doFlipAnimation()
                    //}
                    _updateCameraDevice(selectedCameraType)
                    //_updateFlashMode(flashMode)
                    //_setupMaxZoomScale()
                    //_zoom(0)
                }
            }
        }
    }
    
    // Orientation change function required because we've locked the interface in portrait
    // and DeviceOrientation does not map 1:1 with AVCaptureVideoOrientation
    @objc func changedOrientationNotification(_: Notification?) {
        let currentDeviceOrientation = UIDevice.current.orientation
        switch currentDeviceOrientation {
        case .faceDown, .faceUp, .unknown:
            break
        case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation(rawValue: currentDeviceOrientation.rawValue) ?? .portrait
        @unknown default:
            return
        }
    }
}

// MARK: - Private methods

private extension CaptureManager {
    func createCapturePhotoSettingsObject() -> AVCapturePhotoSettings {
        var newCameraSettings: AVCapturePhotoSettings
        
        if let currentCameraSettings = cameraSettings {
            newCameraSettings = AVCapturePhotoSettings(from: currentCameraSettings)
            newCameraSettings.flashMode = flashMode
        } else {
            newCameraSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg, AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 0.9]])
            newCameraSettings.flashMode = flashMode
        }
        return newCameraSettings
    }
    
    func lockCurrentCameraDeviceForConfiguration(_ configurator: @escaping (AVCaptureDevice?) -> Void) {
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.cameraDevice?.lockForConfiguration()
            } catch let error as NSError {
                self.delegate?.captureManager(self, didFailWithError: error)
            } catch {
                fatalError()
            }
            
            configurator(self.cameraDevice)
            
            self.cameraDevice?.unlockForConfiguration()
        }
    }
    
    func configure(_ completion: @escaping (Bool?) -> Void) {
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.cameraDevice = self.cameraDeviceWithPosition(.back)
            
            guard let cameraDevice =  self.cameraDevice else { return}
            
            do {
                let input = try AVCaptureDeviceInput(device: cameraDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    NSLog("Failed to add input \(input) to session \(self.session)")
                }
            } catch let error1 as NSError {
                self.delegate?.captureManager(self, didFailWithError: error1)
            }
            
            if self.session.canAddOutput(self.cameraOutput) {
                self.session.addOutput(self.cameraOutput)
            }
            
            let videoOutput = self.makeVideoDataOutput()
            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
            }
            
            if let cameraDevice = self.cameraDevice {
                if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                    do {
                        try cameraDevice.lockForConfiguration()
                    } catch let error1 as NSError {
                        self.delegate?.captureManager(self, didFailWithError: error1)
                    }
                    cameraDevice.focusMode = .continuousAutoFocus
                    if cameraDevice.isSmoothAutoFocusSupported {
                        cameraDevice.isSmoothAutoFocusEnabled = true
                    }
                    cameraDevice.unlockForConfiguration()
                }
            }
            self.session.startRunning()
            self.cameraIsSetup = true
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    func cameraDeviceWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        
        if #available(iOS 11.2, *) {
            deviceTypes = [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera]
        } else {
            deviceTypes = [.builtInWideAngleCamera]
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        let availableCameraDevices = discoverySession.devices
        
        guard availableCameraDevices.isEmpty == false else {
            print("Error no camera devices found")
            return nil
        }
        
        for device in availableCameraDevices {
            if device.position == position {
                return device
            }
        }
        return AVCaptureDevice.default(for: AVMediaType.video)
    }
    
    func makeVideoDataOutput() -> AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "no.finn.finjinon-sample-buffer"))
        return output
    }
    
    func _updateCameraDevice(_ deviceType: CameraType) {
        //if let validCaptureSession = session {
        let validCaptureSession = session
        validCaptureSession.beginConfiguration()
        defer { validCaptureSession.commitConfiguration() }
        let inputs: [AVCaptureInput] = validCaptureSession.inputs
        
        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                validCaptureSession.removeInput(deviceInput)
            }
        }
        
        switch deviceType {
        case .front:
            if hasFrontCamera {
                if let validFrontDevice = _deviceInputFromDevice(frontCameraDevice) {
                    if !inputs.contains(validFrontDevice) {
                        validCaptureSession.addInput(validFrontDevice)
                    }
                }
            }
        case .back:
            if let validBackDevice = _deviceInputFromDevice(backCameraDevice) {
                if !inputs.contains(validBackDevice) {
                    validCaptureSession.addInput(validBackDevice)
                }
            }
        }
    }
    
    func _deviceInputFromDevice(_ device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let outError {
            print("EROOR",outError)
            return nil
        }
    }
    
    
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CaptureManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        autoreleasepool {
            autoreleasepool {
                DispatchQueue.main.async {
                    if let imageData = photo.fileDataRepresentation(){
                        self.delegate?.captureManager(self, didCaptureImageData: imageData)
                    }
                    else{
                        if let error = error {
                            self.delegate?.captureManager(self, didFailWithError: error as NSError)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let fps: Int32 = 1 // Create pixel buffer and call the delegate 1 time per second
        
        guard (time - lastVideoCaptureTime) >= CMTime.init(value: 1, timescale: fps) else {
            return
        }
        lastVideoCaptureTime = time
        if let lightningCondition = lowLightService.getLightningCondition(from: sampleBuffer) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.captureManager(self, didDetectLightingCondition: lightningCondition)
            }
        }
    }
}

