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
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    
    override func viewDidLoad() {
        self.pushSimulationView.delegate = self
        self.pushSimulationView.appIcon = UIImage(named: "IconTiny")
        helperTextLabel.markdownStringValue = "When your ride ends, a report is delivered straight to your lock screen. **Slide left to rate your ride.**"
    }
    
    override func next(sender: AnyObject) {
        super.next(sender)
        AppDelegate.appDelegate().registerNotifications()
    }
    
    func didOpenControls(view: RideSummaryView) {
        helperTextLabel.animatedSetMarkdownStringValue("**Thumbs up** for a ride with no issues, **thumbs down** if something stressed you out.")
    }
    
    func didTapActionButton(view: RideSummaryView) {
        self.pushSimulationView.fadeOut {
            self.nextButton.fadeIn()
            
            // ew: http://stackoverflow.com/questions/24070544/suppressing-implicit-returns-in-swift
            return
        }
        helperTextLabel.animatedSetMarkdownStringValue("Nice. Rating your rides will **improve biking in Portland**!")
    }
    
    func didTapDestructiveButton(view: RideSummaryView) {
        self.pushSimulationView.fadeOut {
            self.nextButton.fadeIn()
            
            // ew: http://stackoverflow.com/questions/24070544/suppressing-implicit-returns-in-swift
            return
        }
        helperTextLabel.animatedSetMarkdownStringValue("Aw =(. Rating your rides will **improve biking in Portland**!")
    }
}