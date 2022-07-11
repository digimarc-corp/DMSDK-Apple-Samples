// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK

class MenuViewController: UIViewController, DetectorViewControllerDelegate
{
    var reenableDetectionWhenAppResumes: Bool = false;
    var options: [ReaderOptionKey: Any] = [:]
    weak var currentViewController: DetectorViewController?
    
    // MARK: - View Controller Lifespan
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground(notification:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(notification:)), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notifications

    @objc func applicationWillEnterForeground(notification: NSNotification)
    {
        if self.reenableDetectionWhenAppResumes
        {
            self.currentViewController?.detectionEnabled = true
            self.reenableDetectionWhenAppResumes = false
        }
    }

    @objc func applicationWillResignActive(notification: NSNotification)
    {
        // Only register for this if and only if we get a temporary interruption. We will de-register when we are done running applicationDidBecomeActive:
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func applicationDidBecomeActive(notification: NSNotification)
    {
        if self.reenableDetectionWhenAppResumes
        {
            self.currentViewController?.detectionEnabled = true
            self.reenableDetectionWhenAppResumes = false
        }

        // We only want to be registered for this when we need to, so we will unregister when we are done.
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    // MARK: - View Actions
    
    @IBAction func showReaderViewControllerModally(sender: Any)
    {
        let viewController = DetectorViewController(nibName: nil, bundle: nil)
    
        // * IMPORTANT: Set desired symbologies for video and audio readers. You may remove any symbologies you don't need to use.
        //              Alternatively, you may also use .allImage and .allAudio.
    
        try? viewController.setSymbologies([.imageDigimarc, .audioDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ], options: self.options)
        viewController.delegate = self
        viewController.automaticallyUpdatesRectOfInterest = true
    
        self.present(viewController, animated: true, completion: nil)
    }

    @IBAction func showReaderViewControllerAsNavigation(sender: Any)
    {
        let viewController = DetectorViewController(nibName: nil, bundle: nil)

        // * IMPORTANT: Set desired symbologies for video and audio readers. You may remove any symbologies you don't need to use.
        //              Alternatively, you may also use .allImage and .allAudio.
        
        try? viewController.setSymbologies([.imageDigimarc, .audioDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ], options: self.options)
        viewController.delegate = self
        viewController.automaticallyUpdatesRectOfInterest = true

        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
    @IBAction func showDetectionLocationViewControllerAsNavigation(_ sender: Any)
    {
        let viewController = DetectorViewController(nibName: nil, bundle: nil)
        
        // * IMPORTANT: Set desired symbologies for video and audio readers. You may remove any symbologies you don't need to use.
        //              Alternatively, you may also use .allImage and .allAudio.
        
        try? viewController.setSymbologies([.imageDigimarc, .audioDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ], options: self.options)
        viewController.delegate = self
        viewController.automaticallyUpdatesRectOfInterest = true
        
        // Enabling & customizing how the image detection location style overlays
        // are displayed over the preview.
        let imageDetectionLocationStyle = ImageDetectionLocationStyle()
        imageDetectionLocationStyle.borderColor = UIColor.red
        imageDetectionLocationStyle.fillColor = UIColor.red.withAlphaComponent(0.6)
        imageDetectionLocationStyle.borderWidth = 2.0
        viewController.showImageDetectionLocation = true
        viewController.imageDetectionLocationStyle = imageDetectionLocationStyle
        
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
    @IBAction func showRectOfInterestViewControllerAsNavigation(_ sender: Any)
    {
        let viewController = RegionOfInterestViewController(nibName: nil, bundle: nil)
        
        // * IMPORTANT: Set desired symbologies for video and audio readers. You may remove any symbologies you don't need to use.
        //              Alternatively, you may also use .allImage and .allAudio.
        
        try? viewController.setSymbologies([.imageDigimarc, .audioDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ], options: self.options)
        viewController.delegate = self
        
        self.navigationController?.pushViewController(viewController, animated: true)
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let viewController = segue.destination as? DetectorViewController
        {
    
            // * IMPORTANT: Set desired symbologies for video and audio readers. You may remove any symbologies you don't need to use.
            //              Alternatively, you may also use .allImage and .allAudio.
        
            try? viewController.setSymbologies([.imageDigimarc, .audioDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ], options: self.options)
            viewController.delegate = self
            viewController.automaticallyUpdatesRectOfInterest = true
        }
    }

    @IBAction func showCustomUIViewController(sender: Any)
    {
        if let viewController = UIStoryboard(name: "CustomUIExample", bundle: nil).instantiateInitialViewController() as? ContainerViewController
        {
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }

    // MARK: - SDK Delegate Methods
    
    func detectorViewController(_ viewController: DetectorViewController, shouldResolvePayloadsFor result: ReaderResult) -> [Payload]?
    {
        //  If `showsImageDetectionLocation` is enabled, resolving is disabled
        //  to showcase the image detection location on screen.
        if  viewController.showImageDetectionLocation
        {
            return nil
        }
        return result.payloads
    }

    public func detectorViewController(_ viewController: DetectorViewController, resolvedContent: ResolvedContent, for payload: Payload)
    {
        if viewController.presentingViewController != nil
        {
            self.dismiss(animated: false, completion: nil)
        }

        if let resolvedContentItemURL = resolvedContent.items.first?.url
        {
            UIApplication.shared.open(resolvedContentItemURL, options: [:], completionHandler: { (opened) in
                if  opened {
                    // openURL can be delayed. Turn off detection until the app comes back to avoid
                    // new results between closing the app and reopening it.
                    self.currentViewController = viewController
                    self.reenableDetectionWhenAppResumes = true
                    viewController.detectionEnabled = false
                }
            })
        }
    }
    
    public func detectorViewController(_ viewController: DetectorViewController, didReceiveError error: Error)
    {
        if((error as? URLError)?.code != URLError.cancelled) {
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

            viewController.present(alert, animated: true, completion: nil)
        }
    }
}

