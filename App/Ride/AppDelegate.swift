//
//  AppDelegate.swift
//  Ride Report
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import CoreData
import Crashlytics
import OAuthSwift
import FBSDKCoreKit
import ECSlidingViewController
import Mixpanel

enum PushNotificationRegistrationStatus {
    case Unregistered
    case Registered
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UIAlertViewDelegate {

    var window: UIWindow?
    var fileLogger : DDFileLogger!
    
    var notificationRegistrationStatus : PushNotificationRegistrationStatus = .Unregistered
    
    class func appDelegate() -> AppDelegate! {
        let delegate = UIApplication.sharedApplication().delegate
        
        if (delegate!.isKindOfClass(AppDelegate)) {
            return delegate as! AppDelegate
        }
        
        return nil
    }


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Crashlytics.startWithAPIKey("e04ad6106ec507d40d90a52437cc374949ab924e")

#if DEBUG
        // setup Ride Report to log to Xcode if available
        DDLog.addLogger(DDTTYLogger.sharedInstance())
        DDTTYLogger.sharedInstance().colorsEnabled = true
#endif
        
        self.fileLogger = DDFileLogger()
        self.fileLogger.rollingFrequency = 60 * 60 * 24
        self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(self.fileLogger)
        
        UINavigationBar.appearance().barTintColor = ColorPallete.sharedPallete.darkGreen
        UINavigationBar.appearance().tintColor = ColorPallete.sharedPallete.almostWhite
        
        let versionString = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String
        DDLogInfo(String(format: "========================STARTING RIDE REPORT APP v%@========================", versionString))
        
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        
        // start managers after returing
        
        // Start Managers. The order matters!
        Mixpanel.sharedInstanceWithToken("30ec76ef2bd713e7672d39b5e718a3af")
        CoreDataManager.startup()
        APIClient.startup()
        RandomForestManager.startup()
        
        if (NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup")) {
            HealthKitManager.startup()
        }
        
        if (NSUserDefaults.standardUserDefaults().boolForKey("hasSeenSetup")) {
            // For new users, we wait to start permission-needing managers
            // This avoids immediately presenting the privacy permission dialogs.
            
            dispatch_async(dispatch_get_main_queue()) {
                // perform async
                self.startupNotifications()
            }
            MotionManager.startup()
            
            if launchOptions?[UIApplicationLaunchOptionsLocationKey] != nil {
                DDLogInfo("Launched in background due to location update")
                RouteManager.startup(true)
            } else {
                RouteManager.startup(false)
            }
            
            self.transitionToMainNavController()
        } else {
            // Otherwise SetupPermissionsViewController starts up the permission-needing managers
            self.transitionToSetup()
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func startupNotifications() {
        let goodRideAction = UIMutableUserNotificationAction()
        goodRideAction.identifier = "GOOD_RIDE_IDENTIFIER"
        goodRideAction.title = "Recommend\n👍"
        goodRideAction.activationMode = UIUserNotificationActivationMode.Background
        goodRideAction.destructive = false
        goodRideAction.authenticationRequired = false
        
        let badRideAction = UIMutableUserNotificationAction()
        badRideAction.identifier = "BAD_RIDE_IDENTIFIER"
        badRideAction.title = "Avoid\n👎"
        badRideAction.activationMode = UIUserNotificationActivationMode.Background
        badRideAction.destructive = true
        badRideAction.authenticationRequired = false
        
        let rideCompleteCategory = UIMutableUserNotificationCategory()
        rideCompleteCategory.identifier = "RIDE_COMPLETION_CATEGORY"
        rideCompleteCategory.setActions([goodRideAction, badRideAction], forContext: UIUserNotificationActionContext.Minimal)
        rideCompleteCategory.setActions([goodRideAction, badRideAction], forContext: UIUserNotificationActionContext.Default)
   
        let rideStartedCategory = UIMutableUserNotificationCategory()
        rideStartedCategory.identifier = "RIDE_STARTED_CATEGORY"
        
        #if DEBUG
            let debugCategory = UIMutableUserNotificationCategory()
            debugCategory.identifier = "DEBUG_CATEGORY"
        #endif
        
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
        
        var notificationCategories : Set<UIUserNotificationCategory> = Set([rideCompleteCategory, rideStartedCategory, appPausedCategory])
        #if DEBUG
            notificationCategories.insert(debugCategory)
        #endif
        
        let types: UIUserNotificationType = [UIUserNotificationType.Badge, UIUserNotificationType.Sound, UIUserNotificationType.Alert]
        let settings = UIUserNotificationSettings(forTypes: types, categories: notificationCategories)
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
        UIApplication.sharedApplication().registerForRemoteNotifications()
    }
    
    func transitionToSetup() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let setupVC : SetupViewController = storyBoard.instantiateViewControllerWithIdentifier("setupViewController") as! SetupViewController
        
        setupVC.setupViewControllersForGettingStarted()
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.addAnimation(transition, forKey: nil)
        
        self.window?.rootViewController = setupVC
        self.window?.makeKeyAndVisible()
    }
    
    func showMapAttribution() {
        if let routesVC = (((self.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? RoutesViewController) {
            routesVC.showMapInfo()
        }
    }
    
    func transitionToCreatProfile() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let setupVC : SetupViewController = storyBoard.instantiateViewControllerWithIdentifier("setupViewController") as! SetupViewController
        
        setupVC.setupViewControllersForCreateProfile()
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.addAnimation(transition, forKey: nil)
        
        self.window?.rootViewController = setupVC
        self.window?.makeKeyAndVisible()
    }
    
    
    func transitionToMainNavController() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let viewController : UIViewController = storyBoard.instantiateViewControllerWithIdentifier("slidingViewController") as UIViewController!
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.addAnimation(transition, forKey: nil)
        
        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()
    }
    
    func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
        if ((notificationSettings.types.intersect(UIUserNotificationType.Alert)) == []) {
            // can't send alerts, let the user know.
            if (!NSUserDefaults.standardUserDefaults().boolForKey("UserKnowsNotificationsAreDisabled")) {
                let alert = UIAlertView(title: "Notifications are disabled", message: "Ride Report needs permission to send notifications to deliver Ride reports to your lock screen.", delegate: self, cancelButtonTitle:nil, otherButtonTitles:"Disable Lock Screen Reports", "Go to Notification Settings")
                alert.show()
            }
        }
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        self.notificationRegistrationStatus = .Registered
        
        APIClient.sharedClient.appDidReceiveNotificationDeviceToken(deviceToken)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        APIClient.sharedClient.appDidReceiveNotificationDeviceToken(nil)
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
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        DDLogInfo("Beginning remote notification background task!")
        let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            DDLogInfo("Received remote notification background task expired!")
            completionHandler(.NewData)
        })
        
        let completionBlock = {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                completionHandler(.NewData)
                
                if (backgroundTaskID != UIBackgroundTaskInvalid) {
                    DDLogInfo("Ending remote notification background task!")

                    UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
                }
            })
        }
        
        if let syncTrips = userInfo["syncTrips"] as? Bool where syncTrips {
            DDLogInfo("Received sync trips notification")
            if UIDevice.currentDevice().batteryState == UIDeviceBatteryState.Charging || UIDevice.currentDevice().batteryState == UIDeviceBatteryState.Full {
                // if the user is plugged in, go ahead and sync all unsynced trips.
                APIClient.sharedClient.syncUnsyncedTrips(true, completionBlock: completionBlock)
            }
        } else if let uuid = userInfo["uuid"] as? String,
            let trip = Trip.tripWithUUID(uuid) {
            
            var clearRemoteMessage = false
            if let aps = userInfo["aps"] as? NSDictionary, _ = aps["alert"] as? String {
                clearRemoteMessage = true
            }
            DDLogInfo(String(format: "Received trip summary notification, uuid: %@", uuid))
            trip.loadSummaryFromAPNDictionary(userInfo)
            CoreDataManager.sharedManager.saveContext()
            trip.sendTripCompletionNotificationLocally(clearRemoteMessage)
            completionBlock()
        } else {
            completionBlock()
        }
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if let userInfo = notification.userInfo {
            self.handleNotificationAction(identifier, userInfo: userInfo, completionHandler: completionHandler)
        }
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
        self.handleNotificationAction(identifier, userInfo: userInfo, completionHandler: completionHandler)
    }
    
    func handleNotificationAction(identifier: String?, userInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
        if let uuid = userInfo["uuid"] as? String,
            trip = Trip.tripWithUUID(uuid) {
                if (identifier == "GOOD_RIDE_IDENTIFIER") {
                    trip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
                    self.postTripRatedThanksNotification(true)

                    APIClient.sharedClient.saveAndSyncTripIfNeeded(trip, syncInBackground: true).apiResponse({ (_) -> Void in
                        completionHandler()
                    })
                } else if (identifier == "BAD_RIDE_IDENTIFIER") {
                    trip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
                    
                    self.postTripRatedThanksNotification(false)
                    APIClient.sharedClient.saveAndSyncTripIfNeeded(trip, syncInBackground: true).apiResponse({ (_) -> Void in
                        completionHandler()
                    })
                } else if (identifier == "FLAG_IDENTIFIER") {
                    _ = Incident(location: trip.mostRecentLocation()!, trip: trip)
                    CoreDataManager.sharedManager.saveContext()
                    completionHandler()
                }
        }
        
        if (identifier == "RESUME_IDENTIFIER") {
            RouteManager.sharedManager.resumeTracking()
            completionHandler()
        }
    }
    
    func postTripRatedThanksNotification(wasGoodTrip: Bool) {
        var emojicuteness : [Character] = []
        var thanksPhrases : [String] = []
        
        if (wasGoodTrip) {
            emojicuteness = Array("🐯🍄🐎🙌🐵🐌🌠🍌🍕🍳🍯🍻🎀🎃📈🎄👑💙⛄️💃🎩🏆".characters)
            thanksPhrases = ["Thanks!", "Sweet!", "YES!", "kewlll", "w00t =)", "yaay（＾_＾)", "Nice.", "Spleenndid"]
        } else {
            emojicuteness = Array("😓😔😿💩😤🐷🍆💔🚽📌🚸🚳📉😭".characters)
            thanksPhrases = ["Maww =(", "d'oh!", "sad panda (´･︹ ･` )", "Shucks.", "oh well =(", "drats", "dag =/", "(・_・)ヾ"]
        }
        
        let thanksPhrase = thanksPhrases[Int(arc4random_uniform(UInt32(thanksPhrases.count)))]
        let emoji1 = String(emojicuteness[Int(arc4random_uniform(UInt32(emojicuteness.count)))])
        let emoji2 = String(emojicuteness[Int(arc4random_uniform(UInt32(emojicuteness.count)))])
        
        let notif = UILocalNotification()
        notif.alertBody = emoji1 + thanksPhrase + emoji2
        UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        
        DDLogInfo("Beginning post trip rating background task!")
        let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            DDLogInfo("Post trip notification background task expired!")
            UIApplication.sharedApplication().cancelLocalNotification(notif)
        })

        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
            UIApplication.sharedApplication().cancelLocalNotification(notif)
            
            if (backgroundTaskID != UIBackgroundTaskInvalid) {
                DDLogInfo("Ending post trip rating background task!")

                UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
            }
        })
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        if (url.scheme == "ridereport") {
            if (url.host == "verify-email"){
                if let queryItems = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)?.queryItems {
                    for item in queryItems {
                        if let result = item.value where item.name == "result" {
                            if result == "success" {
                                //
                            } else if result == "failure" {
                                //
                            }
                        }
                    }
                }
            }
        } else if (url.host == "oauth-callback") {
            if ( url.path!.hasPrefix("/facebook" )){
                OAuth2Swift.handleOpenURL(url)
            }
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
    }

    func applicationWillResignActive(application: UIApplication) {
    }

    func applicationDidEnterBackground(application: UIApplication) {
    }

    func applicationWillEnterForeground(application: UIApplication) {
    }

    func applicationDidBecomeActive(application: UIApplication) {
        FBSDKAppEvents.activateApp()
    }

    func applicationWillTerminate(application: UIApplication) {
        let notif = UILocalNotification()
        notif.alertBody = "Hey, you quit Ride Report! That's cool, but if you want to pause it you can use the compass button in the app."
        UIApplication.sharedApplication().presentLocalNotificationNow(notif)
    }

}

