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
        Crashlytics.startWithAPIKey("e04ad6106ec507d40d90a52437cc374949ab924e")
        
        // setup Ride Report to log to Xcode if available
        DDLog.addLogger(DDTTYLogger.sharedInstance())
        DDTTYLogger.sharedInstance().colorsEnabled = true
        
        self.fileLogger = DDFileLogger()
        self.fileLogger.rollingFrequency = 60 * 60 * 24
        self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(self.fileLogger)
        
        let versionString = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String
        DDLogInfo(String(format: "========================STARTING RIDE REPORT APP v%@========================", versionString))
        
        var hasSeenSetup = NSUserDefaults.standardUserDefaults().boolForKey("hasSeenSetup")
        if (!hasSeenSetup && NSUserDefaults.standardUserDefaults().boolForKey("hasSeenGettingStartedv2")) {
            // in case they saw an old version, make sure they dont see it again.
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenSetup")
            NSUserDefaults.standardUserDefaults().synchronize()
            hasSeenSetup = true
        }
        
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        
        // Start Managers. Note that order matters!
        CoreDataManager.startup()
        APIClient.startup()
        SoftwareUpdateManager.startup()
        WeatherManager.startup()
        
        if (hasSeenSetup) {
            // if they are new, we wait to start data gathering managers
            // this avoids immediately presenting the privacy permission dialogs.
            registerNotifications()
            startupDataGatheringManagers()
            self.transitionToMainNavController()
        } else {
            // SetupRatingViewController calls registerNotifications
            // SetupBatteryViewController calls startupDataGatheringManagers
            self.transitionToSetup()
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func registerNotifications() {
        let goodRideAction = UIMutableUserNotificationAction()
        goodRideAction.identifier = "GOOD_RIDE_IDENTIFIER"
        goodRideAction.title = "Chill\n👍"
        goodRideAction.activationMode = UIUserNotificationActivationMode.Background
        goodRideAction.destructive = false
        goodRideAction.authenticationRequired = false
        
        let badRideAction = UIMutableUserNotificationAction()
        badRideAction.identifier = "BAD_RIDE_IDENTIFIER"
        badRideAction.title = "Stressful\n👎"
        badRideAction.activationMode = UIUserNotificationActivationMode.Background
        badRideAction.destructive = true
        badRideAction.authenticationRequired = false
        
        let rideCompleteCategory = UIMutableUserNotificationCategory()
        rideCompleteCategory.identifier = "RIDE_COMPLETION_CATEGORY"
        rideCompleteCategory.setActions([goodRideAction, badRideAction], forContext: UIUserNotificationActionContext.Minimal)
        rideCompleteCategory.setActions([goodRideAction, badRideAction], forContext: UIUserNotificationActionContext.Default)
   
        let rideStartedCategory = UIMutableUserNotificationCategory()
        rideStartedCategory.identifier = "RIDE_STARTED_CATEGORY"
        
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
    }
    
    func startupDataGatheringManagers() {
        RouteManager.startup()
        MotionManager.startup()
    }
    
    func transitionToSetup() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        var setupVC : SetupViewController = storyBoard.instantiateViewControllerWithIdentifier("setupViewController") as! SetupViewController!
        
        setupVC.setupViewControllersForGettingStarted()
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.addAnimation(transition, forKey: nil)
        
        self.window?.rootViewController = setupVC
        self.window?.makeKeyAndVisible()
    }
    
    func showMapAttribution() {
        if let mapViewController = (((self.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? MainViewController)?.mapViewController {
            mapViewController.mapView.attributionButton.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
        }
    }
    
    func transitionToCreatProfile() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        var setupVC : SetupViewController = storyBoard.instantiateViewControllerWithIdentifier("setupViewController") as! SetupViewController!
        
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
        var viewController : UIViewController = storyBoard.instantiateViewControllerWithIdentifier("slidingViewController") as! UIViewController!
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.addAnimation(transition, forKey: nil)
        
        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()
    }
    
    func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
        if ((notificationSettings.types&UIUserNotificationType.Alert) == nil) {
            // can't send alerts, let the user know.
            if (!NSUserDefaults.standardUserDefaults().boolForKey("UserKnowsNotificationsAreDisabled")) {
                let alert = UIAlertView(title: "Notifications are disabled", message: "Ride Report needs permission to send notifications to deliver Ride reports to your lock screen.", delegate: self, cancelButtonTitle:nil, otherButtonTitles:"Disable Lock Screen Reports", "Go to Notification Settings")
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
        var trip : Trip! = nil
        if (notification.userInfo != nil && notification.userInfo!["RideNotificationTripUUID"] != nil) {
            trip = Trip.tripWithUUID(notification.userInfo!["RideNotificationTripUUID"] as! String)
        }
        
        if (trip == nil) {
            trip =  Trip.mostRecentTrip()
        }
        
        if (identifier == "GOOD_RIDE_IDENTIFIER") {
            trip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
            
            APIClient.sharedClient.saveAndSyncTripIfNeeded(trip, syncInBackground: true)
            self.postTripRatedThanksNotification(true)
        } else if (identifier == "BAD_RIDE_IDENTIFIER") {
            trip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
            
            APIClient.sharedClient.saveAndSyncTripIfNeeded(trip, syncInBackground: true)
            self.postTripRatedThanksNotification(false)
        } else if (identifier == "FLAG_IDENTIFIER") {
            let incident = Incident(location: trip.mostRecentLocation()!, trip: trip)
            CoreDataManager.sharedManager.saveContext()
        } else if (identifier == "RESUME_IDENTIFIER") {
            RouteManager.sharedManager.resumeTracking()
        }
    }
    
    func postTripRatedThanksNotification(wasGoodTrip: Bool) {
        var emojicuteness : [Character] = []
        var thanksPhrases : [String] = []
        
        if (wasGoodTrip) {
            emojicuteness = Array("🐯🍄🐎🙌🐵🐌🌠🍌🍕🍳🍯🍻🎀🎃📈🎄👑💙⛄️💃🎩🏆")
            thanksPhrases = ["Thanks!", "Sweet!", "YES!", "kewlll", "w00t =)", "yaay（＾_＾)", "Nice.", "Spleenndid"]
        } else {
            emojicuteness = Array("😓😔😿💩😤🐷🍆💔🚽📌🚸🚳📉😭")
            thanksPhrases = ["Maww =(", "d'oh!", "sad panda (´･︹ ･` )", "Shucks.", "oh well =(", "drats", "dag =/", "(・_・)ヾ"]
        }
        
        let thanksPhrase = thanksPhrases[Int(arc4random_uniform(UInt32(count(thanksPhrases))))]
        let emoji1 = String(emojicuteness[Int(arc4random_uniform(UInt32(count(emojicuteness))))])
        let emoji2 = String(emojicuteness[Int(arc4random_uniform(UInt32(count(emojicuteness))))])
        
        let notif = UILocalNotification()
        notif.alertBody = emoji1 + thanksPhrase + emoji2
        UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            
        let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            UIApplication.sharedApplication().cancelLocalNotification(notif)
        })

        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
            UIApplication.sharedApplication().cancelLocalNotification(notif)
            
            if (backgroundTaskID != UIBackgroundTaskInvalid) {
                UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
            }
        })
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        if (url.scheme == "ridereport") {
            if (url.host == "verify-email"){
                if let queryItems = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)?.queryItems as? [NSURLQueryItem] {
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

