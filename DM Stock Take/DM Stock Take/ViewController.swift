// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2020
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK
import AVFoundation
import Combine

struct ROISample {
    var id: Int
    var title: String
    var identifier: UIAction.Identifier
    var roiRect: CGRect
}

class ViewController: UIViewController
{
    // MARK: - UI Properties
    private var rectOfInterestButton: UIBarButtonItem!
    private var distanceMenuButton: UIBarButtonItem!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var smoothingButton: UIBarButtonItem!
    
    private var smoothingEnabled = true {
        didSet {
            self.updateSmoothingButtonTitle()
        }
    }
    
    // MARK: - AV Foundation Properties
    private var videoSessionRunningObserveContext = 0
    private let videoSessionQueue = DispatchQueue(label: "Video Capture", qos: .unspecified, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    
    private var videoCaptureSession: AVCaptureSession? {
        didSet {
            if  oldValue === videoCaptureSession { return }
            oldValue?.removeObserver(self, forKeyPath: "running", context: &videoSessionRunningObserveContext)
            videoCaptureSession?.addObserver(self, forKeyPath: "running", options: .new, context: &videoSessionRunningObserveContext)
        }
    }
    
    private var captureDevice: AVCaptureDevice?
    
    // MARK: - DMSDK Properties
    private let allowedSymbologies: Symbologies = [.imageDigimarc, .UPCA, .UPCE, .EAN8, .EAN13, .ITFGTIN14, .ITF, .code128]
    private var videoCaptureReader: VideoCaptureReader?
    private var payloadPublisher = PayloadPublisher()
    private var payloadOutput: AnyCancellable!
    private var layers: [UUID: DetectionRegionLayer] = [:]
    
    private var readerOptions: [ReaderOptionKey : Any] {
        let options = [ReaderOptionKey.imageReader1DBarcodeReadDistance : self.readDistanceOption.rawValue]
        
        /// Uncomment and adjust the value for setting the minimum length of variable ITF codes read by
        /// the SDK. Not setting this reader option key will default to using the SDK's default minimum
        /// length.
        // options[ReaderOptionKey.imageReaderITFBarcodeMinimumLength] = 8
        
        return options
    }
    
    // MARK: - Region (Rect) of Interest
    private var samples = [
        ROISample(id: 0, title: "No Region of Interest", identifier: UIAction.Identifier(rawValue: "ROI_None"), roiRect: CGRect(x: 0, y: 0, width: 1, height: 1)),
        ROISample(id: 1, title: "Region Option 1", identifier: UIAction.Identifier(rawValue: "ROI_Option1"), roiRect: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.25)),
        ROISample(id: 2, title: "Region Option 2", identifier: UIAction.Identifier(rawValue: "ROI_Option2"), roiRect: CGRect(x: 0.2, y: 0.5, width: 0.6, height: 0.4))
    ]
    private let regionOverlayLayer = RegionOverlayLayer()
    private var rectOfInterest: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) {
        didSet {
            DispatchQueue.main.async {
                if  self.isViewLoaded {
                    self.view.setNeedsLayout()
                }
            }
        }
    }
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.toggleSmoothing(isEnabled: self.smoothingEnabled)
        
        self.requestVideoAccess()
        self.videoSessionQueue.async {
            self.configureVideoSession()
            self.addAVFoundationObservers()
            self.videoCaptureSession?.startRunning()
        }
        
        // Adding Region of Interest Overlay
        self.previewView.layer.addSublayer(self.regionOverlayLayer)
        self.regionOverlayLayer.frame = self.previewView.bounds
        
        // Buttons with Menu Items
        let roiButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.stack.3d.up.fill"), primaryAction: nil, menu: self.createROIMenu())
        self.rectOfInterestButton = roiButtonItem
        let distanceButtonItem = UIBarButtonItem(image: UIImage(systemName: "ruler.fill"), primaryAction: nil, menu: self.createDistanceReadMenu())
        self.distanceMenuButton = distanceButtonItem
        self.navigationItem.rightBarButtonItems = [roiButtonItem, distanceButtonItem]
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        // Reframing Region of Interest Overlay
        self.updateRegionOfInterest()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in
            if  let videoPreviewLayerConnection = self.previewView.videoPreviewLayer.connection {
                let deviceOrientation = UIDevice.current.orientation
                guard
                    let newVideoOrientation = deviceOrientation.videoOrientation,
                    deviceOrientation.isPortrait || deviceOrientation.isLandscape
                    else { return }
                
                videoPreviewLayerConnection.videoOrientation = newVideoOrientation
            }
            
            // Reframing Region of Interest Overlay
            self.updateRegionOfInterest()
        } completion: { context in
            ()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if  context == &videoSessionRunningObserveContext {
            let newValue = change?[.newKey] as AnyObject?
            guard let isSessionRunning = newValue?.boolValue else { return }
            DispatchQueue.main.async { [unowned self] in
                // Only enable the ability to change camera if the device has more than one camera.
                
                if  isSessionRunning {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.previewView.alpha = 1.0
                        self.previewView.isHidden = false
                    }) { (completed) in
                        //self.previewView.isHidden = false
                    }
                } else {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.previewView.alpha = 0.0
                        self.previewView.isHidden = true
                    }) { (completed) in
                        //self.previewView.isHidden = true
                    }
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - DMSDK Delegate
    
    func updateOverlays(with output: TrackingChange)
    {
        switch output {
        case .appeared(id: let uuid, payload: let payload, metadata: let metadata):
            let layer = DetectionRegionLayer(payload: payload, metadata: metadata, previewLayer: self.previewView.videoPreviewLayer)
            self.previewView.videoPreviewLayer.addSublayer(layer)
            layers[uuid] = layer
        case .moved(id: let uuid, metadata: let metadata):
            if  let found = layers[uuid] {
                found.update(metadata: metadata)
            }
        case .disappeared(id: let uuid):
            if  let found = layers[uuid] {
                if  self.smoothingEnabled {
                    found.animateRemoveFromSuperlayer()
                } else {
                    found.removeFromSuperlayer()
                }
            }
            layers[uuid] = nil
        }
    }
    
    // MARK: - AV Foundation
    
    private func requestVideoAccess()
    {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            ()
        case .denied:
            ()
        case .notDetermined:
            // First time requesting access from the user
            self.videoSessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { (granted: Bool) in
                if  !granted {
                    DispatchQueue.main.async {
                        // Display an alert to the user if permission was not granted.
                    }
                }
                self.videoSessionQueue.resume()
            }
        case .restricted:
            ()
        default:
            ()
        }
    }
    
    private func configureVideoSession()
    {
        guard
            let captureDevice = AVCaptureDevice.default(for: .video) else {
                print("\n~Error in: \(#function)")
                print("Could not get camera device from system.")
                return
        }
        
        let videoCaptureSession = AVCaptureSession()
        self.videoCaptureSession = videoCaptureSession
        
        // Has to 'sync' with the main thread.
        DispatchQueue.main.sync {
            self.previewView.session = self.videoCaptureSession
        }
        
        // Must be called on the video capture session queue.
        videoCaptureSession.beginConfiguration()
        
        do {
            let videoCaptureInput = try AVCaptureDeviceInput(device: captureDevice)
            
            if  videoCaptureSession.canAddInput(videoCaptureInput) {
                videoCaptureSession.addInput(videoCaptureInput)
                self.captureDevice = captureDevice
                
                // DMSDK Setup
                do {
                    
                    let videoCaptureReader = try VideoCaptureReader(symbologies: self.allowedSymbologies, options: self.readerOptions)
                    self.videoCaptureReader = videoCaptureReader
                    
                    if  videoCaptureSession.canAddOutput(videoCaptureReader.captureOutput) {
                        videoCaptureSession.addOutput(videoCaptureReader.captureOutput)
                        videoCaptureReader.setResultsDelegate(self.payloadPublisher, queue: DispatchQueue.main)
                    } else {
                        print("\n~Error in: \(#function)")
                        print("Could not add video capture reader's capture output to video capture session.")
                    }
                    
                } catch {
                    print("\n~Error in: \(#function)")
                    print("Could not create a Video Capture Reader from DMSDK. Enter your Developer DMSDK API License Key in your AppDelegate. Alternatively, you may also enter your DMSDK API License Key in your app's info.plist file with the key `DMSAPIKey`.")
                    fatalError(error.localizedDescription)
                }
                
                DispatchQueue.main.async {
                    guard let statusBarOrientation = self.view.window?.windowScene?.interfaceOrientation else {
                        return
                    }
                    var initialVideoOrientation = AVCaptureVideoOrientation.portrait
                    if  statusBarOrientation != .unknown,
                        let videoOrientation = statusBarOrientation.videoOrientation {
                        initialVideoOrientation = videoOrientation
                    }
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                }
                
            } else {
                print("\n~Error in: \(#function)")
                print("Could not add video capture input to video capture session.")
            }
            
        } catch {
            print("\n~Error in: \(#function)")
            print("Could not create an AVCaptureDeviceInput with the given capture device.")
            print("Error: \(error.localizedDescription)")
        }
        
        self.videoCaptureSession?.commitConfiguration()
    }
    
    private func addAVFoundationObservers()
    {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: Notification.Name("AVCaptureSessionRuntimeErrorNotification"),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: Notification.Name("AVCaptureSessionWasInterruptedNotification"),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: Notification.Name("AVCaptureSessionInterruptionEndedNotification"),
                                               object: nil)
    }
    
    @objc func sessionRuntimeError(notification: NSNotification)
    {
        guard
            let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            else {
                return
        }
        
        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")
        
        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if  error.code == .mediaServicesWereReset {
            videoSessionQueue.async { [unowned self] in
                self.videoCaptureSession?.startRunning()
            }
        }
    }
    
    @objc func sessionWasInterrupted(notification: NSNotification)
    {
        if  let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            
            print("Capture session was interrupted with reason \(reason)")
            
            if reason == AVCaptureSession.InterruptionReason.audioDeviceInUseByAnotherClient ||
                reason == AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient {
            } else if reason == AVCaptureSession.InterruptionReason.videoDeviceNotAvailableWithMultipleForegroundApps {
                
            }
        }
    }
    
    @objc func sessionInterruptionEnded(notification: NSNotification)
    {
        print("Capture session interruption ended")
    }
    
    // MARK: - Updating the Read Distance in DMSDK's Video Capture Reader.
    
    private func toggleSmoothing(isEnabled: Bool)
    {
        // Resetting the publisher and output
        self.payloadOutput?.cancel()
        self.payloadPublisher = PayloadPublisher()
        self.videoCaptureReader?.setResultsDelegate(self.payloadPublisher, queue: DispatchQueue.main)
        
        // Resetting the layers in the view
        self.removeAllLayers()
        
        // Determine which publisher we need, smoothing or not.
        if  isEnabled {
            self.payloadOutput = self.payloadPublisher.tracked().smoothed().sink { (output) in
                self.updateOverlays(with: output)
            }
        } else {
            self.payloadOutput = self.payloadPublisher.tracked().sink { (output) in
                self.updateOverlays(with: output)
            }
        }
    }
    
    @IBAction func smoothingSwitchTapped(_ sender: Any)
    {
        self.smoothingEnabled.toggle()
        self.toggleSmoothing(isEnabled: self.smoothingEnabled)
    }
    
    private var readDistanceOption: ReadDistance = .far {
        didSet {
            self.set1DReadDistanceOption()
        }
    }
    
    /// - Tag: UpdatingReadDistanceReaderOption
    private func set1DReadDistanceOption()
    {
        if  let videoCaptureReader = self.videoCaptureReader {
            try! videoCaptureReader.setSymbologies(self.allowedSymbologies, options: self.readerOptions)
        }
    }
    
    private func removeAllLayers()
    {
        for layer in layers {
            layer.value.removeFromSuperlayer()
        }
        layers.removeAll()
    }
    
    private func updateRegionOfInterest()
    {
        // Hide the overlay if a `rectOfInterest` that is the entire plane is
        // used. That would be CGRect(0, 0, 1, 1).
        let showRegionOfInterest = (self.rectOfInterest != CGRect(x: 0, y: 0, width: 1, height: 1))
        self.regionOverlayLayer.isHidden = !showRegionOfInterest
        if  showRegionOfInterest {
            
            // Update the frame of the region overlay layer
            self.regionOverlayLayer.frame = self.previewView.bounds
            
            //  Convert to normalized camera (flipped) coordinates to pass to
            //  DMSDK's video capture reader.
            let normalizedInCameraCoordinates = self.convertToNormalizedCameraCoordinates(normalizedUIRect: self.rectOfInterest)
            
            //  Convert to points and in UI coordinate space to draw the mask
            //  layer.
            let unnormalizedInCameraCoordinates = self.previewView.videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: normalizedInCameraCoordinates)
            
            self.regionOverlayLayer.locationRect = unnormalizedInCameraCoordinates
            self.videoCaptureReader?.rectOfInterest = normalizedInCameraCoordinates
        }
    }
    
    private func updateSmoothingButtonTitle()
    {
        self.smoothingButton.title =
            self.smoothingEnabled ?
                NSLocalizedString("Smoothing On",  comment: "") :
                NSLocalizedString("Smoothing Off", comment: "")
    }
    
    // MARK: Helper Functions
    
    /// The sample values for region of interest are in normalized, UI view coordinates. This region
    /// (`CGRect`) should be converted to coordinates that work for the device's camera (which is always
    /// in landscape). This helper function will take normalized, UI view-space coordinates and turn them
    /// into normalized camera-device-space coordinates. The result can then be passed to
    /// `videoCaptureReader`'s `rectOfInterest` property.
    /// - Tag: ConvertingToCameraSpaceCoordinates 
    private func convertToNormalizedCameraCoordinates(normalizedUIRect: CGRect) -> CGRect
    {
        //  The selected region coordinates are normalized. Turn the region
        //  `CGRect` into points.
        let unnormalizedRectOfInterest = CGRect(x: normalizedUIRect.origin.x    * self.previewView.bounds.width,
                                                y: normalizedUIRect.origin.y    * self.previewView.bounds.height,
                                                width: normalizedUIRect.width   * self.previewView.bounds.width,
                                                height: normalizedUIRect.height * self.previewView.bounds.height)
        // Use AVCaptureVideoPreviewLayer
        // `metadataOutputRectConverted(fromLayerRect rectInLayerCoordinates: CGRect)`
        // to turn the un-normalized input into normalized camera-device-coordinates.
        let normalizedCameraCoordinates = self.previewView.videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: unnormalizedRectOfInterest)
        return normalizedCameraCoordinates
    }
    
    private func resetROIMenuStates()
    {
        self.rectOfInterestButton.menu = nil
        self.rectOfInterestButton.menu = self.createROIMenu()
    }
    
    private func createROIMenu() -> UIMenu
    {
        let actions = self.samples.map { roiSample in
            return UIAction(title: roiSample.title,
                            identifier: roiSample.identifier,
                            state: roiSample.roiRect == self.rectOfInterest ? .on : .off) { action in
                self.rectOfInterest = roiSample.roiRect
                
                // Convert the selected region of interest to the camera-space
                // coordinates. The selected region must be translated but also
                // rotated since the camera device always works in landscape.
                // AVCaptureVideoPreviewLayer provides the necessary functions
                // to do such conversions.
                self.videoCaptureReader?.rectOfInterest = self.convertToNormalizedCameraCoordinates(normalizedUIRect: roiSample.roiRect)
                self.resetROIMenuStates()
            }
        }
        let menu = UIMenu(title: "Region of Interest Examples", identifier: UIMenu.Identifier(rawValue: "OptionsMenu"), children: actions)
        
        return menu
    }
    
    private func resetDistanceMenuStates()
    {
        self.distanceMenuButton.menu = nil
        self.distanceMenuButton.menu = self.createDistanceReadMenu()
    }
    
    private func createDistanceReadMenu() -> UIMenu
    {
        let actionFar = UIAction(title: "Far Distance", identifier: UIAction.Identifier(rawValue: "Distance_Far"), state: self.readDistanceOption == .far ? .on : .off) { action in
            self.readDistanceOption = .far
            self.resetDistanceMenuStates()
        }
        
        let optionBoth = UIAction(title: "Far + Near Distance", identifier: UIAction.Identifier(rawValue: "Distance_Both"), state: self.readDistanceOption == [.far, .near] ? .on : .off) { action in
            self.readDistanceOption = [.far, .near]
            self.resetDistanceMenuStates()
        }
        
        let optionNear = UIAction(title: "Near Distance", identifier: UIAction.Identifier(rawValue: "Distance_Near"), state: self.readDistanceOption == .near ? .on : .off) { action in
            self.readDistanceOption = .near
            self.resetDistanceMenuStates()
        }
        
        let menu = UIMenu(title: "Distance Reading", identifier: UIMenu.Identifier(rawValue: "DistanceMenu"), children: [actionFar, optionBoth, optionNear])
        
        return menu
    }
}

// MARK: - Extensions & Classes

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}

class PreviewView: UIView
{
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.videoGravity = .resizeAspectFill
            videoPreviewLayer.session = newValue
        }
    }
    
    // MARK: UIView
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
