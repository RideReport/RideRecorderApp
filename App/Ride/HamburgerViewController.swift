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
import MessageUI

class HamburgerNavController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = [UIRectEdge.Bottom, UIRectEdge.Top, UIRectEdge.Left]
    }
    
    @IBAction func unwind(segue: UIStoryboardSegue) {
        
    }
    
}

class HamburgerViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var accountTableViewCell: UITableViewCell!
    @IBOutlet weak var connectedAppsTableViewCell: UITableViewCell!
    @IBOutlet weak var pauseResueTableViewCell: UITableViewCell!
    @IBOutlet weak var sendReportTableViewCell: UITableViewCell!
    @IBOutlet weak var debugCrazyPersonTableViewCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.slidingViewController().topViewAnchoredGesture = [ECSlidingViewControllerAnchoredGesture.Tapping, ECSlidingViewControllerAnchoredGesture.Panning]
        self.tableView.scrollsToTop = false // https://github.com/KnockSoftware/Ride/issues/204
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.updateAccountStatusText()
        self.updatePauseResumeText()
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
        #if DEBUG
            return 5
        #else
            return 5
        #endif
    }
    
    #if DEBUG
    func updateDebugCrazyPersonModeCellText() {
        if (NSUserDefaults.standardUserDefaults().boolForKey("DebugVerbosityMode")) {
            self.debugCrazyPersonTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugCrazyPersonTableViewCell.accessoryType = UITableViewCellAccessoryType.Checkmark
        } else {
            self.debugCrazyPersonTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugCrazyPersonTableViewCell.accessoryType = UITableViewCellAccessoryType.None
        }
    }
    #endif

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {
            return
        }
        
        if (cell == self.sendReportTableViewCell) {
            self.sendLogFile()
        } else if (cell == self.debugCrazyPersonTableViewCell) {
            #if DEBUG
                let debugVerbosityMode = NSUserDefaults.standardUserDefaults().boolForKey("DebugVerbosityMode")
                NSUserDefaults.standardUserDefaults().setBool(!debugVerbosityMode, forKey: "DebugVerbosityMode")
                NSUserDefaults.standardUserDefaults().synchronize()
                self.updateDebugCrazyPersonModeCellText()
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
            #endif
        }  else if (cell == self.accountTableViewCell) {
            if (APIClient.sharedClient.accountVerificationStatus == .Unverified) {
                AppDelegate.appDelegate().transitionToCreatProfile()
            } else if (APIClient.sharedClient.accountVerificationStatus == .Verified){
                let alertController = UIAlertController(title: nil, message: "Your trips and other data will be removed from this iPhone but remain backed up in the cloud. You can log back in later to retrieve your data.", preferredStyle: UIAlertControllerStyle.ActionSheet)
                alertController.addAction(UIAlertAction(title: "Log Out and Delete Data", style: UIAlertActionStyle.Destructive, handler: { (_) in
                    RouteManager.sharedManager.abortTrip()
                    CoreDataManager.sharedManager.resetDatabase()
                    APIClient.sharedClient.logout()
                    AppDelegate.appDelegate().transitionToCreatProfile()
                }))
                alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
            }
        } else if (cell == self.pauseResueTableViewCell) {
            if (RouteManager.sharedManager.isPaused()) {
                Mixpanel.sharedInstance().track(
                    "resumedTracking"
                )
                RouteManager.sharedManager.resumeTracking()
                self.updatePauseResumeText()
                if let routesVC = (((self.view.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? TripsViewController) {
                    routesVC.refreshHelperPopupUI()
                }
            } else {
                let updateUIBlock = {
                    self.updatePauseResumeText()
                    if let mainViewController = (((self.view.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? TripsViewController) {
                        mainViewController.refreshHelperPopupUI()
                    }
                }
                
                let alertController = UIAlertController(title: "How Long Would You Like to Pause Ride Report?", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
                alertController.addAction(UIAlertAction(title: "Pause For an Hour", style: UIAlertActionStyle.Default, handler: { (_) in
                    Mixpanel.sharedInstance().track(
                        "pausedTracking",
                        properties: ["duration": "hour"]
                    )
                    RouteManager.sharedManager.pauseTracking(NSDate().hoursFrom(1))
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause Until Tomorrow", style: UIAlertActionStyle.Default, handler: { (_) in
                    Mixpanel.sharedInstance().track(
                        "pausedTracking",
                        properties: ["duration": "day"]
                    )
                    RouteManager.sharedManager.pauseTracking(NSDate.tomorrow())
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause For a Week", style: UIAlertActionStyle.Default, handler: { (_) in
                    Mixpanel.sharedInstance().track(
                        "pausedTracking",
                        properties: ["duration": "week"]
                    )
                    RouteManager.sharedManager.pauseTracking(NSDate.nextWeek())
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause For Now", style: UIAlertActionStyle.Default, handler: { (_) in
                    Mixpanel.sharedInstance().track(
                        "pausedTracking",
                        properties: ["duration": "indefinite"]
                    )
                    RouteManager.sharedManager.pauseTracking()
                    updateUIBlock()
                }))
                
                alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
    
    func sendLogFile() {
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertView(title:"No email account", message: "Whoops, it looks like you don't have an email account configured on this iPhone", delegate: nil, cancelButtonTitle:"Ima Fix It")
            alert.show()
            return
        }
        
        let fileInfos = AppDelegate.appDelegate().fileLogger.logFileManager.sortedLogFileInfos()
        if (fileInfos == nil || fileInfos.count == 0) {
            return
        }
        
        let versionNumber = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as? String ?? "Unknown Version"
        let buildNumber = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as? String ?? ""
        let osNumber = UIDevice.currentDevice().systemVersion
        let phoneModel = UIDevice.currentDevice().deviceModel()
        let supportId = Profile.profile().supportId ?? ""
        let body = String(format: "Tell us briefly what happened.\n\n\n\n\n=====================\n Support Id: %@\nVersion:%@ (%@)\niOS Version: %@\niPhone Model: %@", supportId, versionNumber, buildNumber, osNumber, phoneModel)
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Report Bug Report")
        composer.setToRecipients(["logs@ride.report"])
        composer.mailComposeDelegate = self
        composer.setMessageBody(body as String, isHTML: false)
        
        for fileInfo in fileInfos {
            if let filePath = fileInfo.filePath, let fileData = NSData(contentsOfURL: NSURL(fileURLWithPath: filePath)) {
                composer.addAttachmentData(fileData, mimeType: "text/plain", fileName: fileInfo.fileName)
            }
        }
        
        
        self.presentViewController(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}


