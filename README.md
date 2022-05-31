# DMSDK - iOS Sample Apps

## DMSDemo
The DMSDemo project showcases how to integrate core Digimarc Mobile SDK APIs. DMSDemo is an ideal starting point for applications that create and handle the AV Foundation pipeline, such as the camera device, preview layer, session, etc.

## DM Stock Take
The DM Stock Take application lets you scan barcodes from various distances. The values are then displayed with a colored background over the corresponding barcode. The app is configured to scan UPC-A, EAN-13, ITF-14, and Code 128 barcodes, which are commonly used in "stock-taking" scenarios.

The app performs additional processing to smooth out the visualization of the barcode values and locations on screen. Individual barcodes are tracked across read operations. This data is used to "fill in" results for barcodes that aren't read in one frame or another, which prevents a flickering effect.

On the main interface are toggles to adjust the read distance and visualization smoothing. They can be changed while the device is scanning.

- Note: Watch a [video demo of DM Stock Take][1]

## Drop-In View Controller 
The Drop-In View Controller project demonstrates how to use `DetectorViewController`, a drop-in subclass of `UIViewController` for mobile content detection of Digimarc digital watermarks, QR codes, and many traditional 1D barcodes.

## ARDemo
The ARDemo project demonstrates how to integrate DMSDK and ARKit. When a Digimarc watermark or a traditional barcode is detected, a 3D cube is displayed over the detection area.

Like the other sample applications, the AR Demo provides a starting-point for building applications that meet your specific use cases and requirements.

[1]:    https://vimeo.com/499261374