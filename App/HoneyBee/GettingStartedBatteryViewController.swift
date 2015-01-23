//
//  GettingStartedBatteryViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedBatteryViewController: GettingStartedChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    var hasTappedPause : Bool = false
    @IBOutlet weak var pauseButton: HBAnimatedGradientMaskButton!
    
    override func viewDidLoad() {
        self.pauseButton.backgroundColor = UIColor.clearColor()
        self.pauseButton.maskImage = UIImage(named: "locationArrow.png")
        self.pauseButton.primaryColor = UIColor(red: 112/255, green: 234/255, blue: 156/255, alpha: 1.0)
        self.pauseButton.secondaryColor = UIColor(red: 116.0/255, green: 187.0/255, blue: 240.0/255, alpha: 1.0)

        self.helperTextLabel.markdownStringValue = "Want to pause Ride? Tap that **arrow button in the upper right**."
    }
    
    override func viewDidAppear(animated: Bool) {
        self.pauseButton.delay(1.0) {
            self.pauseButton.popIn()
            self.pauseButton.delay(5.0) {
                // give the user 5 seconds to tap it themselves, then just do it
                self.tappedPauseButton(self)
                return
            }
            return
        }
    }
    
    @IBAction func tappedPauseButton(sender: AnyObject) {
        if (self.hasTappedPause) {
            return
        }
        
        self.hasTappedPause = true
        helperTextLabel.animatedSetMarkdownStringValue("On a typical day, Ride uses **less than 6%** of your battery. When paused, Ride uses **no battery life**.")
        
        self.pauseButton.maskImage = UIImage(named: "locationArrowDisabled.png")
        self.pauseButton.primaryColor = UIColor.grayColor()
        self.pauseButton.secondaryColor = UIColor.grayColor()
        self.pauseButton.animates = false
        
        self.nextButton.delay(1.0) {
            self.nextButton.fadeIn()
            return
        }
    }
}