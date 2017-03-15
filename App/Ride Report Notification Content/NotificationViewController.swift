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
    @IBOutlet var mapImageHeightConstraint: NSLayoutConstraint!
    
    var inUseSecurityScopedResource :URL? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapImageView.removeConstraint(mapImageHeightConstraint)
        mapImageHeightConstraint = NSLayoutConstraint(item: self.mapImageView, attribute: .height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant:UIScreen.main.bounds.height - 370) // hard coded because notification content is super crazy about autolayout
        self.mapImageView.addConstraint(mapImageHeightConstraint)
        mapImageHeightConstraint.isActive = true

        self.mapImageView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    deinit {
        if let url = inUseSecurityScopedResource {
            // work around an issue where calling stopAccessingSecurityScopedResource too early can result in the image not being loaded
            // http://stackoverflow.com/questions/39063942/image-from-attachment-from-local-notification-is-not-shown-in-unnotificationcont
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    func didReceive(_ notification: UNNotification) {
        rideDescriptionLabel.preferredMaxLayoutWidth = rideDescriptionLabel.frame.size.width
        rewardDescriptionLabel.preferredMaxLayoutWidth = rewardDescriptionLabel.frame.size.width
        
        if let rideDescription = notification.request.content.userInfo["rideDescription"] as? String,
            let rideEmoji = notification.request.content.userInfo["rideEmoji"] as? String {
            
            rideEmojiLabel.text = rideEmoji ?? ""
            rideDescriptionLabel.text = rideDescription
            
            var hasMap = false
            
            if let attachment = notification.request.content.attachments.first {
                if attachment.url.startAccessingSecurityScopedResource(),
                let mapImage = UIImage(contentsOfFile: attachment.url.path) {
                    mapImageView.image = mapImage
                    inUseSecurityScopedResource = attachment.url
                    hasMap = true
                }
            }
            
            if let rewardDescription = notification.request.content.userInfo["rewardDescription"] as? String,
                let rewardEmoji = notification.request.content.userInfo["rewardEmoji"] as? String {
                rewardDescriptionLabel.text = rewardDescription
                rewardDescriptionLabel.isHidden = true
                rewardEmojiLabel.isHidden = true
                rewardDescriptionLabel.sizeToFit()
                self.view.sparkle(ColorPallete.sharedPallete.notificationActionBlue, inRect: CGRect(x: rewardDescriptionLabel.frame.origin.x - 14 - rewardEmojiLabel.frame.size.width, y: rewardDescriptionLabel.frame.origin.y, width: rewardDescriptionLabel.frame.size.width + 28 + rewardEmojiLabel.frame.size.width, height: rewardDescriptionLabel.frame.size.height))
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
