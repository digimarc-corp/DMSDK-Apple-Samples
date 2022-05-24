// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2020
//
// - - - - - - - - - - - - - - - - - - - -

import Foundation
import DMSDK
import Combine

/// Tracking cases for payloads
enum TrackingChange {
    case appeared(id: UUID, payload:Payload, metadata: PayloadMetadata)
    case moved(id: UUID, metadata: PayloadMetadata)
    case disappeared(id: UUID)
}

extension Array where Element == CGVector {
    
    fileprivate func shortest() -> CGVector? {
        return self.min { (left, right) -> Bool in
            left.length < right.length
        }
    }
    
    fileprivate func longest() -> CGVector? {
        return self.max { (left, right) -> Bool in
            left.length < right.length
        }
    }
    
}

extension CGVector {
    
    fileprivate var length: CGFloat {
        get {
            return sqrt((self.dx * self.dx) + (self.dy * self.dy))
        }
    }
    
    fileprivate var angle: CGFloat {
        get {
            return atan2(self.dy, self.dx)
        }
    }
    
}

extension CGPath {
    
    fileprivate func asVectors() -> [CGVector] {
        var vectors: [CGVector] = []
        var lastPoint: CGPoint!
        self.applyWithBlock { (element) in
            if element.pointee.type == .moveToPoint {
                lastPoint = element.pointee.points[0]
            } else if element.pointee.type == .addLineToPoint {
                let newPoint = element.pointee.points[0]
                vectors.append(CGVector(dx: newPoint.x - lastPoint.x, dy: newPoint.y - lastPoint.y))
                lastPoint = newPoint
            }
        }
        return vectors
    }
    
    fileprivate func adjustedBarcodePath() -> CGPath? {
        let vectors = self.asVectors()
        //assume longest is width and shortest is height
        guard let longest = vectors.longest(), let shortest = vectors.shortest() else {
            //path is incomplete, we shouldn't be here, but handle the possible error
            return nil
        }
        
        let ratio = shortest.length / longest.length
        //the angle of the shortest should be the angle of the code
        let angle = longest.angle
        let pathCenterX = self.boundingBox.midX
        let pathCenterY = self.boundingBox.midY
        
        var scaleFactor: CGFloat = 2.5
        if ratio < 0.20 {
            scaleFactor = 6.0
        } else if ratio < 0.25 {
            scaleFactor = 2.8
        } else if ratio < 0.4 {
            scaleFactor = 1.3
        }
        
        //we need to expand the path, using the center of the path as the center point, on the angle we computed
        //translate the code's path to the origin, and rotate it about the origin to face as close to a perspective corrected flat view as possible
        let translateAndRotate = CGAffineTransform(translationX: -pathCenterX, y: -pathCenterY).concatenating(CGAffineTransform(rotationAngle: -angle))
        //once we have the path in that co-ordinate space, increase the height
        let scale = CGAffineTransform(scaleX: 1.0, y: scaleFactor)
        
        //concatinate the operations, along with an inverse of the translate and rotate to project it back to the original location
        var transform = translateAndRotate.concatenating(scale).concatenating(translateAndRotate.inverted())
        
        let newPath = self.copy(using: &transform)
        
        return newPath
    }
    
}

extension Array where Element == (id: UUID, payload: Payload, payloadMetadata: PayloadMetadata) {
    
    func firstOverlapping(with payload: Payload, payloadMetadata: PayloadMetadata) -> UUID? {
        //Go through all our records
        for (id, arrayPayload, arrayMetadata) in self {
            //does the payload match
            if arrayPayload == payload {
                if  arrayMetadata.path!.adjustedBarcodePath()!.contains(payloadMetadata.path!.boundingBox.centerPoint) ||
                        payloadMetadata.path!.adjustedBarcodePath()!.contains(arrayMetadata.path!.boundingBox.centerPoint) {
                    return id
                }
            }
        }
        return nil
    }
    
}

fileprivate extension Array where Element == (payload: Payload, metadata: PayloadMetadata) {
    
    func hasOverlapping(payload: Payload, payloadMetadata: PayloadMetadata) -> Bool {
        //Go through all our records
        for (arrayPayload, metadata) in self {
            //does the payload match
            if arrayPayload == payload {
                // Is the center point of either in the other?
                if  metadata.path!.adjustedBarcodePath()!.contains(payloadMetadata.path!.boundingBox.centerPoint) ||
                        payloadMetadata.path!.adjustedBarcodePath()!.contains(metadata.path!.boundingBox.centerPoint) {
                    return true
                }
            }
        }
        return false
    }
    
}

/// This class takes upstream PayloadPublisher output, and produces Tracking output. We define the valid upstream publisher loosely to allow compatbility with other publishers that produce compatible output.
class Tracking<UpstreamType: Publisher>: Publisher where UpstreamType.Output == PayloadPublisher.Output, UpstreamType.Failure == Never {
    
    // We never have a failure event
    typealias Failure = Never
    typealias Output = TrackingChange
    
    let upstream: UpstreamType
    // Sink to capture and publish upstream data
    private var sink: AnyCancellable!
    // The subject we'll use to publish our output
    private var subject = PassthroughSubject<Output, Never>()
    
    // We want to keep the previous record of payloads, and the next record of payloads.
    // This gets tricky because next payloads may only be from some of the detectors depending on scheduling,
    // so it might only be a partial set.
    private var previousPayloads: Array<(id: UUID, payload: Payload, payloadMetadata: PayloadMetadata)> = []
    private var unprocessedPayloads: [(payload: Payload, metadata: PayloadMetadata)] = []
    
    init(upstream: UpstreamType) {
        self.upstream = upstream
        // Subscribe immediately to our upstream output
        self.sink = upstream.sink(receiveValue: { (output) in
            self.processInput(input: output)
        })
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        // We're just a shell, when we get a new subscriber send their subscription on to our subject
        subject.receive(subscriber: subscriber)
    }
    
    /// - Tag: TrackingPublisherProcessing
    private func processInput(input: PayloadPublisher.Output) {
        
        switch input {
        case .startedFrame:
            // When the frame starts, prime by clearing the unprocessed payloads array
            unprocessedPayloads = []
        case .result(payload: let payload, metadata: let metadata):
            // When we get a result, add it to our unprocessed payloads
            unprocessedPayloads.append((payload, metadata))
        case .endedFrame(lookedFor: let lookedFor):
            // Frame ended, time to process
            
            // First start by narrowing our view of the previous payloads to what we actually looked for
            // don't mess with our watermark records if we only looked for 1D barcode this frame
            let previousRelevantPayloads = self.previousPayloads.filter { (_, payload, _) -> Bool in
                lookedFor.contains(payload.symbology)
            }
            
            // Calculate which payloads are not new, send updated metadata events, and notate
            let lostRecords = previousRelevantPayloads.filter { (_, payload, payloadMetadata) -> Bool in
                !unprocessedPayloads.hasOverlapping(payload: payload, payloadMetadata: payloadMetadata)
            }
            for lostRecord in lostRecords {
                self.subject.send(
                    .disappeared(id: lostRecord.id)
                )
                self.previousPayloads.remove(at: self.previousPayloads.firstIndex(where: { (element) -> Bool in
                    element.id == lostRecord.id
                })!)
            }
            
            // Calculate which payloads are not new, send updated metadata events, and notate
            let movedRecords = unprocessedPayloads.compactMap { (payload, metadata) -> (id: UUID, payload: Payload, metadata: PayloadMetadata)? in
                if let id = previousRelevantPayloads.firstOverlapping(with: payload, payloadMetadata: metadata) {
                    return (id, payload, metadata)
                }
                return nil
            }
            for movedRecord in movedRecords {
                self.subject.send(
                    .moved(id: movedRecord.id, metadata: movedRecord.metadata)
                )
            }
            
            // Calculate which payloads are new, send events, and notate
            let newPayloads = unprocessedPayloads.compactMap { (payload, metadata) -> (id: UUID, payload: Payload, metadata: PayloadMetadata)? in
                if previousRelevantPayloads.firstOverlapping(with: payload, payloadMetadata: metadata) == nil {
                    return (UUID(), payload, metadata)
                }
                return nil
            }
            for newPayload in newPayloads {
                self.subject.send(
                    .appeared(id: newPayload.id, payload: newPayload.payload, metadata: newPayload.metadata)
                )
                self.previousPayloads.append((id: newPayload.id, payload: newPayload.payload, payloadMetadata: newPayload.metadata))
            }
        }
    }
}

// Function for upstream publishers for creating a filter chain.
extension Publisher where Output == PayloadPublisher.Output, Failure == Never {
    func tracked() -> Tracking<Self> {
        return Tracking(upstream: self)
    }
}

extension CGRect {
    var centerPoint: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}
