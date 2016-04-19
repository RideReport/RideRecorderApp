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
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var notificationHelperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    
    var didFigureOutNotificationview: Bool = false
    
    override func viewDidLoad() {
        self.pushSimulationView.delegate = self
        self.pushSimulationView.appIcon = UIImage(named: "AppIcon40x40")
        helperTextLabel.markdownStringValue = "You can help others find good routes by rating your trips, right from your lock screen. **Slide left to rate your ride.**"
        
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
    
    func didOpenControls(view: RideSummaryView) {
        self.didFigureOutNotificationview = true
        self.notificationHelperTextLabel.fadeOut()

        helperTextLabel.animatedSetMarkdownStringValue("Recommend a route with a **Thumbs up**, or tell others to avoid it with a **thumbs down**.")
    }
    
    func didTapActionButton(view: RideSummaryView) {
        self.moveOutIphone()

        helperTextLabel.animatedSetMarkdownStringValue("Nice! **Your ratings help** other riders find good routes – and help your city fix the bad ones.")
    }
    
    func didTapDestructiveButton(view: RideSummaryView) {
        self.moveOutIphone()
        helperTextLabel.animatedSetMarkdownStringValue("Shucks =(. **Your ratings help** other riders find good routes – and help your city fix the bad ones.")
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