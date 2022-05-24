//
//  RegionOverlayLayer.swift
//  DMSDK
//
//  Created by Guzman, Mario on 4/11/22.
//  Copyright © 2022 Digimarc. All rights reserved.
//

import UIKit

@objc(DMSRegionOverlayLayer)
open class RegionOverlayLayer: CALayer {
    
    private lazy var maskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.black.cgColor
        layer.fillRule = .evenOdd
        return layer
    }()
    
    @objc dynamic public var locationRect: CGRect = .zero {
        didSet {
            self.adjustMask()
        }
    }
    
    required public init?(coder: NSCoder)
    {
        super.init(coder: coder)
        self.setup()
    }
    
    override public init()
    {
        super.init()
        self.setup()
    }
    
    override init(layer: Any)
    {
        super.init(layer: layer)
        self.setup()
    }
    
    open override func layoutSublayers()
    {
        self.maskLayer.frame = self.bounds
        self.adjustMask()
    }
    
    /// Initial, one-time setup for this layer. Sets up any sublayers with their initial state and position.
    private func setup()
    {
        self.backgroundColor = UIColor.black.withAlphaComponent(0.75).cgColor
        self.mask = self.maskLayer
    }
    
    /// Adjusts the "cutout" to display the region
    private func adjustMask()
    {
        let bounds = self.bounds
        self.maskLayer.frame = bounds
        
        // Dev note: To achieve a 'cutout', begin with making a path of the
        // bounds that will be darkened, the frame. The 'cutout' shape will
        // be an additive path. Begin by making the shape using a bezier path
        // and Add it to the original frame.
        // Because the fillRule property on the mask layer is .evenOdd, it will
        // result in a 'cutout' effect rather than the shape floating over the
        // view.
        
        let path = UIBezierPath(rect: bounds)
        let cutoutPath = UIBezierPath(roundedRect: self.locationRect, cornerRadius: 16)
        path.append(cutoutPath)
        
        self.maskLayer.path = path.cgPath
    }
}
