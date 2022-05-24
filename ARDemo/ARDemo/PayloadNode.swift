// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2018
//
// - - - - - - - - - - - - - - - - - - - -

import Foundation
import SceneKit
import ARKit
import DMSDK

class PayloadNode: SCNNode {
    
    private(set) var payload: Payload
    var anchor: ARAnchor?
    var alignment  = ARPlaneAnchor.Alignment.horizontal
    
    private static var qrCount = 1
    private static var traditionalBarcodeCount = 1
    private static var digimarcBarcodeCount = 1
    
    init(payload: Payload, alignment: ARPlaneAnchor.Alignment = ARPlaneAnchor.Alignment.horizontal) {
        self.payload = payload
        super.init()
        self.alignment = alignment
        setup(alignment: alignment)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.payload = aDecoder.decodeObject(forKey: "payload") as! Payload
        self.alignment = aDecoder.decodeObject(forKey: "alignment") as! ARPlaneAnchor.Alignment
        super.init(coder: aDecoder)
        setup(alignment: self.alignment)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(self.payload, forKey: "payload")
        aCoder.encode(self.alignment, forKey: "alignment")
    }
    
    func setup(alignment: ARPlaneAnchor.Alignment) {
        //setup the geometry for this cube.
        let cubeGeometry = SCNBox(width: 0.02, height: 0.02, length: 0.02, chamferRadius: 0.001)
        
        //The material should be a texture based on the detection type
        let cubeMaterial = SCNMaterial()
        if payload.symbology.contains(.imageDigimarc) {
            cubeMaterial.diffuse.contents = UIImage(named: "icon_wm")
        } else if payload.symbology.contains(.qrCode) {
            cubeMaterial.diffuse.contents = UIImage(named: "icon_qr")
        } else {
            cubeMaterial.diffuse.contents = UIImage(named: "icon_barcode")
        }
        //add some sheen
        cubeMaterial.lightingModel = .physicallyBased
        cubeMaterial.metalness.intensity = 1.0
        cubeMaterial.roughness.intensity = 0.0
        cubeGeometry.firstMaterial = cubeMaterial
        
        //set the geometry of ourselves to the cube
        self.geometry = cubeGeometry
        self.castsShadow = true
        //set our vertical pivot point to the vertical center of the cube
        if self.alignment == .horizontal {
            self.pivot = SCNMatrix4MakeTranslation(0.0, Float(-cubeGeometry.height/2.0), 0.0)
        } else {
            self.pivot = SCNMatrix4MakeTranslation(0.0, 0.0, Float(cubeGeometry.length/2.0))
        }
        
        //add a text node to notate our cube
        //first setup the geometry
        let textGeometry = SCNText(string: "", extrusionDepth: 0.015)
        textGeometry.font = UIFont.systemFont(ofSize: 0.2)
        if payload.symbology.contains(.imageDigimarc) {
            textGeometry.string = String(format: "Digimarc Barcode #%i", PayloadNode.digimarcBarcodeCount)
            PayloadNode.digimarcBarcodeCount += 1
        } else if payload.symbology.contains(.qrCode) {
            textGeometry.string = String(format: "QR Code #%i", PayloadNode.qrCount)
            PayloadNode.qrCount += 1
        } else {
            textGeometry.string = String(format: "Barcode #%i", PayloadNode.traditionalBarcodeCount)
            PayloadNode.traditionalBarcodeCount += 1
        }
        //setup a black material
        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = UIColor.black
        textGeometry.firstMaterial = textMaterial
        
        //setup the node
        //we need to scale the node down as if the text size is too small
        //there are rendering issues. So use a larger text size and then scale down
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.04, 0.04, 0.04)
        textNode.castsShadow = true
        
        //set our pivot point to the center of the text
        let (min, max) = textNode.boundingBox
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        textNode.rotation = SCNVector4(1.0, 0.0, 0.0, -1.0)
        textNode.position = SCNVector3(0.0, 0.0, 0.02)
        
        self.addChildNode(textNode)
    }
}
