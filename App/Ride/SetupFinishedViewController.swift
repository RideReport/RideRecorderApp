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
    
    override func childViewControllerWillPresent(userInfo: [String: AnyObject]? = nil) {
        super.childViewControllerWillPresent(userInfo)
        
        let _ = self.view.subviews // hack for a gross crash.
        
        if let finishType = userInfo?["finishType"] as! String? {
            if (finishType == "InitialSetupSkippedAccount") {
                Mixpanel.sharedInstance().track(
                    "finishedSetup",
                    properties: ["createdAccount": "false"]
                )
                
                self.helperTextLabel.markdownStringValue = "**You're all set!** You can create an account later if you change your mind."
            } else if (finishType == "InitialSetupCreatedAccount") {
                Mixpanel.sharedInstance().track(
                    "finishedSetup",
                    properties: ["createdAccount": "true"]
                )
                
                self.helperTextLabel.markdownStringValue = "**You're all set!**"
            } else if (finishType == "CreateAccountSkippedAccount") {
                self.helperTextLabel.markdownStringValue = "Cool. You can create an account later if you change your mind."
            } else if (finishType == "CreatedAccountCreatedAccount") {
                Mixpanel.sharedInstance().track(
                    "createdAccount"
                )
                
                self.helperTextLabel.markdownStringValue = "**You're all set!**"
            }
        } else {
            self.helperTextLabel.markdownStringValue = "**You're all set!**"
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(4 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            AppDelegate.appDelegate().transitionToMainNavController()
            return
        }
    }
}