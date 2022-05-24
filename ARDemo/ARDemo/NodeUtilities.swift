// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2018
//
// - - - - - - - - - - - - - - - - - - - -

import Foundation
import SceneKit
import ARKit

extension SCNNode {
    func orientToFace(camera: ARCamera) {
        let rotate = simd_float4x4(SCNMatrix4MakeRotation(camera.eulerAngles.y, 0, 1, 0))
        let rotateTransform = simd_mul(simd_float4x4(self.transform), rotate)
        self.transform = SCNMatrix4(rotateTransform)
    }
}
