//
//  SetupFinishedViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SetupFinishedViewController: SetupChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    

    
    override func childViewControllerWillPresent(userInfo: [String: AnyObject]? = nil) {
        super.childViewControllerWillPresent(userInfo: userInfo)
        
        if let finishType = userInfo?["finishType"] as! String? {
            if (finishType == "InitialSetupSkippedAccount") {
                helperTextLabel.markdownStringValue = "**You're all set**! Go get on your bike and Ride Report will take care of the rest."
            } else if (finishType == "InitialSetupCreatedAccount") {
                helperTextLabel.markdownStringValue = "**You're all set**! Go get on your bike and Ride Report will take care of the rest."
            } else if (finishType == "CreateAccountSkippedAccount") {
                helperTextLabel.markdownStringValue = "**You're all set**!"
            } else if (finishType == "CreatedAccountCreatedAccount") {
                helperTextLabel.markdownStringValue = "Cool. You can always create an account later if you'd like to."
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(6 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            AppDelegate.appDelegate().transitionToMainNavController()
            return
        }
    }
}