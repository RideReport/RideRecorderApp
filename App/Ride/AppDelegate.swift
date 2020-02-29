//
//  AppDelegate.swift
//  Ride Report
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import RouteRecorder
import CoreLocation
import CoreData
import CoreMotion
import CocoaLumberjack
import Mapbox

#if DEBUG
    import Mockingjay
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var fileLogger : DDFileLogger!
        
    class func appDelegate() -> AppDelegate! {
        let delegate = UIApplication.shared.delegate
        
        if (delegate!.isKind(of: AppDelegate.self)) {
            return delegate as? AppDelegate
        }
        
        return nil
    }


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
#if DEBUG
        // setup Ride Report to log to Xcode if available
        DDLog.add(DDTTYLogger.sharedInstance)
        DDTTYLogger.sharedInstance.colorsEnabled = true
#endif
        
        self.fileLogger = DDFileLogger()
        self.fileLogger.rollingFrequency = TimeInterval(60 * 60 * 24)
        self.fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(self.fileLogger)
        
        // isBatteryMonitoringEnabled needed to check battery state
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        UINavigationBar.appearance().tintColor = ColorPallete.shared.primary
        UISwitch.appearance().onTintColor = ColorPallete.shared.goodGreen
        UISegmentedControl.appearance().tintColor = ColorPallete.shared.primary
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor:UIColor.clear], for: .selected)
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor:UIColor.clear], for: .normal)
        UITabBar.appearance().tintColor = ColorPallete.shared.primary
        UIApplication.shared.statusBarStyle = .lightContent
        
        if #available(iOS 9.0, *) {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = ColorPallete.shared.primary
        }
        
        let versionString = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        DDLogInfo(String(format: "========================STARTING RIDE APP v%@========================", versionString))
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
                
        // Start Managers. The order matters!
        CoreDataManager.startup()

#if DEBUG
    if ProcessInfo.processInfo.environment["USE_TEST_MODE"] != nil {
        RouteRecorder.inject(motionManager: CMMotionManager(),
                                      locationManager: LocationManager(type: .gpx),
                                      routeManager: RouteManager(),
                                      randomForestManager: RandomForestManager(),
                                      classificationManager: TestClassificationManager())
        
        RouteRecorder.shared.locationManager.secondLength = 0.4
        RouteRecorder.shared.locationManager.setLocations(locations: GpxLocationGenerator.generate(distanceInterval: 0.1, count: 5, startingCoordinate: CLLocationCoordinate2DMake(45.5231, -122.6765), startingDate: Date()))
        
        let predictionTemplate = PredictedActivity(activityType: .automotive, confidence: 0.4, prediction: nil)
        let predictionTemplate2 = PredictedActivity(activityType: .automotive, confidence: 0.5, prediction: nil)
        let predictionTemplate3 = PredictedActivity(activityType: .automotive, confidence: 0.6, prediction: nil)
        let predictionTemplate4 = PredictedActivity(activityType: .automotive, confidence: 1.0, prediction: nil)
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
        
        TripsManager.startup()
        
        if #available(iOS 10.0, *) {
            WatchManager.startup()
        }
        
        if (UserDefaults.standard.bool(forKey: "healthKitIsSetup")) {
            HealthKitManager.startup()
        }
        
        RouteRecorder.shared.randomForestManager.startup()
        RouteRecorder.shared.classificationManager.startup(handler: {})
        
        if (UserDefaults.standard.bool(forKey: "hasSeenSetup")) {
            // For new users, we wait to start permission-needing managers
            // This avoids immediately presenting the privacy permission dialogs.
            
            NotificationManager.startup()
            
            if launchOptions?[UIApplication.LaunchOptionsKey.location] != nil {
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
        
        
        return true
    }
    
    func transitionToSetup() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let setupVC : SetupViewController = storyBoard.instantiateViewController(withIdentifier: "setupViewController") as! SetupViewController
        
        setupVC.setupViewControllersForGettingStarted()
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = CATransitionType.fade
        self.window?.rootViewController?.view.layer.add(transition, forKey: nil)
        
        self.window?.rootViewController = setupVC
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
    
    func transitionToMainNavController() {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let viewController : UIViewController = (storyBoard.instantiateViewController(withIdentifier: "mainViewController") as UIViewController?)!
        
        let transition = CATransition()
        transition.duration = 0.6
        transition.type = CATransitionType.fade
        self.window?.rootViewController?.view.layer.add(transition, forKey: nil)
        
        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()
    }
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        NotificationManager.shared.didRegisterForNotifications(notificationSettings: notificationSettings)
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        DDLogInfo("Received Memory Warning!")
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
   
    func applicationWillTerminate(_ application: UIApplication) {
        let notif = UILocalNotification()
        notif.alertBody = "Hey, you quit Ride! That's cool, but if you want to pause it you can use the compass button in the app."
        UIApplication.shared.presentLocalNotificationNow(notif)
    }

    #if DEBUG    
    private func stubEndpoint(_ endpoint: String, filename: String) {
        let filePath = Bundle(for: type(of: self)).path(forResource: filename, ofType: "json")
        let fileData = NSData(contentsOfFile: filePath!)
        
        let jsonDict = try! JSONSerialization.jsonObject(with: fileData! as Data, options: JSONSerialization.ReadingOptions.allowFragments) as! NSDictionary
        
        MockingjayProtocol.addStub(matcher: uri("/api/v4/" + endpoint),
                                   builder: json(jsonDict["body"]!, status: (jsonDict["status-code"]! as! NSNumber).intValue, headers: jsonDict["headers"]! as? [String: String])
        )
    }
    #endif
}

