//
//  MainViewController.swift
//  HoneyBee
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
    
    private var logsShowing : Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.navigationItem.title = NSString(format: "%.0f miles logged", Trip.totalCycledMiles)
        
        self.customButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 22, 22))
        self.customButton.addTarget(self, action: "pauseResumeTracking:", forControlEvents: UIControlEvents.TouchUpInside)
        self.navigationItem.rightBarButtonItem?.customView = self.customButton
        
        let settingsCustomButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 25, 25))
        settingsCustomButton.addTarget(self, action: "tools:", forControlEvents: UIControlEvents.TouchUpInside)
        settingsCustomButton.maskImage = UIImage(named: "gear.png")
        settingsCustomButton.primaryColor = self.navigationItem.leftBarButtonItem?.tintColor
        settingsCustomButton.secondaryColor = self.navigationItem.leftBarButtonItem?.tintColor
        self.navigationItem.leftBarButtonItem?.customView = settingsCustomButton
        
        self.mapViewController = self.childViewControllers.first as MapViewController
        self.routesViewController = self.childViewControllers.last?.topViewController as RoutesViewController
        self.routesViewController.mainViewController = self
        
        self.refreshPauseResumeTrackingButtonUI()

        let hasSeenGettingStarted = NSUserDefaults.standardUserDefaults().boolForKey("hasSeenGettingStarted")

        if (!hasSeenGettingStarted) {
            self.navigationController?.performSegueWithIdentifier("segueToGettingStarted", sender: self)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        self.refreshPauseResumeTrackingButtonUI()
    }
    
    @IBAction func tools(sender: AnyObject) {
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Edit Privacy Circle", "Report Bug", "Help")
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
            
            if (RouteMachine.sharedMachine.isPausedDueToBatteryLife() && self.batteryLowPopupView.hidden) {
                self.batteryLowPopupView.popIn()
            }
        } else {
            self.customButton.maskImage = UIImage(named: "locationArrow.png")
            self.customButton.primaryColor = UIColor(red: 112/255, green: 234/255, blue: 156/255, alpha: 1.0)
            self.customButton.secondaryColor = UIColor(red: 116.0/255, green: 187.0/255, blue: 240.0/255, alpha: 1.0)
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
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            self.mapViewController.enterPrivacyCircleEditor()
        } else if (buttonIndex == 2){
            sendLogFile()
        } else if (buttonIndex == 3) {
            self.navigationController?.performSegueWithIdentifier("segueToGettingStarted", sender: self)
        }
    }
    
    @IBAction func logs(sender: AnyObject) {
        if (self.logsShowing) {
            UIForLumberjack.sharedInstance().showLogInView(self.view)
        } else {
            UIForLumberjack.sharedInstance().hideLog()
        }
        
        self.logsShowing = !self.logsShowing
    }
    
    func sendLogFile() {
        let fileInfos = AppDelegate.appDelegate().fileLogger.logFileManager.sortedLogFileInfos()
        if (fileInfos == nil || fileInfos.count == 0) {
            return
        }
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Bug Report")
        composer.setToRecipients(["logs@ride.report"])
        composer.mailComposeDelegate = self
        
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