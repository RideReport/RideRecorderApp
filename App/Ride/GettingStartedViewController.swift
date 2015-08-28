//
//  SetupViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SetupChildViewController : UIViewController {
    var parent : SetupViewController?
    
    @IBAction func next(sender: AnyObject) {
        self.parent?.nextPage(self)
    }
    
    func childViewControllerWillPresent(userInfo: [String: AnyObject]? = nil) {
        // override to receive
    }
}

class SetupViewController: UINavigationController {
    var myViewControllers : [SetupChildViewController]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationBarHidden = true
        self.navigationBar.tintColor = UIColor.whiteColor()
        self.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        let gettingStartedTermsVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedTerms") as! SetupChildViewController
        self.setupVC(gettingStartedTermsVC)
        
        let gettingStartedBatteryVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedBattery") as! SetupChildViewController
        self.setupVC(gettingStartedBatteryVC)
        
        let gettingStartedRatingVC = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedRating") as! SetupChildViewController
        self.setupVC(gettingStartedRatingVC)
        
        let gettingStartedCreateProfile = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedCreateProfile") as! SetupChildViewController
        self.setupVC(gettingStartedCreateProfile)
        
        let gettingStartedConfirmEmail = self.storyboard!.instantiateViewControllerWithIdentifier("gettingStartedConfirmEmail") as! SetupChildViewController
        self.setupVC(gettingStartedConfirmEmail)
        
        self.myViewControllers = [gettingStartedCreateProfile, gettingStartedConfirmEmail]
//        self.myViewControllers = [gettingStartedTermsVC, gettingStartedRatingVC, gettingStartedBatteryVC, gettingStartedCreateProfile, gettingStartedConfirmEmail]
        
        self.setViewControllers([self.myViewControllers.first!], animated: false)
    }
    
    func setupVC(vc: SetupChildViewController) {
        vc.view.backgroundColor = UIColor.clearColor()
        vc.parent = self
    }
    
    func nextPage(sender: AnyObject, userInfo : [String: AnyObject]? = nil) {
        let pageNumber = find(self.myViewControllers!, sender as! SetupChildViewController)
        
        if (pageNumber == nil || (pageNumber! + 1) >= self.myViewControllers.count) {
            self.done()
        } else {
            let nextPage = self.myViewControllers[pageNumber! + 1]
            nextPage.childViewControllerWillPresent(userInfo: userInfo)
            let transition = CATransition()
            transition.duration = 0.6
            transition.type = kCATransitionFade
            self.view.layer.addAnimation(transition, forKey: nil)
            self.setViewControllers([nextPage], animated: false)
        }
    }
    
    func previousPage(sender: AnyObject) {
        let pageNumber = find(self.myViewControllers!, sender as! SetupChildViewController)
        
        if (pageNumber == nil || (pageNumber! - 1) < 0) {
            // presumably we are already on the first page.
        } else {
            let prevPage = self.myViewControllers[pageNumber! - 1]
            let transition = CATransition()
            transition.duration = 0.6
            transition.type = kCATransitionFade
            self.view.layer.addAnimation(transition, forKey: nil)
            self.setViewControllers([prevPage], animated: false)
        }
    }
    
    func done() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenSetup")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        AppDelegate.appDelegate().transitionToMainNavController()
    }
}