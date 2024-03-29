DMSDemo
=======

This iOS and iPadOS sample app showcases the core Digimarc Mobile SDK (DMSDK) APIs.

## Introduction

 DMSDemo integrates with an AVCaptureSession using ```DMSVideoCaptureReader``` to process camera frames and ```DMSAudioCaptureReader``` to sample audio, detecting Digimarc Barcode for Product Packaging, Print Media, and Audio, the most common 1D barcodes, and QR codes. Once a detection is made, a ```Payload``` is provided to the host application via a delegate. 

This sample also instantiates a ```Resolver```, which can be used to query Digimarc's servers for more information on a payload. A ```Resolver``` will return a ```ResolverResult```, which will contain one of more pieces of associated information as ```ResolvedContent```. 

Typically, developers will be interested in the ```contentURL``` associated with a ```ResolvedContent```. This example passes the URL to UIApplication's openURL function, and opens the URL in the system browser or other relevant application.

See the ```Payload``` documentation if you are interested in what information can be queryed locally without using a ```Resolver```. This can include GS1 and GTIN related information.

## Prerequisites

You'll need a valid evaluation or commercial license key to use the core features of the app. Log in to your Digimarc Barcode Manager account to obtain your existing evaluation or commercial license key ([https://portal.digimarc.net/](https://portal.digimarc.net/)). If your evaluation license is expired, please contact [sales@digimarc.com](mailto:sales@digimarc.com) to discuss obtaining a commercial license key.

## Getting started

1. Open DMSDemo.xcodeproj with Xcode 13 or higher.
2. Enter your API Key in either the App Delegate or Info.plist as described below.
3. Run the app on a connected device. The iOS Simulator does not support video capture.

If you are using `AppDelegate` to pass in your API Key, add the following line of code before returning from `application(_ :didFinishLaunchingWithOptions:) -> Bool`.

```swift
LicenseManager.APIKey = "LICENSE_KEY_GOES_HERE"
```
If the Info.plist method is preferred, enter a new key for `DMSAPIKey` and your API Key as its `String` value.