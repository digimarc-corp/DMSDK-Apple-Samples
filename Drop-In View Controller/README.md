Drop-In View Controller Demo
================

This iOS and iPadOS sample app demonstrates usage of DetectorViewController, a drop-in UIViewController for mobile content detection of Digimarc Barcode, QR codes, and many traditional 1D barcodes.

## Introduction

Drop-In View Controller Demo shows different ways to integrate DMSDK's prebuilt view controller into an existing application. A DetectorViewController can handle all setup of a camera and/or microphone and detection. An implementing application is responsible for creating a delegate to process results. The delegate will receive notifications when a ```Payload``` is detected, which represents content found by the camera or microphone.

DetectorViewController can also automatically query the Digimarc Barcode Manager, a cloud based service that can return additional information like related web content. This process is known as resolving a payload. The delegate callbacks offer control over which payloads to resolve.

When content is resolved, a ```ResolverResult ``` will be returned to the delegate. ```ResolverResult``` contains one of more pieces of associated information as a ```ResolvedContent``` type.

DMSDK can also be used in existing, custom developer created view controllers. For more information, see the ```VideoCaptureReader``` and ```AudioCaptureReader``` classes for integrating with a developer provided AVFoundation capture session. The ```Resolver``` class can also be used for manually querying the Digimarc Barcode Manager and retrieving resolver results.

DetectorViewController's appearance can be customized by adding or modifying different child views. It also is UIAppearance and dark and light mode complient.

## Prerequisites

You'll need a valid evaluation or commercial license key to use the core features of the app. Log in to your Digimarc Barcode Manager account to obtain your existing evaluation or commercial license key ([https://portal.digimarc.net/](https://portal.digimarc.net/)). If your evaluation license is expired, please contact [sales@digimarc.com](mailto:sales@digimarc.com) to discuss obtaining a commercial license key.

## Getting Started

1. Open "Drop-In View Controller.xcodeproj" with Xcode 13 or higher.
2. Enter your API Key in either the App Delegate or Info.plist as described below.
3. Run the app on a connected device. The iOS Simulator does not support video capture.

If you are using `AppDelegate` to pass in your API Key, add the following line of code before the `enableSDWSupport()` call.

```swift
LicenseManager.APIKey = "LICENSE_KEY_GOES_HERE"
```
If the Info.plist method is preferred, enter a new key for `DMSAPIKey` and your API Key as its `String` value.
