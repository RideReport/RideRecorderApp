//
//  GettingStartedViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation


class GettingStartedViewController: UIPageViewController {
    
    override func viewDidLoad() {
        let vc0 = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedRating") as UIViewController
        
        self.setViewControllers([vc0], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
    }
    
    @IBAction func done(sender: AnyObject) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenGettingStarted")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}