// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK

class ContainerViewController: UIViewController, DetectorViewControllerDelegate, MultimodalProcessorDelegate
{
    let extendedReadRangeEnabled = false

    @IBOutlet weak var crosshairView: UIView?
    
    var resultsTableViewController: ResultsTableViewController?
    var scannerViewController: ScannerViewController?
    {
        didSet
        {

            // * IMPORTANT: Set desired symbologies for video and audio readers. You may remove any symbologies you don't need to use.
            //              Alternatively, you may also use .allImage and .allAudio.
            
            do {
                try self.scannerViewController?.setSymbologies([.imageDigimarc, .audioDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ], options: [:])
            } catch {
                fatalError(error.localizedDescription)
            }
            
            self.scannerViewController?.delegate = self
            self.scannerViewController?.automaticallyUpdatesRectOfInterest = true
        }
    }
    
    var lastSeenPayloads: [Payload] = []
    var multimodalProcessor: MultimodalProcessor?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.multimodalProcessor = MultimodalProcessor(resolver: self.scannerViewController?.resolver)
        self.multimodalProcessor?.delegate = self
    }

    func detectorViewControllerDidCancel(_ viewController: DetectorViewController)
    {
        print("detectorViewControllerDidCancel: \(viewController)")
    }

    func detectorViewController(_ viewController: DetectorViewController, didReceiveError error: Error)
    {
        if((error as? URLError)?.code != URLError.cancelled) {
            let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler:nil))
            self.present(alertController, animated: true, completion: nil)
        
            print("detectorViewController: \(viewController) didReceiveError: \(error)")
        }
    }

    func detectorViewController(_ viewController: DetectorViewController, resolvedContent: ResolvedContent, for payload: Payload)
    {    
        self.resultsTableViewController?.resolvedContent[payload.id] = resolvedContent
        self.multimodalProcessor?.append(payload: payload, completion: nil)
    }

    func detectorViewController(_ viewController: DetectorViewController, shouldResolvePayloadsFor result: ReaderResult) -> [Payload]?
    {
        let newPayloads = result.payloads.filter
        {
            return !self.lastSeenPayloads.contains($0)
        }

        if newPayloads.count > 0
        {
            self.lastSeenPayloads = newPayloads
    
            return newPayloads
        }
        
        return []
    }
    
    func multimodalProcessor(_ multimodalProcessor: MultimodalProcessor, foundPrioritizedPayload payload: Payload)
    {
        self.resultsTableViewController?.update(with: payload)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let scannerViewControllerDestination = segue.destination as? ScannerViewController {
            self.scannerViewController = scannerViewControllerDestination
        }
        if let resultsTableViewController = segue.destination as? ResultsTableViewController {
            self.resultsTableViewController = resultsTableViewController
        }
    }
}
