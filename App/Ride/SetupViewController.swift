//
//  SetupViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import WatchConnectivity

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
    private var hasAddedWatchkitToSetup = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationBarHidden = true
    }
    
    func setupViewControllersForGettingStarted() {
        let setupTermsVC = self.storyboard!.instantiateViewControllerWithIdentifier("setupTerms") as! SetupChildViewController
        self.setupVC(setupTermsVC)
        
        let setupRatingVC = self.storyboard!.instantiateViewControllerWithIdentifier("setupRating") as! SetupChildViewController
        self.setupVC(setupRatingVC)
        
        let setupFinished = self.storyboard!.instantiateViewControllerWithIdentifier("setupFinished") as! SetupChildViewController
        self.setupVC(setupFinished)
        
        self.myViewControllers = [setupTermsVC, setupRatingVC]
        
        if (!NSUserDefaults.standardUserDefaults().boolForKey("hasSeenSetup")) {
            // if they haven't seen setup, ask for permissions
            let setupPermissionVC = self.storyboard!.instantiateViewControllerWithIdentifier("setupPermissions") as! SetupChildViewController
            self.setupVC(setupPermissionVC)
            self.myViewControllers.append(setupPermissionVC)
        }
        
        if (APIClient.sharedClient.accountVerificationStatus != .Verified) {
            let setupCreateProfile = self.storyboard!.instantiateViewControllerWithIdentifier("setupCreateProfile") as! SetupChildViewController
            self.setupVC(setupCreateProfile)
            
            let setupConfirmEmail = self.storyboard!.instantiateViewControllerWithIdentifier("setupConfirmEmail") as! SetupChildViewController
            self.setupVC(setupConfirmEmail)

            self.myViewControllers.appendContentsOf([setupCreateProfile, setupConfirmEmail])
        }
        
        self.myViewControllers.append(setupFinished)
        
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
        
        self.myViewControllers.first!.childViewControllerWillPresent()
        
        self.setViewControllers([self.myViewControllers.first!], animated: false)
    }
    
    private func setupVC(vc: SetupChildViewController) {
        vc.parent = self
    }
    
    func nextPage(sender: AnyObject, userInfo : [String: AnyObject]? = nil, skipNext: Bool = false) {
        if (!hasAddedWatchkitToSetup) {
            // defer this to allow the session to activate.
            hasAddedWatchkitToSetup = true
            if #available(iOS 10.0, *) {
                if (WatchManager.sharedManager.paired && !NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup")) {
                    // if the user has an Apple Watch, prompt them to connect Health App if they haven't already
                    let healthKitVC = self.storyboard!.instantiateViewControllerWithIdentifier("SetupWatchActivitySyncingViewController") as! SetupChildViewController
                    self.setupVC(healthKitVC)
                    self.myViewControllers.insert(healthKitVC, atIndex: (self.myViewControllers.count - 1))
                }
            }
        }
        
        if let button = sender as? UIControl { button.userInteractionEnabled = false }
        
        let pageNumber = (self.myViewControllers!).indexOf(sender as! SetupChildViewController)
        let interval = skipNext ? 2 : 1
        
        if (pageNumber == nil || (pageNumber! + interval) >= (self.myViewControllers.count - 1)) {
            self.done()
        } else {
            let nextPage = self.myViewControllers[pageNumber! + interval]
            nextPage.childViewControllerWillPresent(userInfo)
            let transition = CATransition()
            transition.duration = 0.6
            transition.type = kCATransitionFade
            self.view.layer.addAnimation(transition, forKey: nil)
            self.setViewControllers([nextPage], animated: false)
            if let button = sender as? UIControl { button.userInteractionEnabled = true }
        }
    }
    
    func previousPage(sender: AnyObject) {
        if let button = sender as? UIControl { button.userInteractionEnabled = false }

        let pageNumber = (self.myViewControllers!).indexOf(sender as! SetupChildViewController)
        
        if (pageNumber == nil || (pageNumber! - 1) < 0) {
            // presumably we are already on the first page.
        } else {
            let prevPage = self.myViewControllers[pageNumber! - 1]
            let transition = CATransition()
            transition.duration = 0.6
            transition.type = kCATransitionFade
            self.view.layer.addAnimation(transition, forKey: nil)
            self.setViewControllers([prevPage], animated: false)
            if let button = sender as? UIControl { button.userInteractionEnabled = true }
        }
    }
    
    func done(userInfo : [String: AnyObject]? = nil) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasSeenSetup")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        let lastPage = self.myViewControllers.last!
        lastPage.childViewControllerWillPresent(userInfo)

        let transition = CATransition()
        transition.duration = 0.6
        transition.type = kCATransitionFade
        self.view.layer.addAnimation(transition, forKey: nil)
        self.setViewControllers([lastPage], animated: false)        
    }
}
