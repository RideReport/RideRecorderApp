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
    var mapViewController: MapViewController! = nil
    var routesViewController: RoutesViewController! = nil
    
    var selectedTrip : Trip!
    
    private var logsShowing : Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapViewController = self.childViewControllers.first as MapViewController
        self.routesViewController = self.childViewControllers.last as RoutesViewController
        
        self.setSelectedTrip(Trip.mostRecentTrip())
        self.routesViewController.setSelectedTrip(Trip.mostRecentTrip())
    }
    
    @IBAction func rateBad(sender: AnyObject) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.mapViewController.refreshTrip(self.selectedTrip)
    }
    
    @IBAction func rateGood(sender: AnyObject) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.mapViewController.refreshTrip(self.selectedTrip)
    }
    
    @IBAction func tools(sender: AnyObject) {
        if (self.selectedTrip == nil) {
            return;
        }
        
        var smoothButtonTitle = ""
        if (self.selectedTrip.hasSmoothed) {
            smoothButtonTitle = "Unsmooth"
        } else {
            smoothButtonTitle = "Smooth"
        }
        
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Query Core Motion Acitivities", smoothButtonTitle, "Simulate Ride End", "Mark as Bike Ride", "Close Trip", "Sync to Server", "Set up Privacy Circle", "Send Logs")
        actionSheet.showFromToolbar(self.navigationController?.toolbar)
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
            self.selectedTrip.clasifyActivityType({
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.mapViewController.refreshTrip(self.selectedTrip)
                })
            })
        } else if (buttonIndex == 2) {
            if (self.selectedTrip.hasSmoothed) {
                self.selectedTrip.undoSmoothWithCompletionHandler({
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.mapViewController.refreshTrip(self.selectedTrip)
                    })
                })
            } else {
                self.selectedTrip.smoothIfNeeded({
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.mapViewController.refreshTrip(self.selectedTrip)
                    })
                })
            }
        } else if (buttonIndex == 3) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                self.selectedTrip.sendTripCompletionNotification()
            })
        } else if (buttonIndex == 4) {
            self.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            CoreDataController.sharedCoreDataController.saveContext()
            
            self.mapViewController.refreshTrip(self.selectedTrip)
        } else if (buttonIndex == 5) {
            self.selectedTrip.closeTrip()
            
            self.mapViewController.refreshTrip(self.selectedTrip)
        } else if (buttonIndex == 6) {
            self.selectedTrip.syncToServer()
        } else if (buttonIndex == 7) {
            self.mapViewController.enterPrivacyCircleEditor()
        } else if (buttonIndex == 8){
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