//
//  HamburgerViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import ECSlidingViewController
import Mixpanel

class HamburgerNavController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = [UIRectEdge.Bottom, UIRectEdge.Top, UIRectEdge.Left]
    }
    
    @IBAction func unwind(segue: UIStoryboardSegue) {
        
    }
    
}

class HamburgerViewController: UITableViewController {
    @IBOutlet weak var accountTableViewCell: UITableViewCell!
    @IBOutlet weak var healthKitTableViewCell: UITableViewCell!
    @IBOutlet weak var mapStatsTableViewCell: UITableViewCell!
    @IBOutlet weak var pauseResueTableViewCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.slidingViewController().topViewAnchoredGesture = [ECSlidingViewControllerAnchoredGesture.Tapping, ECSlidingViewControllerAnchoredGesture.Panning]
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.updateAccountStatusText()
        self.updatePauseResumeText()
        self.updateHealthKitText()
        self.tableView.reloadData()

        NSNotificationCenter.defaultCenter().addObserverForName("APIClientAccountStatusDidChange", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
            dispatch_async(dispatch_get_main_queue(), { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.updateAccountStatusText()
            })
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName("APIClientAccountStatusDidGetArea", object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.tableView.reloadData()
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func updateHealthKitText() {
        guard #available(iOS 9.0, *) else {
            self.healthKitTableViewCell.textLabel?.textColor = ColorPallete.sharedPallete.unknownGrey
            self.healthKitTableViewCell.accessoryType = UITableViewCellAccessoryType.None
            return
        }
        
        if (NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup")) {
            self.healthKitTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.healthKitTableViewCell.accessoryType = UITableViewCellAccessoryType.Checkmark
        } else {
            self.healthKitTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.healthKitTableViewCell.accessoryType = UITableViewCellAccessoryType.None
        }
    }
    
    func updateAccountStatusText() {
        switch APIClient.sharedClient.accountVerificationStatus {
        case .Unknown:
            self.accountTableViewCell.userInteractionEnabled = false
            self.accountTableViewCell.textLabel?.textColor = ColorPallete.sharedPallete.unknownGrey
            self.accountTableViewCell.textLabel?.text = "Updating…"
        case .Unverified:
            self.accountTableViewCell.userInteractionEnabled = true
            self.accountTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.accountTableViewCell.textLabel?.text = "Create Account"
        case .Verified:
            self.accountTableViewCell.userInteractionEnabled = true
            self.accountTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.accountTableViewCell.textLabel?.text = "Log Out"
        }
        
    }
    
    func updatePauseResumeText() {
        if (RouteManager.sharedManager.isPaused()) {
            self.pauseResueTableViewCell.textLabel?.text = "Resume Ride Report"
        } else {
            self.pauseResueTableViewCell.textLabel?.text = "Pause Ride Report"
        }
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.min
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (APIClient.sharedClient.area) {
        case .Area(_,_, _, _):
            return 4
        default:
            return 4
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.row == 3) {
            let priorHealthKitState = NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup")
            NSUserDefaults.standardUserDefaults().setBool(!priorHealthKitState, forKey: "healthKitIsSetup")
            NSUserDefaults.standardUserDefaults().synchronize()
            self.updateHealthKitText()
            
            if (priorHealthKitState) {
                // it was enabled
                HealthKitManager.shutdown()
            } else {
                HealthKitManager.startup()
            }
            
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        } else if (indexPath.row == 1) {
            if (APIClient.sharedClient.accountVerificationStatus == .Unverified) {
                AppDelegate.appDelegate().transitionToCreatProfile()
            } else if (APIClient.sharedClient.accountVerificationStatus == .Verified){
                APIClient.sharedClient.logout()
                AppDelegate.appDelegate().transitionToCreatProfile()
            }
        } else if (indexPath.row == 0) {
            if (RouteManager.sharedManager.isPaused()) {
                Mixpanel.sharedInstance().track(
                    "resumedTracking"
                )
                RouteManager.sharedManager.resumeTracking()
                self.updatePauseResumeText()
                if let routesVC = (((self.view.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? RoutesViewController) {
                    routesVC.refreshHelperPopupUI()
                }
            } else {
                let actionSheet = UIActionSheet(title: "How Long Would You Like to Pause Ride Report?", delegate: nil, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Pause For an Hour", "Pause Until Tomorrow", "Pause Until Next Week", "Pause For Now")
                actionSheet.tapBlock = {(actionSheet, buttonIndex) -> Void in
                    if (buttonIndex == 1) {
                        Mixpanel.sharedInstance().track(
                            "pausedTracking",
                            properties: ["duration": "hour"]
                        )
                        RouteManager.sharedManager.pauseTracking(NSDate().hoursFrom(1))
                    } else if (buttonIndex == 2){
                        Mixpanel.sharedInstance().track(
                            "pausedTracking",
                            properties: ["duration": "day"]
                        )
                        RouteManager.sharedManager.pauseTracking(NSDate.tomorrow())
                    } else if (buttonIndex == 3) {
                        Mixpanel.sharedInstance().track(
                            "pausedTracking",
                            properties: ["duration": "week"]
                        )
                        RouteManager.sharedManager.pauseTracking(NSDate.nextWeek())
                    } else if (buttonIndex == 4) {
                        Mixpanel.sharedInstance().track(
                            "pausedTracking",
                            properties: ["duration": "indefinite"]
                        )
                        RouteManager.sharedManager.pauseTracking()
                    }
                    
                    self.updatePauseResumeText()
                    if let mainViewController = (((self.view.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? RoutesViewController) {
                        mainViewController.refreshHelperPopupUI()
                    }
                }
                actionSheet.showFromToolbar((self.navigationController?.toolbar)!)
            }
            
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
}


