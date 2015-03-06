//
//  MainViewController.swift
//  Ride
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import MessageUI

class MainViewController: UIViewController, MFMailComposeViewControllerDelegate, UIActionSheetDelegate {
    @IBOutlet weak var pauseResumeTrackingButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var routesContainerView: UIView!
    @IBOutlet weak var batteryLowPopupView: UIView!
    var customButton: HBAnimatedGradientMaskButton! = nil
    
    var mapViewController: MapViewController! = nil
    var routesViewController: RoutesViewController! = nil
    
    var selectedTrip : Trip!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.customButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 22, 22))
        self.customButton.addTarget(self, action: "pauseResumeTracking:", forControlEvents: UIControlEvents.TouchUpInside)
        self.navigationItem.rightBarButtonItem?.customView = self.customButton
        
        let settingsCustomButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 25, 25))
        settingsCustomButton.addTarget(self, action: "tools:", forControlEvents: UIControlEvents.TouchUpInside)
        settingsCustomButton.maskImage = UIImage(named: "gear.png")
        settingsCustomButton.primaryColor = self.navigationItem.leftBarButtonItem?.tintColor
        settingsCustomButton.secondaryColor = self.navigationItem.leftBarButtonItem?.tintColor
        settingsCustomButton.animates = false
        self.navigationItem.leftBarButtonItem?.customView = settingsCustomButton
        
        for viewController in self.childViewControllers {
            if (viewController.isKindOfClass(MapViewController)) {
                self.mapViewController = viewController as MapViewController
            } else if (viewController.isKindOfClass(UINavigationController)) {
                self.routesViewController = viewController.topViewController as RoutesViewController
                self.routesViewController.mainViewController = self
            }
        }
        
        self.refreshPauseResumeTrackingButtonUI()
    }
    
    //
    // MARK: - UIVIewController
    //
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refreshPauseResumeTrackingButtonUI()
        
        let hasSeenGettingStarted = NSUserDefaults.standardUserDefaults().boolForKey("hasSeenGettingStartedv2")
        
        if (!hasSeenGettingStarted) {
            self.navigationController?.performSegueWithIdentifier("segueToGettingStarted", sender: self)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.selectedTrip = nil
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.selectedTrip = nil
    }
    
    //
    // MARK: - UI Actions
    //
    
    @IBAction func tools(sender: AnyObject) {
        #if DEBUG
            let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Edit Privacy Circle", "Report Problem", "Setup Assistant", "Show Geofences")
        #else
            let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Edit Privacy Circle", "Report Problem", "Setup Assistant")
        #endif
        actionSheet.showFromToolbar(self.navigationController?.toolbar)
    }
    
    @IBAction func pauseResumeTracking(sender: AnyObject) {
        if (RouteMachine.sharedMachine.isPaused()) {
            RouteMachine.sharedMachine.resumeTracking()
        } else {
            RouteMachine.sharedMachine.pauseTracking()
        }
        
        refreshPauseResumeTrackingButtonUI()
    }
    
    func refreshPauseResumeTrackingButtonUI() {
        if (RouteMachine.sharedMachine.isPaused()) {
            self.customButton.maskImage = UIImage(named: "locationArrowDisabled.png")
            self.customButton.primaryColor = UIColor.grayColor()
            self.customButton.secondaryColor = UIColor.grayColor()
            self.customButton.animates = false
            
            if (RouteMachine.sharedMachine.isPausedDueToBatteryLife() && self.batteryLowPopupView.hidden) {
                self.batteryLowPopupView.popIn()
            }
        } else {
            self.customButton.maskImage = UIImage(named: "locationArrow.png")
            self.customButton.primaryColor = UIColor(red: 112/255, green: 234/255, blue: 156/255, alpha: 1.0)
            self.customButton.secondaryColor = UIColor(red: 116.0/255, green: 187.0/255, blue: 240.0/255, alpha: 1.0)
            self.customButton.animates = true
            if (!RouteMachine.sharedMachine.isPausedDueToBatteryLife() && !self.batteryLowPopupView.hidden) {
                self.batteryLowPopupView.fadeOut()
            }
        }
    }
    
    func setSelectedTrip(trip : Trip!,  sender: AnyObject) {
        let oldTrip = self.selectedTrip
        
        self.selectedTrip = trip
        
        if (oldTrip != nil) {
            self.mapViewController.refreshTrip(oldTrip)
        }
        
        if (trip != nil) {
            self.mapViewController.refreshTrip(trip)
        }
        
        if (!sender.isKindOfClass(RoutesViewController)) {
            self.routesViewController.setSelectedTrip(trip)
        }
        self.mapViewController.setSelectedTrip(trip)
    }
    
    //
    // MARK: - Action Sheet
    //
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            self.mapViewController.enterPrivacyCircleEditor()
        } else if (buttonIndex == 2){
            sendLogFile()
        } else if (buttonIndex == 3) {
            self.navigationController?.performSegueWithIdentifier("segueToGettingStarted", sender: self)
        } else if (buttonIndex == 4) {
            self.mapViewController.refreshGeofences()
        }
    }
    
    func sendLogFile() {
        let fileInfos = AppDelegate.appDelegate().fileLogger.logFileManager.sortedLogFileInfos()
        if (fileInfos == nil || fileInfos.count == 0) {
            return
        }
        
        let bundleID = NSBundle.mainBundle().bundleIdentifier
        let dailyStats = UIDevice.currentDevice().dailyUsageStasticsForBundleIdentifier(bundleID) ?? NSDictionary()
        let weeklyStats = UIDevice.currentDevice().weeklyUsageStasticsForBundleIdentifier(bundleID) ?? NSDictionary()
        let body = NSString(format: "\n\n\n===BATTERY LIFE USAGE STATISTICS===\nDaily: %@\nWeekly: %@", dailyStats, weeklyStats)
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Bug Report")
        composer.setToRecipients(["logs@ride.report"])
        composer.mailComposeDelegate = self
        composer.setMessageBody(body, isHTML: false)
        
        let firstFileInfo = fileInfos.first! as DDLogFileInfo
        let firstFileData = NSData(contentsOfURL: NSURL(fileURLWithPath: firstFileInfo.filePath)!)
        composer.addAttachmentData(firstFileData, mimeType: "text/plain", fileName: firstFileInfo.fileName)
        
        if (fileInfos.count > 1) {
            let secondFileInfo = fileInfos[1] as DDLogFileInfo
            let secondFileData = NSData(contentsOfURL: NSURL(fileURLWithPath: secondFileInfo.filePath)!)
            composer.addAttachmentData(secondFileData, mimeType: "text/plain", fileName: secondFileInfo.fileName)
        }
        
        
        self.presentViewController(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}