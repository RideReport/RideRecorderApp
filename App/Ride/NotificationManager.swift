//
//  NotificationManager.swift
//  Ride
//
//  Created by William Henderson on 5/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UserNotifications
import CocoaLumberjack
import RouteRecorder

enum NotificationManagerAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
}

class NotificationManager : NSObject, UNUserNotificationCenterDelegate {
    static private(set) var shared : NotificationManager!
    private var pendingRegistrationHandler: ((NotificationManagerAuthorizationStatus)->Void)? = nil
    
    struct Static {
        static var onceToken : Int = 0
        static var sharedManager : NotificationManager?
    }
    
    class func startup(handler: @escaping (NotificationManagerAuthorizationStatus)->Void = {(_) in }) {
        if (NotificationManager.shared == nil) {
            NotificationManager.shared = NotificationManager()
            NotificationManager.shared.pendingRegistrationHandler = handler
            NotificationManager.shared.registerNotifications()
        }
    }
    
    override init () {
        super.init()
    }
    
    public func didRegisterForNotifications(notificationSettings: UIUserNotificationSettings) {
        if let handler = self.pendingRegistrationHandler {
            self.pendingRegistrationHandler = nil
            let auth = NotificationManager.getAuthorizationForSettings(notificationSettings)
            handler(auth)
        }
    }
    
    static func checkAuthorized(handler: @escaping (NotificationManagerAuthorizationStatus)->Void) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                switch settings.authorizationStatus {
                case .notDetermined:
                    handler(.notDetermined)
                case .authorized:
                    handler(.authorized)
                case .denied:
                    handler(.denied)
                }
            }
        } else {
            if let settings = UIApplication.shared.currentUserNotificationSettings {
               handler(NotificationManager.getAuthorizationForSettings(settings))
            } else {
                handler(.notDetermined)
            }
        }
    }
    
    private static func getAuthorizationForSettings(_ notificationSettings: UIUserNotificationSettings)->NotificationManagerAuthorizationStatus {
        if notificationSettings.types.intersection(UIUserNotificationType.alert) == [] {
            return .denied
        } else {
            return .authorized
        }
    }
    
    public func didReceiveNotification(userInfo: [AnyHashable: Any]) {
        if let syncTrips = userInfo["syncTrips"] as? Bool, syncTrips {
            DDLogInfo("Received sync trips notification in foreground")
            if UIDevice.current.batteryState == UIDeviceBatteryState.charging || UIDevice.current.batteryState == UIDeviceBatteryState.full {
                // if the user is plugged in, go ahead and sync all unsynced trips.
                RouteRecorder.shared.uploadRoutes(includeFullLocations: true)
            }
        } else if let tripUpdatesAvailable = userInfo["tripUpdatesAvailable"] as? Bool, tripUpdatesAvailable {
            RideReportAPIClient.shared.syncTrips()
        } else if let encouragementDictionaries = userInfo["encouragements"] as? [AnyObject] {
            Profile.profile().updateEncouragements(encouragementDictionaries: encouragementDictionaries)
            CoreDataManager.shared.saveContext()
        } else if let uuid = userInfo["uuid"] as? String,
            let trip = Trip.tripWithUUID(uuid) {
            
            DDLogInfo(String(format: "Received trip summary notification, uuid: %@", uuid))
            
            trip.loadSummaryFromAPNDictionary(userInfo)
            CoreDataManager.shared.saveContext()
            
            if let encouragementDictionaries = userInfo["encouragements"] as? [AnyObject] {
                Profile.profile().updateEncouragements(encouragementDictionaries: encouragementDictionaries)
                CoreDataManager.shared.saveContext()
            }
        }
    }
    
    @available(iOS 10.0, *)
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        self.didReceiveNotification(userInfo: notification.request.content.userInfo)
    }
    
    @available(iOS 10.0, *)
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let trip = Trip.tripWithUUID(response.notification.request.identifier) {
                AppDelegate.appDelegate().transitionToTripView(trip: trip)
            }
            completionHandler()
        } else {
            self.handleNotificationAction(response.actionIdentifier, userInfo: response.notification.request.content.userInfo, completionHandler: completionHandler)
        }
    }
    
    public func handleNotificationAction(_ identifier: String?, userInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
        if let uuid = userInfo["uuid"] as? String,
            let trip = Trip.tripWithUUID(uuid) {
            DDLogInfo(String(format: "Received trip rating notification action"))
            
            for rating in Profile.profile().ratingVersion.availableRatings {
                if identifier == rating.choice.notificationActionIdentifier {
                    let notif = self.postTripRatedThanksNotification(ratingChoice: rating.choice)
                    
                    DDLogInfo("Beginning post trip rating background task!")
                    var backgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
                    backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                        DDLogInfo("Post trip notification background task expired!")
                        UIApplication.shared.cancelLocalNotification(notif)
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = UIBackgroundTaskInvalid
                    })
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                        UIApplication.shared.cancelLocalNotification(notif)
                    })
                    
                    trip.rating = rating
                    
                    RideReportAPIClient.shared.saveAndPatchTripIfNeeded(trip).apiResponse({ (_) -> Void in
                        if (backgroundTaskID != UIBackgroundTaskInvalid) {
                            DDLogInfo("Ending post trip rating background task!")
                            
                            UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        }
                        
                        completionHandler()
                    })
                    return
                }
            }
            if identifier == "END_RIDE_IDENTIFIER" {
                RouteRecorder.shared.routeManager.stopRoute()
            }
            
            completionHandler()
        } else if (identifier == "RESUME_IDENTIFIER") {
            RouteRecorder.shared.routeManager.resumeTracking()
            completionHandler()
        } else {
            completionHandler()
        }
    }
    
    func postTripRatedThanksNotification(ratingChoice: RatingChoice)->UILocalNotification {
        var emojicuteness : [Character] = []
        var thanksPhrases : [String] = []
        
        if (ratingChoice == .good) {
            emojicuteness = Array("🐯🍄🐎🙌🐵🐌🌠🍌🍕🍳🍯🍻🎀🎃📈🎄👑💙⛄️💃🎩🏆".characters)
            thanksPhrases = ["Thanks!", "Sweet!", "YES!", "kewlll", "w00t =)", "yaay（＾_＾)", "Nice.", "Spleenndid"]
        } else if (ratingChoice == .mixed){
            emojicuteness = Array("🤔😬😶🤖🎲📊🗿🥉🌦🎭🃏".characters)
            thanksPhrases = ["hmmm", "welp.", "interesting =/", "riiiiight", "k", "aight.", "gotcha.", "(・_・)ヾ"]
        } else if (ratingChoice == .bad) {
            emojicuteness = Array("😓😔😿💩😤🐷🍆💔🚽📌🚸🚳📉😭".characters)
            thanksPhrases = ["Maww =(", "d'oh!", "sad panda (´･︹ ･` )", "Shucks.", "oh well =(", "drats", "dag =/"]
        }
        
        let thanksPhrase = thanksPhrases[Int(arc4random_uniform(UInt32(thanksPhrases.count)))]
        let emoji1 = String(emojicuteness[Int(arc4random_uniform(UInt32(emojicuteness.count)))])
        let emoji2 = String(emojicuteness[Int(arc4random_uniform(UInt32(emojicuteness.count)))])
        
        let notif = UILocalNotification()
        notif.alertBody = emoji1 + thanksPhrase + emoji2
        UIApplication.shared.presentLocalNotificationNow(notif)
        
        return notif
    }
    
    func registerNotifications() {
        if #available(iOS 10.0, *) {
            var actions : [UNNotificationAction] = []
            
            for rating in Profile.profile().ratingVersion.availableRatings {
                let action = UNNotificationAction(identifier: rating.choice.notificationActionIdentifier, title: rating.emoji + " " + rating.noun, options: UNNotificationActionOptions(rawValue: 0))
                actions.append(action)
            }
            
            let rideCompleteCategory = UNNotificationCategory(identifier: "RIDE_COMPLETION_CATEGORY", actions: actions, intentIdentifiers: [], options: UNNotificationCategoryOptions(rawValue: 0))
            
            let rideStartedAction = UNNotificationAction(identifier: "END_RIDE_IDENTIFIER", title:  "End Ride", options: UNNotificationActionOptions.destructive)
            let rideStartedCategory = UNNotificationCategory(identifier: "RIDE_STARTED_CATEGORY", actions: [rideStartedAction], intentIdentifiers: [], options: UNNotificationCategoryOptions(rawValue: 0))
            
            #if DEBUG
                let debugCategory = UNNotificationCategory(identifier: "DEBUG_CATEGORY", actions: [], intentIdentifiers: [], options: UNNotificationCategoryOptions(rawValue: 0))
            #endif
            
            let resumeAction = UNNotificationAction(identifier: "RESUME_IDENTIFIER", title: "Resume", options: UNNotificationActionOptions(rawValue: 0))
            
            let appPausedCategory = UNNotificationCategory(identifier: "APP_PAUSED_CATEGORY", actions: [resumeAction], intentIdentifiers: [], options: UNNotificationCategoryOptions(rawValue: 0))
            
            var notificationCategories = Set([rideCompleteCategory, rideStartedCategory, appPausedCategory])
            #if DEBUG
                notificationCategories.insert(debugCategory)
            #endif

            UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    UNUserNotificationCenter.current().setNotificationCategories(notificationCategories)
                    if let handler = self.pendingRegistrationHandler {
                        self.pendingRegistrationHandler = nil
                        handler(granted ? .authorized : .denied)
                    }
                }
            }
            UNUserNotificationCenter.current().delegate = self
        } else {
            var actions : [UIMutableUserNotificationAction] = []
            
            for rating in Profile.profile().ratingVersion.availableRatings {
                let action = UIMutableUserNotificationAction()
                action.identifier = rating.choice.notificationActionIdentifier
                action.title = rating.emoji + " " + rating.noun
                action.activationMode = UIUserNotificationActivationMode.background
                action.isDestructive = false
                action.isAuthenticationRequired = false
                actions.append(action)
            }
            
            let rideCompleteCategory = UIMutableUserNotificationCategory()
            rideCompleteCategory.identifier = "RIDE_COMPLETION_CATEGORY"
            rideCompleteCategory.setActions(actions, for: UIUserNotificationActionContext.minimal)
            rideCompleteCategory.setActions(actions, for: UIUserNotificationActionContext.default)
            
            let rideStartedAction = UIMutableUserNotificationAction()
            rideStartedAction.identifier = "END_RIDE_IDENTIFIER"
            rideStartedAction.title = "End Ride"
            rideStartedAction.activationMode = UIUserNotificationActivationMode.background
            rideStartedAction.isDestructive = true
            rideStartedAction.isAuthenticationRequired = false
            let rideStartedCategory = UIMutableUserNotificationCategory()
            rideStartedCategory.identifier = "RIDE_STARTED_CATEGORY"
            rideCompleteCategory.setActions([rideStartedAction], for: UIUserNotificationActionContext.minimal)
            rideCompleteCategory.setActions([rideStartedAction], for: UIUserNotificationActionContext.default)
            
            #if DEBUG
                let debugCategory = UIMutableUserNotificationCategory()
                debugCategory.identifier = "DEBUG_CATEGORY"
            #endif
            
            let resumeAction = UIMutableUserNotificationAction()
            resumeAction.identifier = "RESUME_IDENTIFIER"
            resumeAction.title = "Resume"
            resumeAction.activationMode = UIUserNotificationActivationMode.background
            resumeAction.isDestructive = false
            resumeAction.isAuthenticationRequired = false
            
            let appPausedCategory = UIMutableUserNotificationCategory()
            appPausedCategory.identifier = "APP_PAUSED_CATEGORY"
            appPausedCategory.setActions([resumeAction], for: UIUserNotificationActionContext.minimal)
            appPausedCategory.setActions([resumeAction], for: UIUserNotificationActionContext.default)
            
            var notificationCategories : Set<UIUserNotificationCategory> = Set([rideCompleteCategory, rideStartedCategory, appPausedCategory])
            #if DEBUG
                notificationCategories.insert(debugCategory)
            #endif
            
            let types: UIUserNotificationType = [UIUserNotificationType.badge, UIUserNotificationType.sound, UIUserNotificationType.alert]

            let settings = UIUserNotificationSettings(types: types, categories: notificationCategories)
            UIApplication.shared.registerUserNotificationSettings(settings)
            UIApplication.shared.registerForRemoteNotifications()
            
            // schedule a time out, just in case we dont get a callback
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if let handler = self.pendingRegistrationHandler {
                    self.pendingRegistrationHandler = nil
                    if let settings = UIApplication.shared.currentUserNotificationSettings {
                        handler(NotificationManager.getAuthorizationForSettings(settings))
                    } else {
                        handler(.notDetermined)
                    }
                }
            }
        }
    }

}
