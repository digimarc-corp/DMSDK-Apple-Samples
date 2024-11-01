DMSDemo
=======

This iOS and iPadOS sample app showcases the core Digimarc Mobile SDK (DM SDK) APIs.

## Introduction

 DMSDemo integrates with an AVCaptureSession using ```DMSVideoCaptureReader``` to process camera frames and ```DMSAudioCaptureReader``` to sample audio, detecting Digimarc digital watermark for product packaging, print and audio media, the most common 1D barcodes, and QR codes. Once a detection is made, a ```Payload``` is provided to the host application using a delegate. 

This sample also instantiates a ```Resolver```, which can be used to query Digimarc's servers for more information about a payload. A ```Resolver``` returns a ```ResolverResult```, which contains one or more pieces of associated information as ```ResolvedContent```. 

Typically, developers will be interested in the ```contentURL``` associated with the ```ResolvedContent```. This example passes the URL to UIApplication's openURL function and opens the URL in the system browser or other relevant application.

If you're interested in what information can be queryed locally without using a ```Resolver```, see the ```Payload``` documentation. This can include GS1- and GTIN-related information.

## Prerequisites

You'll need a valid evaluation or commercial license key to use the core features of the app. Log in to your Digimarc Print & Audio module account to get your existing evaluation or commercial license key ([https://portal.digimarc.net/](https://portal.digimarc.net/)). If your evaluation license is expired, contact [sales@digimarc.com](mailto:sales@digimarc.com) to discuss obtaining a commercial license key.

## Getting started

1. Open DMSDemo.xcodeproj with Xcode 13 or higher.
2. Enter your license key in either the App Delegate or Info.plist as described below.
3. Run the app on a connected device. The iOS Simulator doesn't support video capture.

### App Delegate Method
If you're using `AppDelegate` to pass in your license key, add the following line of code before returning from `application(_ :didFinishLaunchingWithOptions:) -> Bool`.

```swift
LicenseManager.APIKey = "LICENSE_KEY_GOES_HERE"
```

### Info.plist Method

If you prefer the Info.plist method, enter a new key for `DMSAPIKey` and your license key as its `String` value.

## Illuminate

DMSDemo now works with the [Digimarc Illuminate Platform](https://www.digimarc.com/product-digitization). You'll need a Mobile SDK license key created in Illuminate and a Mobile API key. For instructions on generating these two keys, see [Introducing the Digimarc Mobile SDK](https://landing.digimarc.com).

You can retrieve Illuminate metadata for an image using the new [resolveV11 function](https://landing.digimarc.com/mobile-sdk/documentation/iOS/Classes/DMSResolver.html#/c:objc(cs)DMSResolver(im)resolveV11:options:).

```swift
let metadata = self.resolver?.resolveV11(payload, options: options)
```
For information about the metadata parameters you can request, see the 
[Illuminate Mobile REST API documentation](https://github.com/digimarc-corp/illuminate-mobile-rest-api). 
For the code to construct the options, see `setupVideoCaptureReader()` in 
[ScannerViewController.swift](https://github.com/digimarc-corp/DMSDK-Apple-Samples/blob/main/DMSDemo/Source/ScannerViewController.swift#L234).
