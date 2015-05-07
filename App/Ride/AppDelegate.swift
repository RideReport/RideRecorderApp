//
//  AppDelegate.swift
//  Ride
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import CoreData
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UIAlertViewDelegate {

    var window: UIWindow?
    var fileLogger : DDFileLogger!
    
    class func appDelegate() -> AppDelegate! {
        let delegate = UIApplication.sharedApplication().delegate
        
        if (delegate!.isKindOfClass(AppDelegate)) {
            return delegate as! AppDelegate
        }
        
        return nil
    }


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        Crashlytics.startWithAPIKey("e04ad6106ec507d40d90a52437cc374949ab924e")
        
        let goodRideAction = UIMutableUserNotificationAction()
        goodRideAction.identifier = "GOOD_RIDE_IDENTIFIER"
        goodRideAction.title = "👍"
        goodRideAction.activationMode = UIUserNotificationActivationMode.Background
        goodRideAction.destructive = false
        goodRideAction.authenticationRequired = false
        
        let badRideAction = UIMutableUserNotificationAction()
        badRideAction.identifier = "BAD_RIDE_IDENTIFIER"
        badRideAction.title = "👎"
        badRideAction.activationMode = UIUserNotificationActivationMode.Background
        badRideAction.destructive = true
        badRideAction.authenticationRequired = false
        
        let rideCompleteCategory = UIMutableUserNotificationCategory()
        rideCompleteCategory.identifier = "RIDE_COMPLETION_CATEGORY"
        rideCompleteCategory.setActions([goodRideAction, badRideAction], forContext: UIUserNotificationActionContext.Minimal)
        rideCompleteCategory.setActions([goodRideAction, badRideAction], forContext: UIUserNotificationActionContext.Default)
        
        let flagAction = UIMutableUserNotificationAction()
        flagAction.identifier = "FLAG_IDENTIFIER"
        flagAction.title = "🚩"
        flagAction.activationMode = UIUserNotificationActivationMode.Background
        flagAction.destructive = true
        flagAction.authenticationRequired = false
        
        let rideStartedCategory = UIMutableUserNotificationCategory()
        rideStartedCategory.identifier = "RIDE_STARTED_CATEGORY"
        rideStartedCategory.setActions([flagAction], forContext: UIUserNotificationActionContext.Minimal)
        rideStartedCategory.setActions([flagAction], forContext: UIUserNotificationActionContext.Default)
        
        let resumeAction = UIMutableUserNotificationAction()
        resumeAction.identifier = "RESUME_IDENTIFIER"
        resumeAction.title = "Resume"
        resumeAction.activationMode = UIUserNotificationActivationMode.Background
        resumeAction.destructive = false
        resumeAction.authenticationRequired = false
        
        let appPausedCategory = UIMutableUserNotificationCategory()
        appPausedCategory.identifier = "APP_PAUSED_CATEGORY"
        appPausedCategory.setActions([resumeAction], forContext: UIUserNotificationActionContext.Minimal)
        appPausedCategory.setActions([resumeAction], forContext: UIUserNotificationActionContext.Default)
        
        let types = UIUserNotificationType.Badge | UIUserNotificationType.Sound | UIUserNotificationType.Alert
        let settings = UIUserNotificationSettings(forTypes: types, categories: Set([rideCompleteCategory, rideStartedCategory, appPausedCategory]))
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
        
        // setup Ride to log to Xcode if available
        DDLog.addLogger(DDTTYLogger.sharedInstance())
        DDTTYLogger.sharedInstance().colorsEnabled = true
        
        self.fileLogger = DDFileLogger()
        self.fileLogger.rollingFrequency = 60 * 60 * 24
        self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(self.fileLogger)
        
        let versionString = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String
        DDLogWrapper.logInfo(String(format: "========================STARTING RIDE APP v%@========================", versionString))
        
        // Start Managers. Note that order matters!
        CoreDataManager.startup()
        RouteManager.startup()
        SoftwareUpdateManager.startup()
        NetworkManager.startup()
        MotionManager.startup()
        WeatherManager.startup()
        
        return true
    }
    
    func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
        if ((notificationSettings.types&UIUserNotificationType.Alert) == nil) {
            // can't send alerts, let the user know.
            if (!NSUserDefaults.standardUserDefaults().boolForKey("UserKnowsNotificationsAreDisabled")) {
                let alert = UIAlertView(title: "Notifications are disabled", message: "Ride needs permission to send notifications to deliver Ride reports to your lock screen.", delegate: self, cancelButtonTitle:nil, otherButtonTitles:"Disable Lock Screen Reports", "Go to Notification Settings")
                alert.show()
            }
        }
    }
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            let url = NSURL(string: UIApplicationOpenSettingsURLString)
            if url != nil && UIApplication.sharedApplication().canOpenURL(url!) {
                UIApplication.sharedApplication().openURL(url!)
            }
        } else {
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "UserKnowsNotificationsAreDisabled")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        let trip = Trip.mostRecentTrip()
        
        if (identifier == "GOOD_RIDE_IDENTIFIER") {
            trip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
            
            NetworkManager.sharedManager.saveAndSyncTripIfNeeded(trip, syncInBackground: true)
        } else if (identifier == "BAD_RIDE_IDENTIFIER") {
            trip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
            
            NetworkManager.sharedManager.saveAndSyncTripIfNeeded(trip, syncInBackground: true)
        } else if (identifier == "FLAG_IDENTIFIER") {
            let incident = Incident(location: trip.mostRecentLocation()!, trip: trip)
            CoreDataManager.sharedManager.saveContext()
        } else if (identifier == "RESUME_IDENTIFIER") {
            RouteManager.sharedManager.resumeTracking()
        }
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NetworkManager.sharedManager.syncTrips()
    }

    func applicationWillTerminate(application: UIApplication) {
        let notif = UILocalNotification()
        notif.alertBody = "Hey, you quit Ride! That's cool, but if you want to pause it you can use the compass button in the app."
        UIApplication.sharedApplication().presentLocalNotificationNow(notif)
    }

}

