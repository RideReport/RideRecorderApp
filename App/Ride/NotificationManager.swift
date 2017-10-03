//
//  NotificationManager.swift
//  Ride
//
//  Created by William Henderson on 5/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UserNotifications

enum NotificationManagerAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
}

class NotificationManager : NSObject {
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
    
    func registerNotifications() {
        if #available(iOS 10.0, *) {
            var actions : [UNNotificationAction] = []
            
            for rating in Profile.profile().ratingVersion.availableRatings {
                let action = UNNotificationAction(identifier: rating.choice.notificationActionIdentifier, title: rating.emoji + " " + rating.noun, options: UNNotificationActionOptions(rawValue: 0))
                actions.append(action)
            }
            
            let rideCompleteCategory = UNNotificationCategory(identifier: "RIDE_COMPLETION_CATEGORY", actions: actions, intentIdentifiers: [], options: UNNotificationCategoryOptions(rawValue: 0))
            
            let rideStartedCategory = UNNotificationCategory(identifier: "RIDE_STARTED_CATEGORY", actions: [], intentIdentifiers: [], options: UNNotificationCategoryOptions(rawValue: 0))
            
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
            
            let rideStartedCategory = UIMutableUserNotificationCategory()
            rideStartedCategory.identifier = "RIDE_STARTED_CATEGORY"
            
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
