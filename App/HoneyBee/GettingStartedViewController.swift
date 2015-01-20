//
//  GettingStartedViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedViewController: UIPageViewController {
    var gettingStartedRatingVC : UIViewController!
    var gettingStartedBatteryVC : UIViewController!
    
    override func viewDidLoad() {
        
        var blur = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        var effectView = UIVisualEffectView(effect: blur)
        effectView.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        self.view.addSubview(effectView)
        self.view.sendSubviewToBack(effectView)
        
        gettingStartedRatingVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedRating") as UIViewController
        gettingStartedRatingVC.view.backgroundColor = UIColor.clearColor()
        
        gettingStartedBatteryVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedBattery") as UIViewController
        gettingStartedBatteryVC.view.backgroundColor = UIColor.clearColor()
        
        self.setViewControllers([gettingStartedRatingVC], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
    }
    
    @IBAction func done(sender: AnyObject) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenGettingStarted")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}