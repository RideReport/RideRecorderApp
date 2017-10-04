//
//  SetupRatingViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SetupRatingViewController: SetupChildViewController, RideNotificationViewDelegate {
    
    weak var pushSimulationView : RideNotificationView!
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
        
        self.buttonContainerView.isHidden = true
        self.buttonContainerView.backgroundColor = pushSimulationView.contentView.backgroundColor
        self.buttonContainerView.layer.cornerRadius = pushSimulationView.contentView.layer.cornerRadius
        
        if #available(iOS 10.0, *) {
            pushSimulationView.showsActionButon = false
            pushSimulationView.showsDestructiveActionButon = false
            if TARGET_OS_SIMULATOR == 0 && self.traitCollection.forceTouchCapability == UIForceTouchCapability.available {
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
        
        self.notificationHelperTextLabel.isHidden = true
        self.notificationHelperTextLabel.delay(4) {
            if !self.didFigureOutNotificationview {
                let opacityAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                opacityAnimation.duration = 1.0;
                opacityAnimation.fromValue = NSNumber(value: 0.0)
                opacityAnimation.toValue =   NSNumber(value: 1.0)
                opacityAnimation.autoreverses = true
                opacityAnimation.repeatCount = .greatestFiniteMagnitude
                
                self.pushSimulationView.layer.add(opacityAnimation, forKey: "shadowOpacity")

                self.pushSimulationView.layer.shadowOpacity = 1.0
                self.pushSimulationView.layer.shadowRadius = 10.0
                self.pushSimulationView.layer.shadowColor = ColorPallete.shared.brightBlue.cgColor
                self.pushSimulationView.layer.shadowOffset = CGSize(width: 0, height: 0);
                
                if #available(iOS 10.0, *) {
                    if self.traitCollection.forceTouchCapability == UIForceTouchCapability.available {
                        self.helperTextLabel.animatedSetMarkdownStringValue("Try **pressing firmly** on the notification down there on the pretend iPhone 👇")
                    } else {
                        self.helperTextLabel.animatedSetMarkdownStringValue("Try **sliding left** on the notification down there on the pretend iPhone 👇")
                    }
                } else {
                    self.helperTextLabel.animatedSetMarkdownStringValue("Try **sliding left** on the notification down there on the pretend iPhone 👇")
                }
                self.notificationHelperTextLabel.isHidden = false
            }
        }
    }
    
    override func next(_ sender: AnyObject) {
        super.next(sender)
    }
    
    func didDeepTouchSummaryView(_ view: RideNotificationView) {
        self.didFigureOutNotificationview = true
        self.notificationHelperTextLabel.fadeOut()
        
        self.pushSimulationView.layer.removeAllAnimations()
        let opacityAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        opacityAnimation.duration = 0.8;
        opacityAnimation.fromValue = NSNumber(value: 1.0 as Float)
        opacityAnimation.toValue =   NSNumber(value: 0.0 as Float)
        
        self.pushSimulationView.layer.add(opacityAnimation, forKey: "shadowOpacity")
        self.pushSimulationView.layer.shadowOpacity = 0.0

        if #available(iOS 10.0, *) {
            showTripRichNotification()
        }
    }
    
    func didOpenControls(_ view: RideNotificationView) {
        self.didFigureOutNotificationview = true
        self.notificationHelperTextLabel.fadeOut()
        self.pushSimulationView.layer.removeAllAnimations()
        let opacityAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        opacityAnimation.duration = 0.8;
        opacityAnimation.fromValue = NSNumber(value: 1.0 as Float)
        opacityAnimation.toValue =   NSNumber(value: 0.0 as Float)
        
        self.pushSimulationView.layer.add(opacityAnimation, forKey: "shadowOpacity")
        self.pushSimulationView.layer.shadowOpacity = 0.0
        
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
    
    @IBAction func tappedMixed(_ sender: AnyObject) {
        self.moveOutIphone()
        helperTextLabel.animatedSetMarkdownStringValue("Oh well =/. **Your ratings help** other riders find good routes – and help your city fix the bad ones.")
    }
    
    @IBAction func tappedNotGreat(_ sender: AnyObject) {
        self.moveOutIphone()
        helperTextLabel.animatedSetMarkdownStringValue("Shucks =(. **Your ratings help** other riders find good routes – and help your city fix the bad ones.")
    }
    
    func didTapEditButton(_ view: RideNotificationView) {
        showTripRichNotification()
    }
    
    private func showTripRichNotification() {
        self.buttonContainerView.popIn()
        helperTextLabel.animatedSetMarkdownStringValue("If **any part** – even a little – of your trip stressed you out, tap **Not Great**.")
    }
    
    func didTapActionButton(_ view: RideNotificationView) {
        self.tappedGreat(self)
    }
    
    func didTapDestructiveButton(_ view: RideNotificationView) {
        self.tappedNotGreat(self)
    }
    
    func moveOutIphone() {
        self.iPhoneContainerViewTopConstraint.constant += (self.view.frame.size.height/2.0)/self.iPhoneContainerViewTopConstraint.multiplier
        
        UIView.animate(withDuration: 1,  animations: {
            self.view.layoutSubviews()
        }, completion: { (_) in
            self.nextButton.delay(0.5) {
                self.nextButton.fadeIn()
            }
        })
    }
}
