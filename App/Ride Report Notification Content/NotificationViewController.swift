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
    @IBOutlet weak var rideSummaryView: RideSummaryView!
    @IBOutlet var mapImageView: UIImageView!
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
        if let rideDescription = notification.request.content.userInfo["rideDescription"] as? String,
            let rideLength = notification.request.content.userInfo["rideLength"] as? Float,
            let rewardDicts = notification.request.content.userInfo["rewards"] as? [[String: Any]] {
            
            var hasMap = false
            
            if let attachment = notification.request.content.attachments.first {
                if attachment.url.startAccessingSecurityScopedResource(),
                let mapImage = UIImage(contentsOfFile: attachment.url.path) {
                    mapImageView.image = mapImage
                    inUseSecurityScopedResource = attachment.url
                    hasMap = true
                }
            }
            rideSummaryView.setTripSummary(tripLength: rideLength, description: rideDescription)
            rideSummaryView.setRewards(rewardDicts, animated: true)
            
            // force an update
            rideSummaryView.updateConstraints()
            rideSummaryView.layoutIfNeeded()
            self.view.layoutIfNeeded()
            
            if (hasMap) {
                self.preferredContentSize.height = mapImageView.frame.maxY
            } else {
                self.mapImageView.removeConstraint(mapImageHeightConstraint)
                self.preferredContentSize.height = mapImageView.frame.minY
            }
        } else {
            self.mapImageView.removeConstraint(mapImageHeightConstraint)
            self.preferredContentSize.height = mapImageView.frame.minY
        }
    }
}
