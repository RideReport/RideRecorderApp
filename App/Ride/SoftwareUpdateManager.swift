//
//  SoftwareUpdateManager.swift
//  Ride Report
//
//  Created by William Henderson on 1/9/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SoftwareUpdateManager : NSObject, UIAlertViewDelegate {
    let manifestUrl = NSURL(string: "https://app.ride.report/manifest.plist")!
    let minimumUpdateCheckInterval : NSTimeInterval = 60*60*4 // 4 hours
    var lastUpdateCheck : NSDate?
    
    struct Static {
        static var sharedManager : SoftwareUpdateManager?
    }
    
    class var sharedManager:SoftwareUpdateManager {
        return Static.sharedManager!
    }
    
    class func startup() {
        if (Static.sharedManager == nil) {
            Static.sharedManager = SoftwareUpdateManager()
            Static.sharedManager?.startup()
        }
    }
    
    func startup() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
    #if DEBUG
        // don't check for updates on debug builds
        NSLog("Skipping updates!")
    #else
        self.checkForUpdateIfNeeded()
    #endif
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func appDidBecomeActive() {
        self.checkForUpdateIfNeeded()
    }
    
    func checkForUpdateIfNeeded() {
        if (self.lastUpdateCheck != nil && abs(self.lastUpdateCheck!.timeIntervalSinceNow) < self.minimumUpdateCheckInterval ) {
            return
        }
        
        self.lastUpdateCheck = NSDate()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            if let manifestDictionary = NSDictionary(contentsOfURL: self.manifestUrl),
                items = manifestDictionary["items"] as? [AnyObject],
                item = items.last as? [String:AnyObject],
                metadata = item["metadata"] as? [String:AnyObject],
                version = metadata["bundle-version"] as? String,
                currentVersion = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as? String
                where currentVersion.compare(version, options: NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedAscending {
                // update is available
                if (UIApplication.sharedApplication().applicationState != UIApplicationState.Active) {
                    let notif = UILocalNotification()
                    notif.alertBody = "An update to Ride Report is available! Open Ride Report to upgrade."
                    UIApplication.sharedApplication().presentLocalNotificationNow(notif)
                }
                
                let alert = UIAlertView(title: "Ride Report Update Available", message: "", delegate: self, cancelButtonTitle: nil, otherButtonTitles: "Update")
                alert.show()
            }
        })
    }
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        let itmsURL = String(format: "itms-services://?action=download-manifest&url=%@", self.manifestUrl)
        UIApplication.sharedApplication().openURL(NSURL(string: itmsURL as String)!)
    }
    
}

