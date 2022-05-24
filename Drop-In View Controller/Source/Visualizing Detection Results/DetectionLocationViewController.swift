//
//  DetectionLocationViewController.swift
//  DigimarcVC
//
//  Created by Guzman, Mario on 7/6/18.
//  Copyright © 2018 Digimarc. All rights reserved.
//

import UIKit
import DMSDK

class DetectionLocationViewController: DetectorViewController, DetectorViewControllerDelegate
{
    private var shapeLayer = CAShapeLayer()
    private var path: CGPath? {
        didSet {
            self.updateShapeLayer()
        }
    }
    
    // MARK: - UIViewController Lifecycle functions
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.delegate = self
        
        if let unwrappedPreviewLayer = self.previewLayer {
            unwrappedPreviewLayer.addSublayer(shapeLayer)
            self.setShapeLayersColors()
            shapeLayer.lineWidth = 2.0
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Updates the shape drawn on screen to its new position during device rotation.
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.updateShapeLayer(shouldAnimate: true)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if  #available(iOS 13.0, *) {
            if  previousTraitCollection?.userInterfaceStyle != self.traitCollection.userInterfaceStyle {
                // A layer's color doesn't update the way a view's tint color does
                // when changing between light and dark mode. These updates should
                // be done manually.
                self.setShapeLayersColors()
            }
        }
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    private func setShapeLayersColors()
    {
        shapeLayer.fillColor = self.view.tintColor.withAlphaComponent(0.25).cgColor
        shapeLayer.strokeColor = self.view.tintColor.cgColor
    }
    
    // MARK: - DetectorViewControllerDelegate functions
    
    func detectorViewController(_ viewController: DetectorViewController, shouldResolvePayloadsFor result: ReaderResult) -> [Payload]?
    {
        for payload in result.payloads {
            // Check to see if we have a detection region (CGPath)
            // and a preview layer onto which it will be drawn on.
            if  let locationPath = result.metadata(for: payload)?.path {
                self.path = locationPath
            }
        }
        
        if  result.payloads.isEmpty && !Symbologies.allImage.intersection(result.executedSymbologies).isEmpty {
            self.path = nil
        }
            
        // We're not wanting to resolve anything here since we just want to
        // display location for results
        return nil
    }
    
    // MARK: - Shape dimension functions
    
    private func updateShapeLayer(shouldAnimate: Bool = false)
    {
        guard
            let unwrappedPath = self.path,
            let videoPreviewLayer = self.previewLayer
            else {
                self.shapeLayer.path = CGMutablePath()
                return
        }
        
        let layerConvertedPath = CGMutablePath()
        unwrappedPath.applyWithBlock { (pathElementPointer) in
            switch pathElementPointer.pointee.type {
            case .moveToPoint:
                let newPoint = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: pathElementPointer.pointee.points.pointee)
                layerConvertedPath.move(to: newPoint)
            case .addLineToPoint:
                let newPoint = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: pathElementPointer.pointee.points.pointee)
                layerConvertedPath.addLine(to: newPoint)
            case .closeSubpath:
                layerConvertedPath.closeSubpath()
            default:
                ()
            }
        }
        
        // Set the new path to the shape layer on screen.
        shapeLayer.path = layerConvertedPath
        
        if shouldAnimate {
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.1
            animation.fromValue = shapeLayer.presentation()?.path
            animation.toValue = layerConvertedPath
            shapeLayer.add(animation, forKey: "pathAnimation")
        }
    }
}
