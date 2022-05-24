// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK

class ScannerViewController: DetectorViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // An example of how to remove a default UI element from the Drop-In View Controller:
        self.userGuidanceView.removeFromSuperview()
    }
}
