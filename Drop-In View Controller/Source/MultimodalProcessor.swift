// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK

protocol MultimodalProcessorDelegate: AnyObject
{
    func multimodalProcessor(_ multimodalProcessor: MultimodalProcessor, foundPrioritizedPayload payload: Payload)
}

class MultimodalProcessor: NSObject
{
    weak var delegate: MultimodalProcessorDelegate?

    var timer: Timer?
    let timeInterval = TimeInterval(0.5)
    
    var payloads: [Payload] = []
    var smartLabelPayloads: [Payload] = []
    var imageWatermarkPayloads: [Payload] = []
    var oneDimensionalBarcodePayloads: [Payload] = []
    var twoDimensionalBarcodePayloads: [Payload] = []
    var allOtherPayloads: [Payload] = []

    let resolver: Resolver?
    let operationQueue = OperationQueue()
    var operations: [String : Operation] = [:]

    override convenience init()
    {
        self.init(resolver: nil)
    }

    init(resolver: Resolver?)
    {
        self.resolver = nil
        
        super.init()
        
        self.operationQueue.name = "Multimodal Resolving Operation Queue"
    }

    func append(payload: Payload, completion: ResolveCompletionBlock?)
    {
        self.timer = self.timer ?? Timer.scheduledTimer(timeInterval: self.timeInterval, target: self, selector: #selector(prioritizeCollectedPayloads), userInfo: nil, repeats: false)
    
    
        if payload.symbology.contains(.imageDigimarc)
        {
            if !self.imageWatermarkPayloads.contains(payload)
            {
                self.imageWatermarkPayloads.append(payload)
            }
        }
        else if payload.symbology.contains(.qrCode)
        {
            if !self.twoDimensionalBarcodePayloads.contains(payload)
            {
                self.twoDimensionalBarcodePayloads.append(payload)
            }
        }
        else if payload.symbology.isSubset(of: .allBarcodes)
        {
            if !self.oneDimensionalBarcodePayloads.contains(payload)
            {
                self.oneDimensionalBarcodePayloads.append(payload)
            }
        }
        else
        {
            if !self.allOtherPayloads.contains(payload)
            {
                self.allOtherPayloads.append(payload)
            }
        }
        
        if let resolver = self.resolver, let completion = completion
        {
            weak var weakResolveOperation: BlockOperation?
            
            let resolveOperation = BlockOperation
            {
                if !(weakResolveOperation?.isCancelled ?? true)
                {
                    let resolveFinishedLock = NSConditionLock()
                    
                    resolver.resolve(payload, queue: OperationQueue.main)
                    {
                        (resolvedContent: ResolvedContent?, error: Error?) in
                        
                        completion(resolvedContent, error)
                        
                        resolveFinishedLock.lock()
                        resolveFinishedLock.unlock(withCondition: 1)
                    }

                    resolveFinishedLock.lock(whenCondition: 1)
                    resolveFinishedLock.unlock()
                }
            }
            
            weakResolveOperation = resolveOperation
            
            self.operations[payload.id] = resolveOperation
            self.operationQueue.addOperation(resolveOperation)
        }
    }
    
    @objc func prioritizeCollectedPayloads()
    {
        // Multi-Modal Requirements:
        // 1. Current auto-open setting should enable Multi-Modal behavior.
        // 2. Default time delay for Multi-Modal is 1 second.
        // 3. Secret setting allows for configuration of Multi-Modal delay time.

        // Invalidate and clear out the Timer object. It will get recreated when new Payloads come in if necessary.
        self.timer?.invalidate()
        self.timer = nil

        // 1. SmartLabel has top priority in what should auto-open
        self.payloads.append(contentsOf: self.smartLabelPayloads)
        
        // 2. followed by image watermarks
        self.payloads.append(contentsOf: self.imageWatermarkPayloads)

        // 3. 1D barcodes followed by QR codes come next.
        self.payloads.append(contentsOf: self.oneDimensionalBarcodePayloads)
        self.payloads.append(contentsOf: self.twoDimensionalBarcodePayloads)

        // 4. Finally, anything else
        self.payloads.append(contentsOf: self.allOtherPayloads)

        // This is the payload with the highest priority:
        guard let payload = self.payloads.first else { return }
        
        let queuedOperation = self.operations[payload.id]
        
        if let _ = self.resolver
        {
            weak var weakCompletionOperation: BlockOperation?
            let completionOperation = BlockOperation
            {
                if !(weakCompletionOperation?.isCancelled ?? true)
                {
                    self.delegate?.multimodalProcessor(self, foundPrioritizedPayload: payload)
                    self.clearCollectedItems()
                }
            }
            
            weakCompletionOperation = completionOperation
            
            if let queuedOperation = queuedOperation
            {
                completionOperation.addDependency(queuedOperation)
            }
        }
        else
        {
            self.delegate?.multimodalProcessor(self, foundPrioritizedPayload: payload)
            
            self.clearCollectedItems()
        }
    }
    
    func stop()
    {
        self.timer?.invalidate()
        self.timer = nil

        self.clearCollectedItems()
    }
    
    func clearCollectedItems()
    {
        self.smartLabelPayloads.removeAll()
        self.imageWatermarkPayloads.removeAll()
        self.oneDimensionalBarcodePayloads.removeAll()
        self.twoDimensionalBarcodePayloads.removeAll()
        self.allOtherPayloads.removeAll()
        self.payloads.removeAll()
        self.operations.removeAll()
    }
}
