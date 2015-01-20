//
//  GettingStartedRatingViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedRatingViewController: UIViewController, PushSimulatorViewDelegate {
    
    @IBOutlet weak var pushSimulationView : PushSimulatorView!
    @IBOutlet weak var helperTextLabel : UILabel!
    
    override func viewDidLoad() {
        self.pushSimulationView.delegate = self
    }

    func didOpenControls(view: PushSimulatorView) {
        helperTextLabel.text = "Thumbs up for a good ride, thumbs down if something was wrong."
    }
    
    func didTapActionButton(view: PushSimulatorView) {
        self.pushSimulationView.fadeOut()
        helperTextLabel.text = "Sweet. Rating your Rides helps improve biking in Portland!"
    }
    
    func didTapDestructiveButton(view: PushSimulatorView) {
        self.pushSimulationView.fadeOut()
        helperTextLabel.text = "Aw =(. Rating your Rides helps improve biking in Portland!"
    }
}