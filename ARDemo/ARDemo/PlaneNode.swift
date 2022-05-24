//
//  PlaneNode.swift
//  ARDemo
//
//  Created by Guzman, Mario on 11/21/18.
//  Copyright © 2018 Digimarc. All rights reserved.
//

import ARKit

class PlaneNode: SCNNode
{
    let fillNode: SCNNode
    
    private let materialColor = UIColor.init(red: 90.0/255.0, green: 200.0/255.0, blue: 250.0/255.0, alpha: 1.0)
    
    init(anchor: ARPlaneAnchor, in sceneView: ARSCNView)
    {
        // Filling to visualize the plane itself
        guard let fillGeometry = ARSCNPlaneGeometry(device: sceneView.device!) else {
            fatalError("There is no device associated with `sceneView`.")
        }
        fillGeometry.update(from: anchor.geometry)
        self.fillNode = SCNNode(geometry: fillGeometry)
        
        super.init()
        
        // Node Fill Styling
        if let material = self.fillNode.geometry?.firstMaterial {
            self.fillNode.opacity = 0.10
            material.diffuse.contents = self.materialColor
        }
        
        self.addChildNode(fillNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
