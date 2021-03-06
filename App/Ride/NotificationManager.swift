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

enum NotificationManagerAuthorizationStatus: Int16 {
    case notDetermined = 0
    case authorized
    case authorizedAlertsDenied
    case denied
}

class NotificationManager : NSObject, UNUserNotificationCenterDelegate {
    static private(set) var shared : NotificationManager!
    static private(set) var lastAuthorizationStatus: NotificationManagerAuthorizationStatus = .notDetermined
    
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
            NotificationManager.lastAuthorizationStatus = NotificationManager.getAuthorizationForSettings(notificationSettings)
            handler(NotificationManager.lastAuthorizationStatus)
        }
    }
    
    static func updateAuthorizationStatus(handler: @escaping ()->Void) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                switch settings.authorizationStatus {
                case .notDetermined:
                    NotificationManager.lastAuthorizationStatus = .notDetermined
                case .authorized:
                    if settings.alertSetting == .enabled {
                        NotificationManager.lastAuthorizationStatus = .authorized
                    } else {
                        NotificationManager.lastAuthorizationStatus = .authorizedAlertsDenied
                    }
                case .denied:
                    NotificationManager.lastAuthorizationStatus = .denied
                default:
                    if #available(iOS 12.0, *) {
                        if settings.authorizationStatus == .provisional {
                            if settings.alertSetting == .enabled {
                                NotificationManager.lastAuthorizationStatus = .authorized
                            } else {
                                NotificationManager.lastAuthorizationStatus = .authorizedAlertsDenied
                            }
                        }
                    }
                }
                
                handler()
            }
        } else {
            if let settings = UIApplication.shared.currentUserNotificationSettings {
               NotificationManager.lastAuthorizationStatus = NotificationManager.getAuthorizationForSettings(settings)
            } else {
                NotificationManager.lastAuthorizationStatus = .notDetermined
            }
            handler()
        }
    }
    
    private static func getAuthorizationForSettings(_ notificationSettings: UIUserNotificationSettings)->NotificationManagerAuthorizationStatus {
        if notificationSettings.types.intersection(UIUserNotificationType.alert) == [] {
            return .authorizedAlertsDenied
        } else {
            return .authorized
        }
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
    
    func registerNotifications() {
        if #available(iOS 10.0, *) {
            var actions : [UNNotificationAction] = []

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
                    NotificationManager.updateAuthorizationStatus() {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                            UNUserNotificationCenter.current().setNotificationCategories(notificationCategories)
                            if let handler = self.pendingRegistrationHandler {
                                self.pendingRegistrationHandler = nil
                                handler(NotificationManager.lastAuthorizationStatus)
                            }
                        }
                    }
                }
            }
            UNUserNotificationCenter.current().delegate = self
        } else {
            var actions : [UIMutableUserNotificationAction] = []
            
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
                        NotificationManager.lastAuthorizationStatus = NotificationManager.getAuthorizationForSettings(settings)
                    } else {
                        NotificationManager.lastAuthorizationStatus = .notDetermined
                    }
                    handler(NotificationManager.lastAuthorizationStatus)
                }
            }
        }
    }

}
