//
//  GettingStartedFinishedViewController.swift
//  Ride
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedFinishedViewController: GettingStartedChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    
    
    override func viewDidLoad() {
        helperTextLabel.markdownStringValue = "That's it! **Ride will start automatically** when you get on your bike."
    }
}