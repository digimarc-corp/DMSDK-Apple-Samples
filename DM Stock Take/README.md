# DMStockTake

DMStockTake allows you to scan barcodes from near and far distances. The values are then displayed with a colored background over the corresponding barcode. The app is configured to scan UPC-A, EAN-13, ITF-14, and Code 128 barcodes, which are commonly used in a "stock-taking" scenario.

The app performs additional processing to "smooth out" the visualization of the barcode values and locations on screen. Individual barcodes are tracked across read operations. This data is used to "fill in" results for barcodes that aren't read in one frame or another, which prevents a flickering effect.

Toggles to adjust the read distance and visualization smoothing are on the main interface and can be changed while the device is scanning.

- Note: Watch a [video demo of DM Stock Take][8]

## Prerequisites

You will need a valid evaluation or commercial license key to use the core features of the app. Log in to your [Digimarc Barcode Manager][3] account to obtain your existing evaluation or commercial license key. If your evaluation license is expired, please contact [sales@digimarc.com](mailto:sales@digimarc.com) to discuss obtaining a commercial license key.

This project assumes familiarity with Apple's [`Combine`][1] and [`AVFoundation`][2] frameworks. Additionally, `Combine` requires iOS 13 or later.

## Getting Started

1. Open "DM Stock Take.xcodeproj" with Xcode 13 or higher.
2. Enter your API Key in either the App Delegate or Info.plist as described below.
3. Run the app on a connected device. The iOS Simulator does not support video capture.

If you are using `AppDelegate` to pass in your API Key, add the following line of code before returning from `application(_ :didFinishLaunchingWithOptions:) -> Bool`.

```swift
LicenseManager.APIKey = "LICENSE_KEY_GOES_HERE"
```
If the Info.plist method is preferred, enter a new key for `DMSAPIKey` and your API Key as its `String` value.

## Configuring Read Distances in DMSDK

The `DMSReadDistance` options configure the read behavior for traditional barcodes as described below:

`DMSReadDistanceNear`:

- Best reading performance in the 3" to 12" range
- Up to 10 barcodes decoded per frame

`DMSReadDistanceFar`:

- Best reading performance in the 12" to 48" range 
- Up to 40 barcodes decoded per frame
- Uses 4K camera resolution

These options can also be used simultaneously.

```swift
self.readDistanceOption = [ReadDistance.far, ReadDistance.near]
```

- Note: Using both `DMSReadDistance ` options simultaneously increases battery and CPU usage.

`ViewController.swift` contains a private instance variable that holds the current `DMSReadDistance` selection and is set by the user. It has a `didSet` that will update the options in `DMSVideoCaptureReader`.

``` swift
private var readDistanceOption: ReadDistance = .far
```
Updating the option for `DMSReadDistance` can be done by calling the following function on `DMSVideoCaptureReader`:

``` swift
func setSymbologies(_ symbologies: Symbologies, options: [ReaderOptionKey : Any] = [:]) throws
```

[View in Source][4]

## Using Combine to Handle Results

`Combine` is used as the results handling pipeline in DMStockTake. At a minimum, there is a custom `Publisher` called `PayloadPublisher`. This conforms to the `DMSVideoCaptureReaderResultsDelegate` protocol from DMSDK to handle read results.

`PayloadPublisher` will publish 3 types of events:

- `startedFrame`
- `result(payload:metadata:)`
- `endedFrame(lookedFor:)`

The publisher downstream will handle these results as needed but the output `result(payload:metadata:)` is what will be used to display values and their location on screen. It provides the necessary payload value and location information.

[View in Source][5]

## Toggling Results Smoothing

Part of the results handling pipeline is using a `Combine` publisher that "tracks" all instances of `DMSPayload` passed down from the `PayloadPublisher`. Whenever the user enables the "results smoothing" toggle, another publisher is appended to the pipeline for additional processing to achieve these smooth label animations.

The `Tracking` publisher will publish the following events; determined by comparing the incoming batch of `DMSPayload` results to the previous batch of `DMSPayload` results:

- `appeared(id:payload:metadata:)`
- `moved(id:metadata:)`
- `disappeared(id:)`

The publisher sends each event with relevant identifiers as they're determined which allows the UI to react to changes immediately.

If "results smoothing" is disabled, this is the end of the processing pipeline.

[View in Source][6]

When "results smoothing" is enabled, the pipeline is reset and reconstructed using a `PayloadPublisher`, `Tracking` publisher, and a `Smoothing` publisher at the end.

``` swift
private func toggleSmoothing(isEnabled: Bool)
{
    // Resetting the publisher and output
    self.payloadOutput?.cancel()
    self.payloadPublisher = PayloadPublisher()
    self.videoCaptureReader?.setResultsDelegate(self.payloadPublisher, queue: DispatchQueue.main)
    
    // Resetting the layers in the view
    self.removeAllLayers()
    
    // Determine which publisher we need, smoothing or not.
    if  isEnabled {
        self.payloadOutput = self.payloadPublisher.tracked().smoothed().sink { (output) in
            self.updateOverlays(with: output)
        }
    } else {
        self.payloadOutput = self.payloadPublisher.tracked().sink { (output) in
            self.updateOverlays(with: output)
        }
    }
}
```
## Smoothing Results

The `Smoothing` publisher's input and output are the exact type as the `Tracking` publisher's output:

- `appeared(id:payload:metadata:)`
- `moved(id:metadata:)`
- `disappeared(id:)`

This publisher works by tracking `Payload` objects currently in view and those marked as deleted/disappeared by the `Tracking` publisher.

It tracks the current payloads in view:

```swift
var upstreamPayloads: [(id: UUID, payload: Payload, payloadMetadata: PayloadMetadata)] = []
```
As it is processing incoming appeared or moved events, it compares them to those in `upstreamPayloads` to check for overlaps. An overlap indicates that the `Payload` is not new and publishes a moved event downstream. No overlap indicates that the `Payload` is new and publishes an appeared event.

However, sometimes with slight movement of the device, a barcode isn't detected for a given frame. This triggers a disappeared event in our current pipeline and can produce a flickering/jittering effect. `Payload` objects are tracked in:

```swift
var pendingDeletionTimers: [UUID : Timer] = [:]
```

To "smooth" over this effect, whenever the `Tracking` publisher publishes a disappeared event, the `Smoothing` publisher will hang onto the `Payload`'s `UUID` but assigns a countdown timer on it.

The countdown timer gives that particular payload in its location some time to remain on screen in case it's detected in the subsequent frames. This reduces the flickering/jittering effect described above.

[View in Source][7]

However, if the particular payload does not reappear in subsequent frames, the `Smoothing` publisher will send a disappeared event once its timer expires.

## Region of Interest

DMStockTake app also illustrates how to use `rectOfInterest` on instances of `DMSVideoCaptureReader`. The UI allows the user to choose from a few examples, which are normalized `CGRect` values in UI coordinate space.

However, `rectOfInterest` on `DMSVideoCaptureReader` requires the `CGRect` value be in normalized camera-device space coordinates.

This conversion is done using 
`func metadataOutputRectConverted(fromLayerRect rectInLayerCoordinates: CGRect) -> CGRect`
on 'AVCaptureVideoPreviewLayer'. Review the helper function
`func convertToNormalizedCameraCoordinates(normalizedUIRect: CGRect) -> CGRect`
to see how this function is used.

[View in Source][9]


[1]:    https://developer.apple.com/documentation/combine
[2]:    https://developer.apple.com/documentation/avfoundation
[3]:    https://portal.digimarc.net
[4]:    x-source-tag://UpdatingReadDistanceReaderOption
[5]:    x-source-tag://PayloadPublisher
[6]:    x-source-tag://TrackingPublisherProcessing
[7]:    x-source-tag://SmoothingPublisherProcessing
[8]:    https://vimeo.com/499261374
[9]:    x-source-tag://ConvertingToCameraSpaceCoordinates