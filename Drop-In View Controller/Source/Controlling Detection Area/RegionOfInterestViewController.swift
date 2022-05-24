//
//  RegionOfInterestViewController.swift
//  DigimarcVC
//
//  Created by Cornaby, Colin on 6/16/21.
//  Copyright © 2021 Digimarc. All rights reserved.
//

import UIKit
import DMSDK

/*
 This class demonstrates how to set a detection area in a DetectorViewController.
 
 By default, a DetectorViewController will look for barcodes across the entire camera.
 DetectorViewController provides a rectOfInterest property that allows a specific
 detection region to be set. There are a few things to remember when using this property:
 
 - rectOfInterest is set using a normalized co-ordinate space, like other common camera
 functions on Apple platforms. This means the rect is defined using percentages of the camera
 frame as its unit type.
 - The frame the camera receives may not be the same size as the screen. The preview may clip
 the camera's view. So the rect of interest should be provided as a subrect of the camera frame,
 not a subrect of the view.
 
 Apple provides functions on AVCaptureVideoPreviewLayer that can convert view rects into
 normalized camera rects. This sample demonstrates how to use Apple's conversion functions
 to take view co-ordinates, and set a focus region based on the screen region.
 
 The xib accompanying this class contains an auto layout managed view that should constrain
 detections. This view is referenced via the regionOfInterestView outlet.
 
 The rect of interest is set within the viewDidLayoutSubviews function. Its important
 that the rect of interest be updated each time this function is called so that the rect
 of interest will update as the layout changes in response to rotation or window resize.
 
 DMSDK will detect portions of a barcode. rectOfInterest does not require that the
 entire barcode be within the detection region, only a usable portion of it.
 */

class RegionOfInterestViewController: DetectorViewController {

    private var rectOfInterestButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //this sample draws it's own targeting view,
        //disable the built in one
        self.automaticallyUpdatesRectOfInterest = false
        
        // Buttons with Menu Items
        let roiButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.stack.3d.up.fill"), primaryAction: nil, menu: self.createROIMenu())
        self.rectOfInterestButton = roiButtonItem
        self.navigationItem.rightBarButtonItems = [roiButtonItem]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        //  Now that our bounds have changed, update `rectOfInterest` based off
        //  the selected `rectOfInterest`.
        if  self.overlayType == .crosshairs || self.overlayType == .detectRegion {
            self.setROI(newROI: self.selectedRectOfInterest)
        }
    }
    
    // MARK: - Region (Rect) of Interest
    
    // Used as a reference to the last selected rect of interest. When the device
    // device rotates, we have to re-calculate our overlay based on this again.
    private var selectedRectOfInterest: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) {
        didSet {
            DispatchQueue.main.async {
                if  self.isViewLoaded {
                    self.view.setNeedsLayout()
                }
            }
        }
    }
    
    struct ROISample {
        var id: Int
        var title: String
        var identifier: UIAction.Identifier
        var roiRect: CGRect
    }
    
    struct OverlayMenu {
        var id: Int
        var title: String
        var identifier: UIAction.Identifier
        var overlayType: DetectorViewController.OverlayType
    }
    
    private var sampleRegions = [
        ROISample(id: 0, title: "No Region of Interest", identifier: UIAction.Identifier(rawValue: "ROI_None"), roiRect: CGRect(x: 0, y: 0, width: 1, height: 1)),
        ROISample(id: 1, title: "Region Option 1", identifier: UIAction.Identifier(rawValue: "ROI_Option1"), roiRect: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.25)),
        ROISample(id: 2, title: "Region Option 2", identifier: UIAction.Identifier(rawValue: "ROI_Option2"), roiRect: CGRect(x: 0.2, y: 0.5, width: 0.6, height: 0.4))
    ]
    
    private var overlayMenus = [
        OverlayMenu(id: 0, title: "No Overlay", identifier: UIAction.Identifier(rawValue: "Overlay_None"), overlayType: .none),
        OverlayMenu(id: 1, title: "Crosshairs", identifier: UIAction.Identifier(rawValue: "Overlay_Crosshairs"), overlayType: .crosshairs),
        OverlayMenu(id: 2, title: "Region", identifier: UIAction.Identifier(rawValue: "Overlay_Region"), overlayType: .detectRegion)
    ]
    
    private func createROIMenu() -> UIMenu
    {
        let regionActions = self.sampleRegions.map { roiSample in
            return UIAction(title: roiSample.title,
                            identifier: roiSample.identifier,
                            state: roiSample.roiRect == self.selectedRectOfInterest ? .on : .off) { action in
                self.setROI(newROI: roiSample.roiRect)
                self.resetROIMenuStates()
            }
        }
        let overlayActions = self.overlayMenus.map { overlayMenu in
            return UIAction(title: overlayMenu.title,
                            identifier: overlayMenu.identifier,
                            state: overlayMenu.overlayType == overlayType ? .on : .off) { action in
                self.overlayType = overlayMenu.overlayType
                self.resetROIMenuStates()
            }
        }
        let roiMenu = UIMenu(title: "Regions", identifier: UIMenu.Identifier(rawValue: "RegionsMenu"), options: .displayInline, children: regionActions)
        let overlayMenu = UIMenu(title: "Overlays", identifier: UIMenu.Identifier(rawValue: "OverlaysMeny"), options: .displayInline, children: overlayActions)
        
        let menu = UIMenu(title: "Region of Interest Examples", identifier: UIMenu.Identifier(rawValue: "OptionsMenu"), children: [roiMenu, overlayMenu])
        
        return menu
    }
    
    private func resetROIMenuStates()
    {
        self.rectOfInterestButton.menu = nil
        self.rectOfInterestButton.menu = self.createROIMenu()
    }
    
    // Coordinate Calculation Helper Functions
        
    private func setROI(newROI: CGRect)
    {
        let updatedRect = self.convertToNormalizedCameraCoordinates(normalizedUIRect: newROI)
        self.selectedRectOfInterest = newROI
        self.rectOfInterest = updatedRect
    }
    
    /// The sample values for region of interest are in normalized, UI view coordinates. This region
    /// (`CGRect`) should be converted to coordinates that work for the device's camera (which is always
    /// in landscape). This helper function will take normalized, UI view-space coordinates and turn them
    /// into normalized camera-device-space coordinates. The result can then be passed to
    /// `videoCaptureReader`'s `rectOfInterest` property.
    private func convertToNormalizedCameraCoordinates(normalizedUIRect: CGRect) -> CGRect
    {
        //  The selected region coordinates are normalized. Turn the region
        //  `CGRect` into points.
        let unnormalizedRectOfInterest = CGRect(x: normalizedUIRect.origin.x    * self.previewLayer!.bounds.width,
                                                y: normalizedUIRect.origin.y    * self.previewLayer!.bounds.height,
                                                width: normalizedUIRect.width   * self.previewLayer!.bounds.width,
                                                height: normalizedUIRect.height * self.previewLayer!.bounds.height)
        // Use AVCaptureVideoPreviewLayer
        // `metadataOutputRectConverted(fromLayerRect rectInLayerCoordinates: CGRect)`
        // to turn the un-normalized input into normalized camera-device-coordinates.
        let normalizedInCameraCoordinates = self.previewLayer!.metadataOutputRectConverted(fromLayerRect: unnormalizedRectOfInterest)
        return normalizedInCameraCoordinates
    }
}
