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

        helperTextLabel.markdownStringValue = "Ride is very light on your battery. Normal usage should consume **5% or less** of your battery."
        self.helperTextLabel.delay(3.0) {
            self.helperTextLabel.animatedSetMarkdownStringValue( "If you want pause Ride, tap on that **arrow button in the upper right**. Go ahead, give it a shot.") {
                self.pauseButton.delay(1.0) {
                    self.pauseButton.popIn()
                    return
                }
                return
            }
            return
        }
    }
    
    @IBAction func tappedPauseButton(sender: AnyObject) {
        helperTextLabel.animatedSetMarkdownStringValue("That's it. Ride won't log your rides or use any battery life when it is **paused**.")
        
        self.pauseButton.maskImage = UIImage(named: "locationArrowDisabled.png")
        self.pauseButton.primaryColor = UIColor.grayColor()
        self.pauseButton.secondaryColor = UIColor.grayColor()
        
        self.nextButton.delay(1.0) {
            self.nextButton.fadeIn()
            return
        }
    }
}