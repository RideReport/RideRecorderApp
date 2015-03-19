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
        helperTextLabel.markdownStringValue = "**You're all set**! Go get on your bike and Ride will take care of the rest."
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(8 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.parent?.nextPage()
            return
        }
    }
}