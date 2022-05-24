// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2020
//
// - - - - - - - - - - - - - - - - - - - -

import Foundation
import DMSDK
import Combine

class PayloadPublisher: NSObject, Publisher, VideoCaptureReaderResultsDelegate {
    typealias Failure = Never
    
    enum Output {
        case startedFrame
        case result(payload: Payload, metadata: PayloadMetadata)
        case endedFrame(lookedFor: Symbologies)
    }
    
    //Passthrough subject to pass the payloads through to the Combine stream
    private var subject = PassthroughSubject<Output, Never>()
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        //We're just a shell for the PassthroughSubject's publishing, pass our subscribers on to them
        subject.receive(subscriber: subscriber)
    }
    
    /// - Tag: PayloadPublisher
    func videoCaptureReader(_ videoCaptureReader: VideoCaptureReader, didOutputResult result: ReaderResult) {
        //Send the payloads one at a time downstream
        subject.send(.startedFrame)
        for payload in result.payloads {
            if  let payloadMetadata = result.metadata(for: payload) {
                subject.send(.result(payload: payload, metadata: payloadMetadata))
            }
        }
        subject.send(.endedFrame(lookedFor: result.executedSymbologies))
    }
}
