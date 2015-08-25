//
//  GettingStartedViewController.swift
//  Ride Report
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

class GettingStartedViewController: UINavigationController {
    var myViewControllers : [GettingStartedChildViewController]!
    
    override func viewDidLoad() {
        
        self.navigationBarHidden = true
        
        let gettingStartedTermsVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedTerms") as! GettingStartedChildViewController
        self.setupVC(gettingStartedTermsVC)
        
        let gettingStartedBatteryVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedBattery") as! GettingStartedChildViewController
        self.setupVC(gettingStartedBatteryVC)
        
        let gettingStartedRatingVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedRating") as! GettingStartedChildViewController
        self.setupVC(gettingStartedRatingVC)
        
        let gettingStartedCreateProfile = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedCreateProfile") as! GettingStartedChildViewController
        self.setupVC(gettingStartedCreateProfile)
        
        let gettingStartedConfirmEmail = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedConfirmEmail") as! GettingStartedChildViewController
        self.setupVC(gettingStartedConfirmEmail)
        
        self.myViewControllers = [gettingStartedConfirmEmail]
//        self.myViewControllers = [gettingStartedTermsVC, gettingStartedRatingVC, gettingStartedBatteryVC, gettingStartedCreateProfile]
        
        self.setViewControllers([self.myViewControllers.first!], animated: false)
    }
    
    func setupVC(vc: GettingStartedChildViewController) {
        vc.view.backgroundColor = UIColor.clearColor()
        vc.parent = self
    }
    
    func nextPage() {
        let pageNumber = find(self.myViewControllers!, self.viewControllers.first as! GettingStartedChildViewController)
        
        if (pageNumber == nil || (pageNumber! + 1) >= self.myViewControllers.count) {
            self.done()
        } else {
            let thisPage = self.myViewControllers[pageNumber!] as UIViewController
            let nextPage = self.myViewControllers[pageNumber! + 1]
            let transition = CATransition()
            transition.duration = 0.6
            transition.type = kCATransitionFade
            self.view.layer.addAnimation(transition, forKey: nil)
            self.setViewControllers([nextPage], animated: false)
        }
    }
    
    func done() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenGettingStartedv2")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        AppDelegate.appDelegate().transitionToMainNavController()
    }
}