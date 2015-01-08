//
//  GettingStartedViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation


class GettingStartedViewController: UIViewController {
    
    @IBAction func done(sender: AnyObject) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenGettingStarted")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}