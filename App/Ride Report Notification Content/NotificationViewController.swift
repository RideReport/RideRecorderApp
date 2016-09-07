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
import SpriteKit


class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet var mapImageView: UIImageView!
    @IBOutlet var rideEmojiLabel: UILabel!
    @IBOutlet var rideDescriptionLabel: UILabel!
    @IBOutlet var rewardDescriptionLabel: UILabel!
    @IBOutlet var rewardEmojiLabel: UILabel!
    @IBOutlet var bottomSpaceConstraint: NSLayoutConstraint!
    
    var inUseSecurityScopedResource :NSURL? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    deinit {
        if let url = inUseSecurityScopedResource {
            // work around an issue where calling stopAccessingSecurityScopedResource too early can result in the image not being loaded
            // http://stackoverflow.com/questions/39063942/image-from-attachment-from-local-notification-is-not-shown-in-unnotificationcont
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    func didReceiveNotification(notification: UNNotification) {
        rideDescriptionLabel.preferredMaxLayoutWidth = rideDescriptionLabel.frame.size.width
        rewardDescriptionLabel.preferredMaxLayoutWidth = rewardDescriptionLabel.frame.size.width
        
        if let rideDescription = notification.request.content.userInfo["rideDescription"] as? String,
            let rideEmoji = notification.request.content.userInfo["rideEmoji"] as? String {
            
            rideEmojiLabel.text = rideEmoji ?? ""
            rideDescriptionLabel.text = rideDescription
            
            var hasMap = false
            
            if let attachment = notification.request.content.attachments.first {
                if attachment.URL.startAccessingSecurityScopedResource() {
                    mapImageView.image = UIImage(contentsOfFile: attachment.URL.path!)
                    inUseSecurityScopedResource = attachment.URL
                    hasMap = true
                }
            }
            
            if let rewardDescription = notification.request.content.userInfo["rewardDescription"] as? String,
                let rewardEmoji = notification.request.content.userInfo["rewardEmoji"] as? String {
                rewardDescriptionLabel.text = rewardDescription
                rewardDescriptionLabel.hidden = true
                rewardEmojiLabel.hidden = true
                rewardDescriptionLabel.sizeToFit()
                self.view.sparkle(ColorPallete.sharedPallete.notificationActionBlue, inRect: CGRectMake(rewardDescriptionLabel.frame.origin.x - 14 - rewardEmojiLabel.frame.size.width, rewardDescriptionLabel.frame.origin.y, rewardDescriptionLabel.frame.size.width + 28 + rewardEmojiLabel.frame.size.width, rewardDescriptionLabel.frame.size.height))
                rewardDescriptionLabel.fadeIn()
                rewardEmojiLabel.fadeIn()
                
                rewardEmojiLabel.text = rewardEmoji
                if (hasMap) {
                    self.preferredContentSize.height = mapImageView.frame.maxY
                } else {
                    mapImageView.removeConstraints(mapImageView.constraints)
                    self.preferredContentSize.height = mapImageView.frame.minY
                }
            } else {
                rewardDescriptionLabel.text = ""
                rewardEmojiLabel.text = ""
                
                if (hasMap) {
                    self.preferredContentSize.height = mapImageView.frame.maxY - (bottomSpaceConstraint?.constant ?? 0)
                } else {
                    mapImageView.removeConstraints(mapImageView.constraints)
                    self.preferredContentSize.height = mapImageView.frame.minY - (bottomSpaceConstraint?.constant ?? 0)
                }
                
                bottomSpaceConstraint?.constant = 0
            }
        } else {
            self.rideDescriptionLabel.text = notification.request.content.body
            rewardDescriptionLabel.text = ""
            rewardDescriptionLabel.text = ""
            rewardEmojiLabel.text = ""
            mapImageView.removeConstraints(mapImageView.constraints)
            self.preferredContentSize.height = mapImageView.frame.minY - (bottomSpaceConstraint?.constant ?? 0)
            bottomSpaceConstraint?.constant = 0
        }
    }
}
