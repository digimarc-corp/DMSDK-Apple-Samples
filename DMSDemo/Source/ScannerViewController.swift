// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import AVFoundation
import DMSDK
import SafariServices

var _illuminate_configuration: DMSDK.IlluminateConfiguration?


class ScannerViewController: UIViewController, AudioCaptureReaderResultsDelegate, VideoCaptureReaderResultsDelegate
{

    @IBOutlet weak var previewView: VideoPreviewLayerView?
    @IBOutlet var microphoneView: MicrophoneView?

    let audioSymbologies: Symbologies = [ .audioDigimarc ]
    let videoSymbologies: Symbologies = [ .imageDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ]
    
    var audioCaptureSession: AVCaptureSession?
    var videoCaptureSession: AVCaptureSession?
    var audioCaptureReader: AudioCaptureReader?
    var videoCaptureReader: VideoCaptureReader?
    var readersEnabled:Bool = false {
        willSet {
            self.audioCaptureReader?.enabled = newValue
            self.videoCaptureReader?.enabled = newValue
        }
    }
    
    private static var torchStateContext = 1
    private var torchButton:UIBarButtonItem?
    private var cameraDevice:AVCaptureDevice? {
        didSet {
            oldValue?.removeObserver(self, forKeyPath: "torchAvailable")
            oldValue?.removeObserver(self, forKeyPath: "torchMode")
            cameraDevice?.addObserver(self, forKeyPath: "torchAvailable", options: [.initial, .new], context: &ScannerViewController.torchStateContext)
            cameraDevice?.addObserver(self, forKeyPath: "torchMode",      options: [.initial, .new], context: &ScannerViewController.torchStateContext)
        }
    }
    
    let setupQueue = DispatchQueue(label: "Scanner Setup Queue")
    
    var resolver: Resolver?

    let alertController = UIAlertController(title: "", message: "", preferredStyle: .alert)
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if  #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            self.navigationItem.standardAppearance = appearance
            self.navigationItem.scrollEdgeAppearance = appearance
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
        self.setupAudioCaptureReader()
        self.setupVideoCaptureReader()
        self.setupResolver()
        
        self.startCaptureSessions()
        
        self.alertController.addAction(UIAlertAction(title: "OK", style: .default) { (action:UIAlertAction) in
            
            // Resetting the capture readers so that user can re-scan the same item again when coming back to this view.
            self.resetReaders()
            
            // Restarting the readers
            self.readersEnabled = true
        })
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.resetReaders()
        self.readersEnabled = true
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        self.readersEnabled = false
    }
    
    @objc func applicationDidBecomeActive()
    {
        self.resetReaders()
        self.readersEnabled = true
    }
    
    @objc func applicationWillResignActive()
    {
        self.readersEnabled = false
    }
    
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?)
    {
        self.readersEnabled = false
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)?)
    {
        super.dismiss(animated: flag, completion: completion)
        self.resetReaders()
        self.readersEnabled = true
    }
    
    func startCaptureSessions()
    {
        // Only start the capture session if running on a real device:
        #if os(iOS) && (arch(arm) || arch(arm64))
        
            self.setupQueue.async
            {
                if let session = self.audioCaptureSession, session.isRunning == false
                {
                    session.startRunning()
                }

                if let session = self.videoCaptureSession, session.isRunning == false
                {
                    session.startRunning()
                }
            }
            
        #endif
    }
    
    func stopCaptureSessions()
    {
        self.setupQueue.async
        {
            if let session = self.audioCaptureSession, session.isRunning == true
            {
                session.stopRunning()
            }

            if let session = self.videoCaptureSession, session.isRunning == true
            {
                session.stopRunning()
            }
        }
    }
    
    func setupAudioCaptureReader()
    {
        self.audioCaptureSession = AVCaptureSession()
        
        do {
            self.audioCaptureReader = try AudioCaptureReader(symbologies: self.audioSymbologies, options: [:])
        } catch {
            if  let readerError = error as? DMSError {
                if  readerError.code == .invalidLicense {
                    fatalError(readerError.localizedDescription)
                }
            }
            return
        }

        // Request access to the microphone
        AVCaptureDevice.requestAccess(for: AVMediaType.audio)
        {
            (granted: Bool) in
            guard granted else { return }
            
            self.setupQueue.async
            {
                do
                {
                    guard
                    let audioCaptureSession = self.audioCaptureSession,
                    let audioCaptureReader = self.audioCaptureReader
                    else
                    {
                        return
                    }
                    
                    // Register our app with the system for capturing audio
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.record)))
                    try AVAudioSession.sharedInstance().setActive(true)
                
                    // Configure audio capture
                    audioCaptureSession.beginConfiguration()
                    defer { audioCaptureSession.commitConfiguration() }
                    
                    if let defaultAudioDevice = AVCaptureDevice.default(for: AVMediaType.audio) {
                        let deviceInput = try AVCaptureDeviceInput(device: defaultAudioDevice)
                        
                        if audioCaptureSession.canAddInput(deviceInput)
                        {
                            audioCaptureSession.addInput(deviceInput)
                        }
                        else
                        {
                            throw NSError(domain: "ScannerViewControllerErrorDomain", code: 1, userInfo: [ NSLocalizedDescriptionKey : "Couldn't add audio capture device input." ])
                        }
                        
                        audioCaptureReader.setResultsDelegate(self, queue: DispatchQueue.main)
                        audioCaptureSession.addOutput(audioCaptureReader.captureOutput)
                        
                        DispatchQueue.main.async
                            {
                                self.microphoneView?.isHidden = false
                        }
                    }
                }
                catch
                {
                    // Handle any audio setup errors here:
                    print(error)
                    self.showError(error)
                }
            }
        }
    }
    
    func setupVideoCaptureReader()
    {
        
        _illuminate_configuration = DMSDK.IlluminateConfiguration(
            env: DMSDK.IlluminateEnvironment.production,
            accountId: "account id here",
            name: "Mobile Verify Testing",
            apiKey: "api key here",
            fields: [.redirectUrl]
        )

        
        self.videoCaptureSession = AVCaptureSession()
        do {
            self.videoCaptureReader = try VideoCaptureReader(symbologies: self.videoSymbologies, options: [
                DMSDK.ReaderOptionKey.illuminateServiceConfiguration: _illuminate_configuration])
        } catch {
            if  let readerError = error as? DMSError {
                if  readerError.code == .invalidLicense {
                    fatalError(readerError.localizedDescription)
                }
                return
            }
        }

        // Request access to the camera
        AVCaptureDevice.requestAccess(for: AVMediaType.video)
        {
            (granted: Bool) in
            guard granted else {
                DispatchQueue.main.async {
                    self.navigationItem.rightBarButtonItem = nil
                    self.torchButton = nil
                }
                return
            }

            self.setupQueue.async
            {
                do
                {
                    guard
                    let videoCaptureSession = self.videoCaptureSession,
                    let videoCaptureReader = self.videoCaptureReader,
                        let videoCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)
                    else
                    {
                        return
                    }

                    // Configure video capture
                    videoCaptureSession.beginConfiguration()
                    defer { videoCaptureSession.commitConfiguration() }
                    
                    let deviceInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
                    
                    if videoCaptureSession.canAddInput(deviceInput)
                    {
                        videoCaptureSession.addInput(deviceInput)
                        self.cameraDevice = videoCaptureDevice
                    }
                    else
                    {
                        throw NSError(domain: "ScannerViewControllerErrorDomain", code: 1, userInfo: [ NSLocalizedDescriptionKey : "Couldn't add video capture device input." ])
                    }
                    
                    videoCaptureReader.setResultsDelegate(self, queue: DispatchQueue.main)
                    videoCaptureSession.addOutput(videoCaptureReader.captureOutput)

                    DispatchQueue.main.sync
                    {
                        if let previewLayer = self.previewView?.layer as? AVCaptureVideoPreviewLayer
                        {
                            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                        }

                        self.previewView?.captureSession = videoCaptureSession
                    }
                }
                catch
                {
                    // Handle any video setup errors here:
                    print(error)
                    self.showError(error)
                }
            }
        }
    }
    
    private func setupResolver()
    {
        do {
            self.resolver = try Resolver()
        } catch {
            if
                let resolverError = error as? DMSError,
                resolverError.code == .invalidLicense {
                fatalError(resolverError.localizedDescription)
            }
        }
        
    }
    
    func captureSessionRuntimeError(notification: Notification)
    {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
        {
            print("DMS Demo - Capture Session Runtime Error: \(error.localizedDescription) \(error.code)")
        
            self.showError(error)
        }
        
        self.setupAudioCaptureReader()
        self.setupVideoCaptureReader()
    }

    func captureSessionWasInterrupted(notification: Notification)
    {
        if let interruptionReason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason
        {
            if interruptionReason == .videoDeviceNotAvailableWithMultipleForegroundApps
            {
                // Typically, you cannot run the AV hardware until the other app using it releases them.
                print("DMS Demo - Capture Session: Device Not Available With Multiple Foreground Apps.")
            }
        }
    }

    func captureSessionInterruptionEnded(notification: Notification)
    {
        self.startCaptureSessions()
    }

    func audioCaptureReader(_ audioCaptureReader: AudioCaptureReader, didOutputResult result: ReaderResult)
    {
        // check result.payloads or result.newPayloads for detected payloads
        if result.newPayloads.count > 0
        {
            print("Audio Result: \(result.newPayloads)")
            self.resolvePayloads(result.newPayloads)
        }
    }
    
    func videoCaptureReader(_ videoCaptureReader: VideoCaptureReader, didOutputResult result: ReaderResult)
    {
        // check result.payloads or result.newPayloads for detected payloads
        if result.newPayloads.count > 0
        {
            print("Video Result: \(result.newPayloads)")
            self.resolvePayloads(result.newPayloads)
        }
    }
   
    func resolvePayloads(_ payloads: [Payload])
    {
        if let payload = payloads.first
        {
            var isV11 = false
            
            let options = [ReaderOptionKey.illuminateServiceConfiguration: _illuminate_configuration as Any];
            
            DispatchQueue.main.async
            {
                if let metadata = self.resolver?.resolveV11(payload, options: options)
                {
                    if !metadata.isEmpty
                    {
                        isV11 = true
                        
                        if let redirectUrl = metadata["redirectUrl"]
                        {
                            if let URL = URL(string: redirectUrl)
                            {
                                self.openURL(URL)
                            }
                        }
                    }
                }
                
                if !isV11
                {
                    self.resolver?.resolve(payload, queue: OperationQueue.main)
                    {
                        (content, error) in
                        
                        if let error = error
                        {
                            self.showError(error)
                            
                            print(error)
                        }
                        else if let content = content
                        {
                            if let url = content.items.first?.url
                            {
                                self.openURL(url)
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if context == &ScannerViewController.torchStateContext {
            DispatchQueue.main.async {
                self.updateTorchButtonState()
            }
        }
    }
    
    func openURL(_ url: URL)
    {
        if let scheme = url.scheme, ["http", "https", "file"].contains(scheme.lowercased())
        {
            if let unwrappedCaptureDevice = self.cameraDevice, ((try? unwrappedCaptureDevice.lockForConfiguration()) != nil) {
                if unwrappedCaptureDevice.isTorchAvailable {
                    unwrappedCaptureDevice.torchMode = .off
                }
                unwrappedCaptureDevice.unlockForConfiguration()
            }
            
            // Guards against attempting to display another web view if there is one already presenting or we're showing an alert.
            if self.alertController.presentingViewController == nil && self.presentedViewController == nil {
                self.present(SFSafariViewController(url: url), animated: true, completion: nil)
            }
        }
        else
        {
            if UIApplication.shared.canOpenURL(url)
            {
                if #available(iOS 10.0, *)
                {
                    // New for iOS 10 and newer
                    UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: { (success:Bool) in })
                }
                else
                {
                    // iOS 9 and older.
                    UIApplication.shared.openURL(url)
                }
            }
            else
            {
                self.showMessage("\(url)", title: "Invalid URL")
            }
        }
    }
    
    @objc func toggleTorch()
    {
        guard
            let cameraDevice = self.cameraDevice,
            let torchButton = self.torchButton
            else {
                return
        }
        
        if cameraDevice.hasTorch {
            do {
                // Disable the torch button here to prevent pressing while changing states.
                torchButton.isEnabled = false
                try cameraDevice.lockForConfiguration()
                
                if cameraDevice.torchMode == AVCaptureDevice.TorchMode.on {
                    cameraDevice.torchMode = AVCaptureDevice.TorchMode.off
                } else {
                    cameraDevice.torchMode = AVCaptureDevice.TorchMode.on
                }
                
                cameraDevice.unlockForConfiguration()
                torchButton.isEnabled = true
            } catch {
                print(error)
            }
        }
    }
    
    func resetReaders()
    {
        self.audioCaptureReader?.reset()
        self.videoCaptureReader?.reset()
    }
    
    func updateTorchButtonState()
    {
        // Display/Hide Torch Button
        guard let cameraDevice = self.cameraDevice else {
            return
        }
        
        if cameraDevice.isTorchAvailable {
            if self.torchButton == nil {
                self.torchButton = UIBarButtonItem(image: UIImage(named: "torch-off")!, style: .plain, target: self, action: #selector(self.toggleTorch))
            }
            self.navigationItem.rightBarButtonItem = self.torchButton
        } else {
            self.navigationItem.rightBarButtonItem = nil
            self.torchButton = nil
        }
        
        // Setting Torch Button State
        guard let torchButton = self.torchButton else {
            return
        }
        
        if cameraDevice.torchMode == AVCaptureDevice.TorchMode.on {
            torchButton.image = UIImage(named: "torch")!
        } else if cameraDevice.torchMode == AVCaptureDevice.TorchMode.off {
            torchButton.image = UIImage(named: "torch-off")!
        }
    }

    func showMessage(_ message: String?, title: String?)
    {
        self.alertController.title = title
        self.alertController.message = message
        
        if self.alertController.presentingViewController == nil
        {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func showError(_ error: Error)
    {
        self.showMessage(error.localizedDescription, title: NSLocalizedString("Error", comment: "Error Message Title"))
    }
}

// VideoPreviewLayerView is a view that is backed with an AVCaptureVideoPreviewLayer
class VideoPreviewLayerView: UIView
{
    override class var layerClass: AnyClass
    {
        get { return AVCaptureVideoPreviewLayer.self }
    }

    var previewLayer: AVCaptureVideoPreviewLayer?
    {
        get { return self.layer as? AVCaptureVideoPreviewLayer }
    }

    var captureSession: AVCaptureSession?
    {
        get { return self.previewLayer?.session }
        set { self.previewLayer?.session = newValue }
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
