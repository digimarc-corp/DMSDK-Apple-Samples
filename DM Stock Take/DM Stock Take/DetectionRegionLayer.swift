// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2020
//
// - - - - - - - - - - - - - - - - - - - -

import Foundation
import QuartzCore
import UIKit
import AVFoundation
import DMSDK

class DetectionRegionLayer: CAShapeLayer, CAAnimationDelegate {
    
    weak private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    let payload: Payload
    var pendingDeletion = false 
    private let labelLayer = CATextLayer()
    
    init(payload: Payload, metadata: PayloadMetadata, previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        self.payload = payload
        super.init()
        self.fillColor = UIColor.red.withAlphaComponent(0.67).cgColor
        self.borderWidth = 5.0
        self.strokeColor = UIColor.red.cgColor
        self.update(metadata: metadata)
        
        labelLayer.fontSize = 14.0
        labelLayer.backgroundColor = UIColor.black.withAlphaComponent(0.25).cgColor
        labelLayer.foregroundColor = UIColor.white.cgColor
        labelLayer.contentsScale = UIScreen.main.scale
        labelLayer.shadowColor = UIColor.black.cgColor
        labelLayer.shadowOffset = CGSize(width: 0.0, height: 0.75)
        labelLayer.shadowOpacity = 1.0
        labelLayer.shadowRadius = 0.0
        if  let rawValue = CPMParser(cpmPath: payload.id)?.pathComponents[CPMComponent.value.rawValue] {
            labelLayer.string = rawValue
        }
        labelLayer.alignmentMode = .center
        labelLayer.truncationMode = .none
        labelLayer.cornerRadius = 4.0
        
        self.addSublayer(labelLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSublayers() {
        self.updateLabelPosition()
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        self.removeFromSuperlayer()
    }
    
    func update(metadata: PayloadMetadata) {
        let layerConvertedPath = CGMutablePath()
        guard let previewLayer = self.previewLayer,  let metadataPath = metadata.path  else {
            return
        }
        metadataPath.applyWithBlock { (pathElementPointer) in
            switch pathElementPointer.pointee.type {
            case .moveToPoint:
                let newPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: pathElementPointer.pointee.points.pointee)
                layerConvertedPath.move(to: newPoint)
            case .addLineToPoint:
                let newPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: pathElementPointer.pointee.points.pointee)
                layerConvertedPath.addLine(to: newPoint)
            case .closeSubpath:
                layerConvertedPath.closeSubpath()
            default:
                ()
            }
        }
        self.path = layerConvertedPath
        self.updateLabelPosition()
    }
    
    private func updateLabelPosition() {
        if  let currentPath = self.path {
            let longestSide = min(max(max(currentPath.boundingBox.width, currentPath.boundingBox.height), 52), 52)
            labelLayer.frame = CGRect(x: self.bounds.minX, y: self.bounds.minY, width: longestSide * 2.0, height: 17.0)
            labelLayer.position = CGPoint(x: currentPath.boundingBox.midX, y: currentPath.boundingBox.midY)
        }
    }
    
    func animateRemoveFromSuperlayer() {
        let layerConvertedPath = CGMutablePath()
        layerConvertedPath.move(to: CGPoint(x: self.path!.boundingBox.midX, y: self.path!.boundingBox.midY))
        layerConvertedPath.addLine(to: CGPoint(x: self.path!.boundingBox.midX, y: self.path!.boundingBox.midY))
        layerConvertedPath.closeSubpath()
        
        let animation = CABasicAnimation(keyPath: "path")
        animation.delegate = self
        animation.fromValue = self.path
        animation.toValue = layerConvertedPath
        animation.duration = 0.1
        animation.isRemovedOnCompletion = true
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1
        fadeAnimation.toValue = 0
        fadeAnimation.duration = 0.1
        
        // Attach animations to layers
        self.add(animation, forKey: animation.keyPath)
        self.labelLayer.add(fadeAnimation, forKey: fadeAnimation.keyPath)
        
        // Final values
        self.path = layerConvertedPath
        self.labelLayer.opacity = 0
    }
}
