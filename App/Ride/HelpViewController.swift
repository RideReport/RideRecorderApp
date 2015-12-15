//
//  HelpViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import ECSlidingViewController
import MessageUI

class HelpViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        self.slidingViewController().anchorRightRevealAmount = 276.0 // the default
        self.slidingViewController().viewDidLayoutSubviews()
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.min
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        if (indexPath.row == 2) {
            self.sendLogFile()
        } else if (indexPath.row == 0) {
            self.slidingViewController().anchorRightPeekAmount = 0.0
            self.slidingViewController().viewDidLayoutSubviews()
            self.slidingViewController().topViewAnchoredGesture = [ECSlidingViewControllerAnchoredGesture.Tapping, ECSlidingViewControllerAnchoredGesture.Panning]
        } else if (indexPath.row == 1) {
            AppDelegate.appDelegate().transitionToSetup()
        } else if (indexPath.row == 3) {
            AppDelegate.appDelegate().showMapAttribution()
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


