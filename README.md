# DMSDK - iOS Sample Apps

## DMSDemo
The DMSDemo project showcases how to integrate core Digimarc Mobile SDK APIs. `DMSDemo` is an ideal starting point for applications where the application creates and handles the AV Foundation pipeline such as the camera device, preview layer, and session etc.

## DM Stock Take
The DM Stock Take allows you to scan barcodes from near and far distances. The values are then displayed with a colored background over the corresponding barcode. The app is configured to scan UPC-A, EAN-13, ITF-14, and Code 128 barcodes, which are commonly used in a "stock-taking" scenario.

The app performs additional processing to "smooth out" the visualization of the barcode values and locations on screen. Individual barcodes are tracked across read operations. This data is used to "fill in" results for barcodes that aren't read in one frame or another, which prevents a flickering effect.

Toggles to adjust the read distance and visualization smoothing are on the main interface and can be changed while the device is scanning.

- Note: Watch a [video demo of DM Stock Take][1]

## Drop-In View Controller 
The Drop-In View Controller project demonstrates how to use `DetectorViewController`, a drop-in subclass of `UIViewController` for mobile content detection of Digimarc Barcode, QR codes, and many traditional 1D barcodes.

## ARDemo
The ARDemo project showcases how to integrate DMSDK and ARKit. The result is an application that once a Digimarc or Traditional Barcode is detected, a 3D cube is around where the detection took place.

AR Demo is only a starting-point example and your specific use-case may very.

[1]:    https://vimeo.com/499261374