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
    }
    
    func setupViewControllersForGettingStarted() {
        let setupTermsVC = self.storyboard!.instantiateViewControllerWithIdentifier("setupTerms") as! SetupChildViewController
        self.setupVC(setupTermsVC)
        
        let setupBatteryVC = self.storyboard!.instantiateViewControllerWithIdentifier("setupBattery") as! SetupChildViewController
        self.setupVC(setupBatteryVC)
        
        let setupRatingVC = self.storyboard!.instantiateViewControllerWithIdentifier("setupRating") as! SetupChildViewController
        self.setupVC(setupRatingVC)
        
        let setupCreateProfile = self.storyboard!.instantiateViewControllerWithIdentifier("setupCreateProfile") as! SetupChildViewController
        self.setupVC(setupCreateProfile)
        
        let setupConfirmEmail = self.storyboard!.instantiateViewControllerWithIdentifier("setupConfirmEmail") as! SetupChildViewController
        self.setupVC(setupConfirmEmail)
        
        let setupFinished = self.storyboard!.instantiateViewControllerWithIdentifier("setupFinished") as! SetupChildViewController
        self.setupVC(setupFinished)
        
        self.myViewControllers = [setupTermsVC, setupRatingVC, setupBatteryVC, setupCreateProfile, setupConfirmEmail, setupFinished]
        
        self.myViewControllers.first!.childViewControllerWillPresent()
        
        self.setViewControllers([self.myViewControllers.first!], animated: false)
    }
    
    func setupViewControllersForCreateProfile() {
        let setupCreateProfile = self.storyboard!.instantiateViewControllerWithIdentifier("setupCreateProfile") as! SetupChildViewController
        self.setupVC(setupCreateProfile)
        
        let setupConfirmEmail = self.storyboard!.instantiateViewControllerWithIdentifier("setupConfirmEmail") as! SetupChildViewController
        self.setupVC(setupConfirmEmail)
        
        let setupFinished = self.storyboard!.instantiateViewControllerWithIdentifier("setupFinished") as! SetupChildViewController
        self.setupVC(setupFinished)
        
        self.myViewControllers = [setupCreateProfile, setupConfirmEmail, setupFinished]
        
        self.myViewControllers.first!.childViewControllerWillPresent(userInfo: ["isCreatingProfileOutsideGettingStarted": true])
        
        self.setViewControllers([self.myViewControllers.first!], animated: false)
    }
    
    private func setupVC(vc: SetupChildViewController) {
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
    
    func done(userInfo : [String: AnyObject]? = nil) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenSetup")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        let lastPage = self.myViewControllers.last!
        lastPage.childViewControllerWillPresent(userInfo: userInfo)

        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.view.layer.addAnimation(transition, forKey: nil)
        self.setViewControllers([lastPage], animated: false)        
    }
}