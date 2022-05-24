// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2020
//
// - - - - - - - - - - - - - - - - - - - -

import Foundation
import DMSDK
import Combine

/// This class takes upstream Tracking output, and produces Tracking output. We define the valid upstream publisher loosely to allow compatbility with other publishers that produce compatible output.
class Smoothing<UpstreamType: Publisher>: Publisher where UpstreamType.Output == TrackingChange, UpstreamType.Failure == Never
{
    // We never have a failure event
    typealias Failure = Never
    typealias Output = TrackingChange
    
    let upstream: UpstreamType
    // Sink to capture and publish upstream data
    private var sink: AnyCancellable!
    // The subject we'll use to publish our output
    private var subject = PassthroughSubject<Output, Never>()
    
    /// The delay for payloads pending deletion to remain in view before disappearing.
    var deletionDelay: TimeInterval
    
    /// Dictionary for payloads marked for deletion.
    var pendingDeletionTimers: [UUID : Timer] = [:]
    
    /// Mapping of upstream UUIDs to downstream UUIDs we're outputting. The upstream id might change if the payload is dropped for a frame, so we need to smooth over that and remap the inconsistant upstream ids to a consistant downstream one
    var idTranslations: [UUID: UUID] = [:]
    
    // The payloads currently being tracking
    var upstreamPayloads: [(id: UUID, payload: Payload, payloadMetadata: PayloadMetadata)] = []
    
    init(upstream: UpstreamType, deletionDelay: TimeInterval = 0.5) {
        self.deletionDelay = deletionDelay
        self.upstream = upstream
        self.sink = upstream.sink(receiveValue: { (trackingChange: TrackingChange) in
            self.processInput(input: trackingChange)
        })
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        // We're just a shell, when we get a new subscriber send their subscription on to our subject
        subject.receive(subscriber: subscriber)
    }
    
    private func register(payload: Payload, metadata: PayloadMetadata, upstreamID: UUID, _ callback: ((UUID, Bool) -> Void)) {
        //First we need to decide if this is actually a new payload, or an intermitant result we need to smooth over
        //Check to see if we have an old entry matching this payload value and rough position that is pending deletion
        if  let oldUUID = upstreamPayloads.firstOverlapping(with: payload, payloadMetadata: metadata),
            let _ = self.pendingDeletionTimers[oldUUID] {
            //We did find an old entry pending deletion that looks to be a match for this "new" result, do some smoothing.
            
            // We need to report back a consistant id for smoothing, go to our lookup table, and reassign the id we allocated
            // for this old entry to the new one
            let smoothedUUID = idTranslations[oldUUID]
            idTranslations[oldUUID] = nil
            
            // Unregister the old payload id
            self.unregister(upstreamID: oldUUID)
            
            //link the new payload entry to the existing downstream id
            idTranslations[upstreamID] = smoothedUUID
            
            callback(smoothedUUID!, false)
        } else {
            //this really does look like a new payload, create a new id for it
            let newUUID = UUID()
            idTranslations[upstreamID] = newUUID
            callback(newUUID, true)
        }
        upstreamPayloads.append((id: upstreamID, payload: payload, payloadMetadata: metadata))
    }
    
    private func unregister(upstreamID: UUID) {
        self.pendingDeletionTimers[upstreamID]?.invalidate()
        self.pendingDeletionTimers[upstreamID] = nil
        self.upstreamPayloads.remove(at: self.upstreamPayloads.firstIndex(where: { (element) -> Bool in
            element.id == upstreamID
        })!)
    }
    
    /// - Tag: SmoothingPublisherProcessing
    private func processInput(input: TrackingChange)
    {
        switch input {
        case .appeared(id: let uuid, payload: let payload, metadata: let metadata):
            
            self.register(payload: payload, metadata: metadata, upstreamID: uuid) { (identifier, isNew) in
                if isNew {
                    // Signal that the Payload was introduced.
                    self.subject.send(
                        .appeared(id: identifier, payload: payload, metadata: metadata)
                    )
                } else {
                    // Payload may be on screen. Signal that it should be moved.
                    self.subject.send(
                        .moved(id: idTranslations[uuid]!, metadata: metadata)
                    )
                }
            }
            
        case .disappeared(id: let uuid):
            // Payload was signaled that it isn't in view.
            // Mark as pending deletion by adding it to the pending deletion
            // dictionary along with the payload object as context.
            let newTimer = Timer.scheduledTimer(timeInterval: self.deletionDelay, target: self, selector: #selector(signalDeletion(timer:)), userInfo: ["id": uuid], repeats: false)
            self.pendingDeletionTimers[uuid] = newTimer
            
            
        case .moved(id: let uuid, metadata: let metadata):
            // Signal that the payload is still in view but has moved position.
            self.subject.send(
                .moved(id: idTranslations[uuid]!, metadata: metadata)
            )
        }
    }
    
    /// Triggered when the timer for a payload pending deletion fires. Uses the timer's userInfo to extract
    /// the payload and publishes an update.
    @objc func signalDeletion(timer: Timer) {
        if  let context = timer.userInfo as? [String : UUID],
            let uuid = context["id"] {
            self.unregister(upstreamID: uuid)
            self.subject.send(
                .disappeared(id: idTranslations[uuid]!)
            )
            idTranslations[uuid] = nil
        }
    }
}

extension Publisher where Output == TrackingChange, Failure == Never {
    func smoothed() -> Smoothing<Self> {
        return Smoothing(upstream: self)
    }
}
