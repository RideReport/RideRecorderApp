//
//  NotificationViewController.swift
//  Ride Report Notification Content
//
//  Created by William Henderson on 8/31/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet var rideEmojiLabel: UILabel!
    @IBOutlet var rideDescriptionLabel: UILabel!
    @IBOutlet var rewardEmojiLabel: UILabel!
    @IBOutlet var rewardDescriptionLabel: UILabel!
    @IBOutlet var bottomSpaceConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        CoreDataManager.startup()
    }
    
    func didReceiveNotification(notification: UNNotification) {
        if let uuid = notification.request.content.userInfo["uuid"] as? String,
            let trip = Trip.tripWithUUID(uuid) {
            
            rideEmojiLabel.text = trip.climacon ?? ""
            rideDescriptionLabel.text = trip.displayStringWithTime()
            
            if let reward = trip.tripRewards.firstObject as? TripReward {
                rewardEmojiLabel.text = reward.displaySafeEmoji
                rewardDescriptionLabel.text = reward.descriptionText
                bottomSpaceConstraint?.constant = 14
            } else {
                rewardEmojiLabel.text = ""
                rewardDescriptionLabel.text = ""
                bottomSpaceConstraint?.constant = 0
            }
        } else {
            self.rideDescriptionLabel.text = notification.request.content.body
            rewardEmojiLabel.text = ""
            rewardDescriptionLabel.text = ""
            bottomSpaceConstraint?.constant = 0
        }
    }

}
