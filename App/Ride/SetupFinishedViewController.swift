//
//  SetupFinishedViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Mixpanel

class SetupFinishedViewController: SetupChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    
    override func viewDidLoad() {
        self.helperTextLabel.markdownStringValue = "**You're ready to ride!**"
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(4 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            AppDelegate.appDelegate().transitionToMainNavController()
            return
        }
    }
}
