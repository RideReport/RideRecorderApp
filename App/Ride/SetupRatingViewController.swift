//
//  SetupRatingViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SetupRatingViewController: SetupChildViewController, RideSummaryViewDelegate {
    
    weak var pushSimulationView : RideSummaryView!
    @IBOutlet weak var iPhoneContainerViewTopConstraint : NSLayoutConstraint!
    @IBOutlet weak var iPhoneContainerView : UIView!
    @IBOutlet weak var buttonContainerView : UIView!
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var notificationHelperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    
    var didFigureOutNotificationview: Bool = false
    
    override func viewDidLoad() {
        self.pushSimulationView.delegate = self
        self.pushSimulationView.appIcon = UIImage(named: "AppIcon40x40")
        
        self.buttonContainerView.hidden = true
        self.buttonContainerView.backgroundColor = pushSimulationView.contentView.backgroundColor
        self.buttonContainerView.layer.cornerRadius = pushSimulationView.contentView.layer.cornerRadius
        
        if #available(iOS 10.0, *) {
            pushSimulationView.showsActionButon = false
            pushSimulationView.showsDestructiveActionButon = false
            if self.traitCollection.forceTouchCapability == UIForceTouchCapability.Available {
                helperTextLabel.markdownStringValue = "At the end of your trip, you'll get a Ride Report notification. **Press it firmly** to rate your ride."
                pushSimulationView.showsEditButton = false
                pushSimulationView.allowsScrolling = false
                pushSimulationView.slideLabel.text = "Press for more"
                self.notificationHelperTextLabel.text = "firmly press this notification"
            } else {
                helperTextLabel.markdownStringValue = "At the end of your trip, you'll get a Ride Report notification. **Slide it left** to rate your ride."
                pushSimulationView.showsEditButton = true
                pushSimulationView.editTitle = "View"
            }
        } else {
            helperTextLabel.markdownStringValue = "At the end of your trip, you'll get a Ride Report notification. **Slide it left** to rate your ride."
        }
        
        self.notificationHelperTextLabel.hidden = true
        self.notificationHelperTextLabel.delay(4) {
            if !self.didFigureOutNotificationview {
                self.notificationHelperTextLabel.hidden = false
            }
        }
    }
    
    override func next(sender: AnyObject) {
        super.next(sender)
    }
    
    func didDeepTouchSummaryView(view: RideSummaryView) {
        self.didFigureOutNotificationview = true
        self.notificationHelperTextLabel.fadeOut()

        if #available(iOS 10.0, *) {
            showTripRichNotification()
        }
    }
    
    func didOpenControls(view: RideSummaryView) {
        self.didFigureOutNotificationview = true
        self.notificationHelperTextLabel.fadeOut()
        
        if #available(iOS 10.0, *) {
            helperTextLabel.animatedSetMarkdownStringValue("Ok, tap the **View** button.")
        } else {
            helperTextLabel.animatedSetMarkdownStringValue("If **any part** – even a little – of your trip stressed you out, tap **Not Great**.")
        }
    }
    
    @IBAction func tappedGreat(_ sender: AnyObject) {
        self.moveOutIphone()
        
        helperTextLabel.animatedSetMarkdownStringValue("Nice! **Your ratings help** other riders find good routes – and help your city fix the bad ones.")
    }
    
    @IBAction func tappedNotGreat(_ sender: AnyObject) {
        self.moveOutIphone()
        helperTextLabel.animatedSetMarkdownStringValue("Shucks =(. **Your ratings help** other riders find good routes – and help your city fix the bad ones.")    }
    
    func didTapEditButton(view: RideSummaryView) {
        showTripRichNotification()
    }
    
    private func showTripRichNotification() {
        self.buttonContainerView.popIn()
        helperTextLabel.animatedSetMarkdownStringValue("If **any part** – even a little – of your trip stressed you out, tap **Not Great**.")
    }
    
    func didTapActionButton(view: RideSummaryView) {
        self.tappedGreat(self)
    }
    
    func didTapDestructiveButton(view: RideSummaryView) {
        self.tappedNotGreat(self)
    }
    
    func moveOutIphone() {
        self.iPhoneContainerViewTopConstraint.constant += (self.view.frame.size.height/2.0)/self.iPhoneContainerViewTopConstraint.multiplier
        
        UIView.animateWithDuration(1,  animations: {
            self.view.layoutSubviews()
        }, completion: { (_) in
            self.nextButton.delay(0.5) {
                self.nextButton.fadeIn()
            }
        })
    }
}
