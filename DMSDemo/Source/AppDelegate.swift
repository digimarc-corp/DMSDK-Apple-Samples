// - - - - - - - - - - - - - - - - - - - -
//
// Digimarc Confidential
// Copyright Digimarc Corporation, 2014-2017
//
// - - - - - - - - - - - - - - - - - - - -

import UIKit
import DMSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        enableSDWSupport();
        return true
    }
    
    func enableSDWSupport() {
       Task {
           do {
               let _ = try await DMSDK.LicenseManager.startSecureSession(env: DMSDK.IlluminateEnvironment.production)
           } catch {
               await MainActor.run {
                   print("Failed to start Secure Digital Watermark session.")
               }
           }
       }
   }
    
}

