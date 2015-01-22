//
//  GettingStartedFinishedViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedFinishedViewController: GettingStartedChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    
    
    override func viewDidLoad() {
        helperTextLabel.markdownStringValue = "That's it! Hop on your bike and **Ride will take care of the rest**."
    }
}