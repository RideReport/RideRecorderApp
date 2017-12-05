//
//  AppDelegate.swift
//  Ride Report
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import RouteRecorder
import CoreData
import CoreMotion
import Crashlytics
import OAuthSwift
import FBSDKCoreKit
import Mixpanel
import CocoaLumberjack

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var fileLogger : DDFileLogger!
        
    class func appDelegate() -> AppDelegate! {
        let delegate = UIApplication.shared.delegate
        
        if (delegate!.isKind(of: AppDelegate.self)) {
            return delegate as! AppDelegate
        }
        
        return nil
    }


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Crashlytics.start(withAPIKey: "e04ad6106ec507d40d90a52437cc374949ab924e")

#if DEBUG
        // setup Ride Report to log to Xcode if available
        DDLog.add(DDTTYLogger.sharedInstance)
        DDTTYLogger.sharedInstance.colorsEnabled = true
#endif
        
        self.fileLogger = DDFileLogger()
        self.fileLogger.rollingFrequency = TimeInterval(60 * 60 * 24)
        self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(self.fileLogger)
        
        UINavigationBar.appearance().tintColor = ColorPallete.shared.primary
        UISwitch.appearance().onTintColor = ColorPallete.shared.goodGreen
        UISegmentedControl.appearance().tintColor = ColorPallete.shared.primary
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedStringKey.foregroundColor:UIColor.clear], for: .selected)
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedStringKey.foregroundColor:UIColor.clear], for: .normal)
        UITabBar.appearance().tintColor = ColorPallete.shared.primary
        UIApplication.shared.statusBarStyle = .lightContent
        
        if #available(iOS 9.0, *) {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = ColorPallete.shared.primary
        }
        
        let versionString = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        DDLogInfo(String(format: "========================STARTING RIDE REPORT APP v%@========================", versionString))
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.transitionToCreatProfile), name: Notification.Name(rawValue:"CoreDataManagerDidHardResetWithReadError"), object: nil)
        
        // Start Managers. The order matters!
        Mixpanel.initialize(token: "30ec76ef2bd713e7672d39b5e718a3af")
        CoreDataManager.startup()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.appDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        })

#if DEBUG
    if ProcessInfo.processInfo.environment["USE_TEST_MODE"] != nil {
        RouteRecorder.inject(motionManager: CMMotionManager(),
                                      locationManager: LocationManager(type: .gpx),
                                      routeManager: RouteManager(),
                                      randomForestManager: RandomForestManager(),
                                      classificationManager: TestClassificationManager())
        
        RouteRecorder.shared.locationManager.secondLength = 0.4
        RouteRecorder.shared.locationManager.setLocations(locations: GpxLocationGenerator.generate(distanceInterval: 0.1, count: 5, startingCoordinate: CLLocationCoordinate2DMake(45.5231, -122.6765), startingDate: Date()))
        
        let predictionTemplate = PredictedActivity(activityType: .cycling, confidence: 0.4, prediction: nil)
        let predictionTemplate2 = PredictedActivity(activityType: .cycling, confidence: 0.5, prediction: nil)
        let predictionTemplate3 = PredictedActivity(activityType: .cycling, confidence: 0.6, prediction: nil)
        let predictionTemplate4 = PredictedActivity(activityType: .cycling, confidence: 1.0, prediction: nil)
        RouteRecorder.shared.classificationManager.setTestPredictionsTemplates(testPredictions: [predictionTemplate, predictionTemplate2, predictionTemplate3, predictionTemplate4])
    }
#endif
        
        if (!RouteRecorder.isInjected) {
            // the RouteRecorder can be constructed by a test component
            // to allow for dependency injection
            
            RouteRecorder.inject(motionManager: CMMotionManager(),
                                       locationManager: LocationManager(type: .coreLocation),
                                       routeManager: RouteManager(),
                                       randomForestManager: RandomForestManager(),
                                       classificationManager: SensorClassificationManager())
        }
        
        RideReportAPIClient.startup()
        TripsManager.startup()
        
        if #available(iOS 10.0, *) {
            WatchManager.startup()
        }
        
        if (UserDefaults.standard.bool(forKey: "healthKitIsSetup")) {
            HealthKitManager.startup()
        }
        
        if (UserDefaults.standard.bool(forKey: "hasSeenSetup")) {
            // For new users, we wait to start permission-needing managers
            // This avoids immediately presenting the privacy permission dialogs.
            
            NotificationManager.startup()

            RouteRecorder.shared.randomForestManager.startup()
            RouteRecorder.shared.classificationManager.startup(handler: {})
            
            if launchOptions?[UIApplicationLaunchOptionsKey.location] != nil {
                DDLogInfo("Launched in background due to location update")
                RouteRecorder.shared.routeManager.startup(true)
            } else {
                RouteRecorder.shared.routeManager.startup(false)
            }
            
            self.transitionToMainNavController()
        } else {
            // Otherwise SetupPermissionsViewController starts up the permission-needing managers
            self.transitionToSetup()
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func transitionToSetup() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let setupVC : SetupViewController = storyBoard.instantiateViewController(withIdentifier: "setupViewController") as! SetupViewController
        
        setupVC.setupViewControllersForGettingStarted()
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.add(transition, forKey: nil)
        
        self.window?.rootViewController = setupVC
        self.window?.makeKeyAndVisible()
    }
    
    @objc func appDidBecomeActive() {
        if (CoreDataManager.shared.isStartingUp) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil)
                RideReportAPIClient.shared.syncStatus()
            }
        } else {
            RideReportAPIClient.shared.syncStatus()
        }
    }
    
    func showMapAttribution() {
        if let window = self.window, let rootVC = window.rootViewController as? UITabBarController, let vcs = rootVC.viewControllers {
            for vc in vcs {
                if let directionsVC = vc as? DirectionsViewController {
                    rootVC.selectedViewController = directionsVC
                    directionsVC.showMapInfo()
                }
            }
        }
    }
    
    func logout() {
        Profile.resetProfile()
        CoreDataManager.shared.resetDatabase()
        AppDelegate.appDelegate().transitionToCreatProfile()
    }
    
    @objc func transitionToCreatProfile() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let setupVC : SetupViewController = storyBoard.instantiateViewController(withIdentifier: "setupViewController") as! SetupViewController
        
        setupVC.setupViewControllersForCreateProfile()
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.add(transition, forKey: nil)
        
        self.window?.rootViewController = setupVC
        self.window?.makeKeyAndVisible()
    }
    
    func transitionToConnectApp(_ app: ConnectedApp) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let navVC = storyBoard.instantiateViewController(withIdentifier: "ConnectedAppSetupNavController") as! UINavigationController
        
        guard let connectVC = navVC.topViewController as? ConnectedAppsBrowseViewController else {
            return
        }
        
        if let rootVC = self.window?.rootViewController {
            if let presentedVC = rootVC.presentedViewController {
                // dismiss anything in the way first
                presentedVC.dismiss(animated: false, completion: nil)
            }
            
            connectVC.launchToConnectedApp = app
            rootVC.present(navVC, animated: true, completion: nil)
        }
    }
    
    
    func transitionToMainNavController() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let viewController : UIViewController = storyBoard.instantiateViewController(withIdentifier: "mainViewController") as UIViewController!
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.window?.rootViewController?.view.layer.add(transition, forKey: nil)
        
        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()
    }
    
    func transitionToTripView(trip: Trip) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        guard let tripVC = storyBoard.instantiateViewController(withIdentifier: "TripViewController") as? TripViewController else {
            return
        }
        
        if let window = self.window, let rootVC = window.rootViewController as? UITabBarController, let vcs = rootVC.viewControllers, let navVC = vcs.first as? UINavigationController {
            if rootVC.selectedIndex != 0 {
                rootVC.selectedIndex = 0
            }
            
            if let presentedVC = rootVC.presentedViewController {
                // dismiss anything in the way first
                presentedVC.dismiss(animated: false, completion: nil)
            }
            tripVC.selectedTrip = trip
            navVC.pushViewController(tripVC, animated: true)
        }
    }
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        NotificationManager.shared.didRegisterForNotifications(notificationSettings: notificationSettings)
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        DDLogInfo("Received Memory Warning!")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        RideReportAPIClient.shared.appDidReceiveNotificationDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        RideReportAPIClient.shared.appDidReceiveNotificationDeviceToken(nil)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DDLogInfo("Beginning remote notification background task!")
        var backgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
            DDLogInfo("Received remote notification background task expired!")
            completionHandler(.newData)
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = UIBackgroundTaskInvalid

        })
        
        let completionBlock = {
            DispatchQueue.main.async(execute: { () -> Void in
                completionHandler(.newData)
                
                if (backgroundTaskID != UIBackgroundTaskInvalid) {
                    DDLogInfo("Ending remote notification background task!")

                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            })
        }
        
        if let syncTrips = userInfo["syncTrips"] as? Bool, syncTrips {
            DDLogInfo("Received sync trips notification")
            if UIDevice.current.batteryState == UIDeviceBatteryState.charging || UIDevice.current.batteryState == UIDeviceBatteryState.full {
                // if the user is plugged in, go ahead and sync all unsynced trips.
                RouteRecorder.shared.uploadRoutes(includeFullLocations: true, completionBlock: completionBlock)
            } else {
                completionBlock()
            }
        } else {
            NotificationManager.shared.didReceiveNotification(userInfo: userInfo)
            completionBlock()
        }
    }
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
        if #available(iOS 10.0, *) {
            // Handled by NotificationManager
        } else {
            if let userInfo = notification.userInfo {
                NotificationManager.shared.handleNotificationAction(identifier, userInfo: userInfo, completionHandler: completionHandler)
            }
        }
    }
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
        if #available(iOS 10.0, *) {
            // Handled by NotificationManager
        } else {
            NotificationManager.shared.handleNotificationAction(identifier, userInfo: userInfo, completionHandler: completionHandler)
        }
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        if (url.scheme == "ridereport") {
            if (url.host == "verify-email"){
                if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                    for item in queryItems {
                        if let result = item.value, item.name == "result" {
                            if result == "success" {
                                //
                            } else if result == "failure" {
                                //
                            }
                        }
                    }
                }
            } else if (url.host == "authcode-callback") {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "RideReportAuthCodeCallBackNotification"), object: url)
            } else if (url.host == "authorize-application") {
                if let uuid = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.filter({ $0.name == "uuid" }).first?.value {
                    var fixedUUID = uuid
                    if (!uuid.contains("-") && uuid.characters.count == 32) {
                        // work around an absurd issue where we sometimes have URL's out there with dashless uuids.
                        fixedUUID.insert("-", at: fixedUUID.index(fixedUUID.startIndex, offsetBy: 8))
                        fixedUUID.insert("-", at: fixedUUID.index(fixedUUID.startIndex, offsetBy: 13))
                        fixedUUID.insert("-", at: fixedUUID.index(fixedUUID.startIndex, offsetBy: 18))
                        fixedUUID.insert("-", at: fixedUUID.index(fixedUUID.startIndex, offsetBy: 23))
                    }
                    let app = ConnectedApp.createOrUpdate(fixedUUID)
                    
                    RideReportAPIClient.shared.getApplication(app).apiResponse({ (response) in
                        switch response.result {
                        case .success(_):
                            app.isHiddenApp = true
                            CoreDataManager.shared.saveContext()
                            
                            DispatchQueue.main.async {
                                self.transitionToConnectApp(app)
                            }
                        case .failure(let error):
                            DDLogWarn(String(format: "Error getting third party app from URL scheme: %@", error as CVarArg))
                        }
                    })
                }
            }
        } else if (url.host == "oauth-callback") {
            if ( url.path.hasPrefix("/facebook" )){
                OAuth2Swift.handle(url: url)
            }
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        FBSDKAppEvents.activateApp()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        let notif = UILocalNotification()
        notif.alertBody = "Hey, you quit Ride Report! That's cool, but if you want to pause it you can use the compass button in the app."
        UIApplication.shared.presentLocalNotificationNow(notif)
    }

}

