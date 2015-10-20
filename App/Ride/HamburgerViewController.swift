//
//  HamburgerViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import ECSlidingViewController
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.slidingViewController().topViewAnchoredGesture = [ECSlidingViewControllerAnchoredGesture.Tapping, ECSlidingViewControllerAnchoredGesture.Panning]
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        UINavigationBar.appearance().barStyle = UIBarStyle.BlackTranslucent
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.updateAccountStatusText()
        NSNotificationCenter.defaultCenter().addObserverForName("APIClientAccountStatusDidChange", object: nil, queue: nil) { (notification : NSNotification) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
            self.updateAccountStatusText()
            })
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func updateAccountStatusText() {
        var accountCellTitle = ""
        switch APIClient.sharedClient.accountVerificationStatus {
        case .Unknown: accountCellTitle = "Updating Account Status…"
        case .Unverified: accountCellTitle = "Create Account"
        case .Verified: accountCellTitle = "Log Out"
        }
        
        self.accountTableViewCell.textLabel?.text = accountCellTitle
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.min
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.row == 1) {
            self.sendLogFile()
        } else if (indexPath.row == 2) {
            if (APIClient.sharedClient.accountVerificationStatus == .Unverified) {
                AppDelegate.appDelegate().transitionToCreatProfile()
            } else if (APIClient.sharedClient.accountVerificationStatus == .Verified){
                APIClient.sharedClient.logout()
                AppDelegate.appDelegate().transitionToCreatProfile()
            }
        }
    }
    
    func sendLogFile() {
        let fileInfos = AppDelegate.appDelegate().fileLogger.logFileManager.sortedLogFileInfos()
        if (fileInfos == nil || fileInfos.count == 0) {
            return
        }
        
        let body = "What happened?\n"
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Report Bug Report")
        composer.setToRecipients(["logs@ride.report"])
        composer.mailComposeDelegate = self
        composer.setMessageBody(body as String, isHTML: false)
        
        let firstFileInfo = fileInfos.first! as! DDLogFileInfo
        if let firstFileData = NSData(contentsOfURL: NSURL(fileURLWithPath: firstFileInfo.filePath)) {
            composer.addAttachmentData(firstFileData, mimeType: "text/plain", fileName: firstFileInfo.fileName)
            
            if (fileInfos.count > 1) {
                let secondFileInfo = fileInfos[1] as! DDLogFileInfo
                let secondFileData = NSData(contentsOfURL: NSURL(fileURLWithPath: secondFileInfo.filePath!))
                composer.addAttachmentData(secondFileData!, mimeType: "text/plain", fileName: secondFileInfo.fileName)
            }
        }
        
        
        self.presentViewController(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}


