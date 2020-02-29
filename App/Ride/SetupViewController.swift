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
    var parentSetupViewController : SetupViewController?
    
    @IBAction func next(_ sender: AnyObject) {
        self.parentSetupViewController?.nextPage(sender: self)
    }
    
    func childViewControllerWillPresent(_ userInfo: [String: Any]? = nil) {
        // override to receive
    }
}

class SetupViewController: UINavigationController {
    var myViewControllers : [SetupChildViewController]!
    var hasAddedWatchkitToSetup = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.isNavigationBarHidden = true
    }
    
    func setupViewControllersForGettingStarted() {
        let setupTermsVC = self.storyboard!.instantiateViewController(withIdentifier: "setupTerms") as! SetupChildViewController
        self.setupVC(vc: setupTermsVC)
        
        
        let setupFinished = self.storyboard!.instantiateViewController(withIdentifier: "setupFinished") as! SetupChildViewController
        self.setupVC(vc: setupFinished)
        
        self.myViewControllers = [setupTermsVC]
        
        if (!UserDefaults.standard.bool(forKey: "hasSeenSetup")) {
            // if they haven't seen setup, ask for permissions
            let setupPermissionVC = self.storyboard!.instantiateViewController(withIdentifier: "setupPermissions") as! SetupChildViewController
            self.setupVC(vc: setupPermissionVC)
            self.myViewControllers.append(setupPermissionVC)
        }
                
        self.myViewControllers.append(setupFinished)
        
        self.myViewControllers.first!.childViewControllerWillPresent()
        
        self.setViewControllers([self.myViewControllers.first!], animated: false)
    }
    
    private func setupVC(vc: SetupChildViewController) {
        vc.parentSetupViewController = self
    }
    
    func nextPage(sender: AnyObject, userInfo : [String: Any]? = nil, skipInterval: Int = 0) {
        if (!hasAddedWatchkitToSetup) {
            // defer this to allow the session to activate.
            hasAddedWatchkitToSetup = true
            if #available(iOS 10.0, *) {
                if (WatchManager.shared.paired && !UserDefaults.standard.bool(forKey: "healthKitIsSetup")) {
                    // if the user has an Apple Watch, prompt them to connect Health App if they haven't already
                    let healthKitVC = self.storyboard!.instantiateViewController(withIdentifier: "SetupWatchActivitySyncingViewController") as! SetupChildViewController
                    self.setupVC(vc: healthKitVC)
                    self.myViewControllers.insert(healthKitVC, at: (self.myViewControllers.count - 1))
                }
            }
        }
        
        if let button = sender as? UIControl { button.isUserInteractionEnabled = false }
        
        let pageNumber = (self.myViewControllers!).index(of: sender as! SetupChildViewController)
        let interval = skipInterval + 1
        
        if (pageNumber == nil || (pageNumber! + interval) >= (self.myViewControllers.count - 1)) {
            self.done()
        } else {
            let nextPage = self.myViewControllers[pageNumber! + interval]
            nextPage.childViewControllerWillPresent(userInfo)
            let transition = CATransition()
            transition.duration = 0.6
            transition.type = CATransitionType.fade
            self.view.layer.add(transition, forKey: nil)
            self.setViewControllers([nextPage], animated: false)
            if let button = sender as? UIControl { button.isUserInteractionEnabled = true }
        }
    }
    
    func previousPage(sender: AnyObject) {
        if let button = sender as? UIControl { button.isUserInteractionEnabled = false }

        let pageNumber = (self.myViewControllers!).index(of: sender as! SetupChildViewController)
        
        if (pageNumber == nil || (pageNumber! - 1) < 0) {
            // presumably we are already on the first page.
        } else {
            let prevPage = self.myViewControllers[pageNumber! - 1]
            let transition = CATransition()
            transition.duration = 0.6
            transition.type = CATransitionType.fade
            self.view.layer.add(transition, forKey: nil)
            self.setViewControllers([prevPage], animated: false)
            if let button = sender as? UIControl { button.isUserInteractionEnabled = true }
        }
    }
    
    func done(userInfo : [String: Any]? = nil) {
        UserDefaults.standard.set(true, forKey: "hasSeenSetup")
        UserDefaults.standard.synchronize()
        
        let lastPage = self.myViewControllers.last!
        lastPage.childViewControllerWillPresent(userInfo)

        let transition = CATransition()
        transition.duration = 0.6
        transition.type = CATransitionType.fade
        self.view.layer.add(transition, forKey: nil)
        self.setViewControllers([lastPage], animated: false)        
    }
}
