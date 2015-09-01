//
//  SetupBatteryViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SetupBatteryViewController: SetupChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    @IBOutlet weak var pauseButton: HBAnimatedGradientMaskButton!
    
    override func viewDidLoad() {
        self.pauseButton.backgroundColor = UIColor.clearColor()
        self.pauseButton.maskImage = UIImage(named: "locationArrowDisabled.png")
        self.pauseButton.primaryColor = UIColor.grayColor()
        self.pauseButton.secondaryColor = UIColor.grayColor()
        self.pauseButton.animates = false

        self.helperTextLabel.markdownStringValue = "Ride Report uses your location and motion data in the background, but don't worry – it won't drain your battery."
    }
    
    override func viewDidAppear(animated: Bool) {
        self.nextButton.delay(1.0) {
            self.nextButton.fadeIn()
            return
        }
        
        super.viewDidAppear(animated)
    }
    
    @IBAction func tappedButton(sender: AnyObject) {
        AppDelegate.appDelegate().startupDataGatheringManagers()
        
        self.nextButton.fadeOut()
        
        helperTextLabel.animatedSetMarkdownStringValue("If you want to stop reporting trips for a while, tap that **arrow thing in the upper right**.")
        
        self.pauseButton.delay(1.0) {
            self.pauseButton.popIn()
            self.pauseButton.delay(10.0) {
                self.next(self)
                return
            }
            return
        }
        
    }
    
    @IBAction func tappedArrowButton(sender: AnyObject) {
        self.helperTextLabel.animatedSetMarkdownStringValue("Yeah, you got it.")
        self.pauseButton.maskImage = UIImage(named: "locationArrow.png")
        self.pauseButton.primaryColor = UIColor(red: 112/255, green: 234/255, blue: 156/255, alpha: 1.0)
        self.pauseButton.secondaryColor = UIColor(red: 116.0/255, green: 187.0/255, blue: 240.0/255, alpha: 1.0)
        self.pauseButton.animates = true
        
        self.pauseButton.delay(3.0) {
            self.next(self)
        }
    }
}