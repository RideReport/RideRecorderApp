//
//  GettingStartedViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedChildViewController : UIViewController {
    var parent : GettingStartedViewController?
    
    @IBAction func next(sender: AnyObject) {
        self.parent?.nextPage()
    }
}

class GettingStartedViewController: UIPageViewController {
    var myViewControllers : [GettingStartedChildViewController]!
    
    override func viewDidLoad() {
        
        var blur = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        var effectView = UIVisualEffectView(effect: blur)
        effectView.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        self.view.addSubview(effectView)
        self.view.sendSubviewToBack(effectView)
        
        let gettingStartedRatingVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedRating") as GettingStartedChildViewController
        gettingStartedRatingVC.parent = self
        gettingStartedRatingVC.view.backgroundColor = UIColor.clearColor()
        
        let gettingStartedBatteryVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedBattery") as GettingStartedChildViewController
        gettingStartedBatteryVC.parent = self
        gettingStartedBatteryVC.view.backgroundColor = UIColor.clearColor()
        
        self.myViewControllers = [gettingStartedBatteryVC, gettingStartedRatingVC]
        
        self.setViewControllers([self.myViewControllers.first!], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
    }
    
    func nextPage() {
        let pageNumber = find(self.myViewControllers!, self.viewControllers.first as GettingStartedChildViewController)
        
        if (pageNumber == nil || pageNumber >= self.myViewControllers.count) {
            self.done()
        } else {
            let nextPage = self.myViewControllers[pageNumber! + 1]
            self.setViewControllers([nextPage], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
        }
    }
    
    func done() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenGettingStarted")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}