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
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var fileLogger : DDFileLogger!
    
    class func appDelegate() -> AppDelegate! {
        let delegate = UIApplication.sharedApplication().delegate
        
        if (delegate!.isKindOfClass(AppDelegate)) {
            return delegate as AppDelegate
        }
        
        return nil
    }


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        Crashlytics.startWithAPIKey("e04ad6106ec507d40d90a52437cc374949ab924e")
        
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        
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
        
        let types = UIUserNotificationType.Badge | UIUserNotificationType.Sound | UIUserNotificationType.Alert
        let settings = UIUserNotificationSettings(forTypes: types, categories: NSSet(object: rideCompleteCategory))
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
        
        // setup the file logger
        DDLog.addLogger(UIForLumberjack.sharedInstance())
        
        // setup Knock to log to Xcode if available
        DDLog.addLogger(DDTTYLogger.sharedInstance())
        DDTTYLogger.sharedInstance().colorsEnabled = true
        
        self.fileLogger = DDFileLogger()
        self.fileLogger.rollingFrequency = 60 * 60 * 24
        self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(self.fileLogger)
        
        let versionString = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as String
        DDLogWrapper.logInfo(NSString(format: "========================STARTING RIDE APP v%@========================", versionString))
        
        // fire up Core Data
        CoreDataController.sharedCoreDataController.startup()
        RouteMachine.sharedMachine.startup((launchOptions?[UIApplicationLaunchOptionsLocationKey] != nil))
        SoftwareUpdateMachine.sharedMachine.startup()
        
        return true
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if (identifier == "GOOD_RIDE_IDENTIFIER") {
            Trip.mostRecentTrip().rating = NSNumber(short: Trip.Rating.Good.rawValue)
            CoreDataController.sharedCoreDataController.saveContext()
            
            Trip.mostRecentTrip().syncToServer()
        } else if (identifier == "BAD_RIDE_IDENTIFIER") {
            Trip.mostRecentTrip().rating = NSNumber(short: Trip.Rating.Bad.rawValue)
            CoreDataController.sharedCoreDataController.saveContext()
            
            Trip.mostRecentTrip().syncToServer()
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
        Trip.syncTrips()
    }

    func applicationWillTerminate(application: UIApplication) {
        let notif = UILocalNotification()
        notif.alertBody = "Hey, you quit Ride! That's cool, but if you want to pause it you can use the compass button in the app."
        UIApplication.sharedApplication().presentLocalNotificationNow(notif)
    }

}

