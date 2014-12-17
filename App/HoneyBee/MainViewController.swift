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
    
    var mapViewController: MapViewController! = nil
    var routesViewController: RoutesViewController! = nil
    
    var selectedTrip : Trip!
    
    private var logsShowing : Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.mapViewController = self.childViewControllers.first as MapViewController
        self.routesViewController = self.childViewControllers.last?.topViewController as RoutesViewController
        self.routesViewController.mainViewController = self
        
        refreshPauseResumeTrackingButtonUI()
    }
    
    @IBAction func tools(sender: AnyObject) {
        if (self.selectedTrip == nil) {
            return;
        }
        
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Set up Privacy Circle", "Send Logs")
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
            self.pauseResumeTrackingButton.title = "Resume Tracking"
        } else {
            self.pauseResumeTrackingButton.title = "Pause Tracking"
        }
    }
    
    func setSelectedTrip(trip : Trip!) {
        let oldTrip = self.selectedTrip
        
        self.selectedTrip = trip
        
        if (oldTrip != nil) {
            self.mapViewController.refreshTrip(oldTrip)
        }
        
        if (trip != nil) {
            self.mapViewController.refreshTrip(trip)
        }
        
        self.mapViewController.setSelectedTrip(trip)
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            self.mapViewController.enterPrivacyCircleEditor()
        } else if (buttonIndex == 2){
            sendLogFile()
        } else {
            
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
        composer.setSubject("HoneyBee Log File")
        composer.setToRecipients(["honeybeelogs@knocktounlock.com"])
        composer.addAttachmentData(fileData, mimeType: "text/plain", fileName: firstFileInfo.fileName)
        composer.mailComposeDelegate = self
        
        self.presentViewController(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

}