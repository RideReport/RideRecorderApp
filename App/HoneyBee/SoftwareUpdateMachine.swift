//
//  SoftwareUpdateMachine.swift
//  Ride
//
//  Created by William Henderson on 1/9/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SoftwareUpdateMachine : NSObject, UIAlertViewDelegate {
    let manifestUrl = NSURL(string: "https://s3-us-west-2.amazonaws.com/rideenterprise/manifest.plist")!
    let minimumUpdateCheckInterval : NSTimeInterval = 60*60*4 // 4 hours
    var lastUpdateCheck : NSDate?
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedMachine : SoftwareUpdateMachine?
    }
    
    class var sharedMachine:SoftwareUpdateMachine {
        dispatch_once(&Static.onceToken) {
            Static.sharedMachine = SoftwareUpdateMachine()
        }
        
        return Static.sharedMachine!
    }
    
    func startup() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
        self.checkForUpdateIfNeeded()
    }
    
    func appDidBecomeActive() {
        self.checkForUpdateIfNeeded()
    }
    
    func checkForUpdateIfNeeded() {
        if (self.lastUpdateCheck != nil && abs(self.lastUpdateCheck!.timeIntervalSinceNow) < self.minimumUpdateCheckInterval ) {
            return
        }
        
        self.lastUpdateCheck = NSDate()
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let manifestDictionary = NSDictionary(contentsOfURL: self.manifestUrl) as [String:AnyObject]?
            if (manifestDictionary != nil) {
                
                let items = manifestDictionary?["items"] as [AnyObject]?
                let item = items?.last as [String:AnyObject]?
                
                let version = item?["metadata"]?["bundle-version"] as String
                let currentVersion = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as String
                
                if (currentVersion.compare(version, options: NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedAscending) {
                    // update is available
                    if (UIApplication.sharedApplication().applicationState != UIApplicationState.Active) {
                        let notif = UILocalNotification()
                        notif.alertBody = "An update to Ride is available! Open Ride to upgrade over the air."
                        UIApplication.sharedApplication().presentLocalNotificationNow(notif)
                    }
                    
                    let alert = UIAlertView(title: "An update to Ride is available", message: "Tap Upgrade to upgrade over the air.", delegate: self, cancelButtonTitle: nil, otherButtonTitles: "Upgrade")
                    alert.show()
                }
            }
        })
    }
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        let itmsURL = NSString(format: "itms-services://?action=download-manifest&url=%@", self.manifestUrl)
        UIApplication.sharedApplication().openURL(NSURL(string: itmsURL)!)
    }
    
}

