//
//  SetupPermissionsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SetupPermissionsViewController: SetupChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    
    override func viewDidLoad() {
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
        AppDelegate.appDelegate().startupDataGatheringManagers(false)
        self.next(self)
    }
}