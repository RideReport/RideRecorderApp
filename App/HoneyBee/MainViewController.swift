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
        
        self.customButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 25, 25))
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
        
        refreshPauseResumeTrackingButtonUI()
        
        let hasSeenGettingStarted = NSUserDefaults.standardUserDefaults().boolForKey("hasSeenGettingStarted")

        if (!hasSeenGettingStarted) {
            self.navigationController?.performSegueWithIdentifier("segueToGettingStarted", sender: self)
        }
    }
    
    @IBAction func tools(sender: AnyObject) {
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Edit Privacy Circle", "Report Bug", "Sync all routes", "Help")
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

        } else {
            self.customButton.maskImage = UIImage(named: "locationArrow.png")
            self.customButton.primaryColor = UIColor(red: 112/255, green: 234/255, blue: 156/255, alpha: 1.0)
            self.customButton.secondaryColor = UIColor(red: 116.0/255, green: 187.0/255, blue: 240.0/255, alpha: 1.0)
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
            Trip.syncTrips()
        } else if (buttonIndex == 4) {
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
        
        let firstFileInfo = fileInfos.first! as DDLogFileInfo
        let fileData = NSData(contentsOfURL: NSURL(fileURLWithPath: firstFileInfo.filePath)!)
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Log File")
        composer.setToRecipients(["honeybeelogs@knocktounlock.com"])
        composer.addAttachmentData(fileData, mimeType: "text/plain", fileName: firstFileInfo.fileName)
        composer.mailComposeDelegate = self
        
        self.presentViewController(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

}