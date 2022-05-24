// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2018
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate
{
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var messageView: MessageView!
    
    var imageReader: ImageReader?
    let imageSymbologies: Symbologies = [ .imageDigimarc, .UPCA, .UPCE, .EAN13, .EAN8, .dataBar, .qrCode, .code39, .code128, .ITF, .ITFGTIN14 ]
    
    var visibleNodePositions: [String : SCNVector3] = [:]
    var orientation = UIInterfaceOrientation.portrait
    var nodesForPayloads: [Payload : PayloadNode] = [:]
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.setupMessageView()
        
        // Setup DMSDK's ImageReader class.
        
        // TODO: Handle the catch.
        self.imageReader = try? ImageReader(symbologies: imageSymbologies, detectionType: .default, allowFrameSkipping: false)
        
        // Setup Delegate for SceneKit
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        
        self.restartConfiguration(runOptions: [])
        
        // Show statistics such as fps and timing information
        // sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.orientation = UIApplication.shared.statusBarOrientation
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil, completion: { _ in
            self.orientation = UIApplication.shared.statusBarOrientation
        })
    }
    
    //MARK: - ARSession Delegate (DMSDK used here)
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable, .limited:
            DispatchQueue.main.async {
                self.messageView.header.text = camera.trackingState.presentationString
                self.messageView.subheader.text = camera.trackingState.recommendationString 
                self.messageView.isHidden = false
            }
        case .normal:
            DispatchQueue.main.async {
                self.messageView.isHidden = true
                self.messageView.header.text = nil
                self.messageView.subheader.text = nil
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame)
    {
        // If we have a sample buffer, unwrap the imageReader and safely check
        // for payloads in the sample buffer and process them.
        if  let imageReaderResult = ((try? imageReader?.process(pixelBuffer: frame.capturedImage)) as ReaderResult??),
            let result = imageReaderResult {
            
            for payload in result.payloads {
                
                // Get the detection region of the payload to perform a hit test
                // to possibly anchor AR conent.
                var transform = frame.displayTransform(for: self.orientation, viewportSize: sceneView.bounds.size)
                
                guard let path = result.metadata(for: payload)?.path?.copy(using: &transform) else { continue }
                
                let midX = path.boundingBox.midX
                let midY = path.boundingBox.midY
                var center = CGPoint(x: midX, y: midY)
                self.modify(point: &center)
                
                // Perform a hit test in the area of the to see where we can
                // position the anchor.
                guard let hitTest = sceneView.hitTest(center, types: [.existingPlaneUsingExtent]).first else { continue }
                let position = SCNVector3(x: hitTest.worldTransform.columns.3.x, y: hitTest.worldTransform.columns.3.y, z: hitTest.worldTransform.columns.3.z)
                
                // Checks the index of the payload's identifier in the dictionary.
                // If there is no index, the position is added to the dictionary
                // with it's identifier as the key.
                if let index = visibleNodePositions.index(forKey: payload.id) {
                    
                    // Remove an anchor if its within a certain minimum distance and
                    // re-add it as a new anchor with its new position. We'll re-add
                    // them after this.
                    if visibleNodePositions[index].value.distance(toVector: position) > 0.5, let payloadNode = self.nodesForPayloads[payload] {
                        if let anchor = payloadNode.anchor {
                            session.remove(anchor: anchor)
                        }
                        payloadNode.removeFromParentNode()
                    }
                }
                
                if self.nodesForPayloads[payload] == nil {
                    if let planeAnchor = hitTest.anchor as? ARPlaneAnchor {
                        let payloadNode = PayloadNode(payload: payload, alignment: planeAnchor.alignment)
                        sceneView.scene.rootNode.addChildNode(payloadNode)
                        let anchor = ARAnchor(transform: hitTest.worldTransform)
                        payloadNode.simdPosition = anchor.transform.translation
                        if planeAnchor.alignment == .horizontal {
                            payloadNode.orientToFace(camera: frame.camera)
                        }
                        nodesForPayloads[payload] = payloadNode
                        payloadNode.transform = SCNMatrix4(anchor.transform)
                        payloadNode.anchor = anchor
                        session.add(anchor: anchor)
                        visibleNodePositions.updateValue(position, forKey: payload.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func restartConfiguration(runOptions: ARSession.RunOptions)
    {
        let configuration = ARWorldTrackingConfiguration()
        if #available(iOS 12.0, *) {
            configuration.environmentTexturing = .automatic
        }
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: runOptions)
    }
    
    @IBAction func resetAction(_ sender: Any)
    {
        self.restartConfiguration(runOptions: [.resetTracking, .removeExistingAnchors])
        for node in nodesForPayloads {
            node.value.removeFromParentNode()
        }
        self.nodesForPayloads = [:]
        self.visibleNodePositions = [:]
    }
    
    func modify(point: inout CGPoint)
    {
        point.y *= CGFloat(self.sceneView.bounds.height)
        point.x *= CGFloat(self.sceneView.bounds.width)
    }
    
    private func setupMessageView()
    {
        guard  let unwrappedMessageView = self.messageView else { return }
        
        unwrappedMessageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(unwrappedMessageView)
        NSLayoutConstraint(item: unwrappedMessageView,
                           attribute: .bottom,
                           relatedBy: .equal,
                           toItem: self.view,
                           attribute: .bottomMargin,
                           multiplier: 1,
                           constant: 0).isActive = true
        NSLayoutConstraint(item: unwrappedMessageView,
                           attribute: .leading,
                           relatedBy: .equal,
                           toItem: self.view,
                           attribute: .leading,
                           multiplier: 1,
                           constant: 0).isActive = true
        NSLayoutConstraint(item: unwrappedMessageView,
                           attribute: .trailing,
                           relatedBy: .equal,
                           toItem: self.view,
                           attribute: .trailing,
                           multiplier: 1,
                           constant: 0).isActive = true
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)
    {
        if let planeAnchor = anchor as? ARPlaneAnchor {
            // Create a SceneKit plane to visualize the node using its position and extent.
            let planeNode = PlaneNode(anchor: planeAnchor, in: sceneView)
            node.addChildNode(planeNode)
        } else if let payloadNode = self.nodesForPayloads.first(where: { (pair) -> Bool in
            return pair.value.anchor == anchor
        })?.value {
            payloadNode.simdPosition = anchor.transform.translation
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if  let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? PlaneNode {
            
            if  let planeGeometry = plane.fillNode.geometry as? ARSCNPlaneGeometry {
                planeGeometry.update(from: planeAnchor.geometry)
            }
        } else if let payloadNode = self.nodesForPayloads.first(where: { (pair) -> Bool in
            return pair.value.anchor == anchor
        })?.value {
            payloadNode.simdPosition = anchor.transform.translation
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor)
    {
        if let anchorNode = sceneView.node(for: anchor) {
            anchorNode.runAction(.fadeOut(duration: 0.3))
            anchorNode.removeFromParentNode()
        }
    }
}

// MARK: - Extension SCNVector3

extension SCNVector3
{
    func distance(toVector: SCNVector3) -> Float
    {
        let distance = SCNVector3(toVector.x - self.x, toVector.y - self.y, toVector.z - self.z)
        return sqrtf(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z)
    }
}

// MARK: - Extension ARCamera.TrackingState

extension ARCamera.TrackingState {
    var presentationString: String {
        switch self {
        case .notAvailable:
            return "Tracking unavailable"
        case .normal:
            return "Tracking normal"
        case .limited(.excessiveMotion):
            return "Tracking limited – Excessive motion"
        case .limited(.insufficientFeatures):
            return "Tracking limited – Low detail"
        case .limited(.initializing):
            return "Initializing"
        case .limited(.relocalizing):
            return "Recovering from interruption"
        case .limited(_):
            return "Tracking Limited - Unsupported Reason"
        }
    }
    
    var recommendationString: String? {
        switch self {
        case .limited(.excessiveMotion):
            return "Try slowing down your movement"
        case .limited(.insufficientFeatures):
            return "Try pointing at a flat surface"
        case .limited(.relocalizing):
            return "Return to the location where you left off"
        default:
            return nil
        }
    }
}

extension float4x4 {
    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
     */
    var translation: SIMD3<Float> {
        get {
            let translation = columns.3
            return SIMD3(translation.x, translation.y, translation.z)
        }
        set(newValue) {
            columns.3 = SIMD4(newValue.x, newValue.y, newValue.z, columns.3.w)
        }
    }
}
