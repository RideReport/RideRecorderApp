//
//  AppDelegate.swift
//  RouteMachineTestTool
//
//  Created by William Henderson on 1/25/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
//    var fileLogger : DDFileLogger!
    var simpleRouteMachine : SimpleRouteMachine!

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {        
        // setup to log to syslog
        // DDLog.addLogger(DDASLLogger.sharedInstance())
        //
        // // setup to log to Xcode if available
        // DDLog.addLogger(DDTTYLogger.sharedInstance())
        // DDTTYLogger.sharedInstance().colorsEnabled = true
        //
        // self.fileLogger = DDFileLogger()
        // self.fileLogger.rollingFrequency = 60 * 60 * 24
        // self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        // DDLog.addLogger(self.fileLogger)
        
        let rideCompleteCategory = UIMutableUserNotificationCategory()
        rideCompleteCategory.identifier = "RIDE_COMPLETION_CATEGORY"
        
        let types = UIUserNotificationType.Badge | UIUserNotificationType.Sound | UIUserNotificationType.Alert
        let settings = UIUserNotificationSettings(forTypes: types, categories: NSSet(object: rideCompleteCategory))
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)

        
//        CoreDataController.sharedCoreDataController.startup()
//        RouteMachine.sharedMachine.startup((launchOptions?[UIApplicationLaunchOptionsLocationKey] != nil))
//        RouteMachine.sharedMachine.minimumMonitoringSpeed = 0
        
        self.simpleRouteMachine = SimpleRouteMachine()
        
        return true
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
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}
