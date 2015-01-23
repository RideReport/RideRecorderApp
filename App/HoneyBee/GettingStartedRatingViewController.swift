//
//  GettingStartedRatingViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedRatingViewController: GettingStartedChildViewController, PushSimulatorViewDelegate {
    
    @IBOutlet weak var pushSimulationView : PushSimulatorView!
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    
    override func viewDidLoad() {
        self.pushSimulationView.delegate = self
        helperTextLabel.markdownStringValue = "Rides are reported straight to your lock screen. Just **slide left to rate the route**."
    }
    
    func didOpenControls(view: PushSimulatorView) {
        helperTextLabel.animatedSetMarkdownStringValue("**Thumbs up** for a good ride, **thumbs down** if something was wrong.")
    }
    
    func didTapActionButton(view: PushSimulatorView) {
        self.pushSimulationView.fadeOut {
            self.nextButton.fadeIn()
            
            // ew: http://stackoverflow.com/questions/24070544/suppressing-implicit-returns-in-swift
            return
        }
        helperTextLabel.animatedSetMarkdownStringValue("Sweet. Rating your Rides helps improve biking in Portland!")
    }
    
    func didTapDestructiveButton(view: PushSimulatorView) {
        self.pushSimulationView.fadeOut {
            self.nextButton.fadeIn()
            
            // ew: http://stackoverflow.com/questions/24070544/suppressing-implicit-returns-in-swift
            return
        }
        helperTextLabel.animatedSetMarkdownStringValue("Aw =(. Rating your Rides helps improve biking in Portland!")
    }
}