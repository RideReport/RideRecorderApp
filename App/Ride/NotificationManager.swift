//
//  NotificationManager.swift
//  Ride
//
//  Created by William Henderson on 5/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class NotificationManager : NSObject {
    static private(set) var shared : NotificationManager!
    
    struct Static {
        static var onceToken : Int = 0
        static var sharedManager : NotificationManager?
    }
    
    class func startup() {
        if (NotificationManager.shared == nil) {
            NotificationManager.shared = NotificationManager()
            NotificationManager.shared.registerNotifications()
        }
    }
    
    override init () {
        super.init()
        
    }
    
    func registerNotifications() {
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
    }

}
