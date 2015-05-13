//
//  MainViewController.swift
//  Ride
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import MessageUI

class MainViewController: UIViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var pauseResumeTrackingButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var routesContainerView: UIView!
    @IBOutlet weak var popupView: PopupView!
    @IBOutlet weak var newIncidentButton: UIButton!
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    var customButton: HBAnimatedGradientMaskButton! = nil
    
    var mapViewController: MapViewController! = nil
    var routesViewController: RoutesViewController! = nil
    
    var selectedTrip : Trip! {
        didSet {
            if (oldValue != nil) {
                self.mapViewController.refreshTrip(oldValue)
            }
            
            if (selectedTrip != nil) {
                self.newIncidentButton.hidden = false
                self.mapViewController.refreshTrip(self.selectedTrip)
            } else {
                self.newIncidentButton.hidden = false
            }
            
            self.mapViewController.setSelectedTrip(selectedTrip)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for viewController in self.childViewControllers {
            if (viewController.isKindOfClass(MapViewController)) {
                self.mapViewController = viewController as! MapViewController
            }
        }
        
        var rect : CGRect
        let markersImage = UIImage(named: "markers-soft")!
        let pinColorsCount : CGFloat = 20
        let pinWidth = markersImage.size.width/pinColorsCount
        let iconSize : CGFloat = 16.0
        var icon : UIImage! = IonIcons.imageWithIcon(ion_plus_circled, size: iconSize, color: UIColor.whiteColor())
        
        let iconPoint = CGPoint(x: (pinWidth - icon.size.width)/2.0, y: 9)
        rect = CGRect(x: 0, y: 0.0, width: pinWidth, height: markersImage.size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        markersImage.drawAtPoint(rect.origin)
        icon.drawAtPoint(iconPoint)
        let newPinImage = UIGraphicsGetImageFromCurrentImageContext().imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal)
        UIGraphicsEndImageContext()
        
        self.newIncidentButton.setImage(newPinImage, forState: UIControlState.Normal)
        self.newIncidentButton.setTitle("", forState: UIControlState.Normal)
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.customButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 22, 22))
        self.customButton.addTarget(self, action: "pauseResumeTracking:", forControlEvents: UIControlEvents.TouchUpInside)
        self.navigationItem.rightBarButtonItem?.customView = self.customButton
        
//        let settingsCustomButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 25, 25))
//        settingsCustomButton.addTarget(self, action: "tools:", forControlEvents: UIControlEvents.TouchUpInside)
//        settingsCustomButton.maskImage = UIImage(named: "gear.png")
//        settingsCustomButton.primaryColor = self.navigationItem.rightBarButtonItem?.tintColor
//        settingsCustomButton.secondaryColor = self.navigationItem.rightBarButtonItem?.tintColor
//        settingsCustomButton.animates = false
//        self.navigationItem.rightBarButtonItem?.customView = settingsCustomButton
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
        
        self.selectedTrip = nil
        
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
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "presentIncidentEditor") {
            (segue.destinationViewController.topViewController as! IncidentEditorViewController).mainViewController = self
            (segue.destinationViewController.topViewController as! IncidentEditorViewController).incident = (sender as! Incident)
        } else if (segue.identifier == "showRoutes") {
            (segue.destinationViewController as! RoutesViewController).mainViewController = self
        }
    }
    
    //
    // MARK: - UI Actions
    //
    
    @IBAction func newIncident(sender: AnyObject) {
        let roadHazardButton: PathMenuItem = PathMenuItem(image: Incident.IncidentType.RoadHazard.pinImage, highlightedImage: Incident.IncidentType.RoadHazard.pinImage, ContentImage: nil, highlightedContentImage:nil)
        let unsafeIntersectionButton = PathMenuItem(image: Incident.IncidentType.UnsafeIntersection.pinImage, highlightedImage: Incident.IncidentType.UnsafeIntersection.pinImage, ContentImage: nil, highlightedContentImage:nil)
        let bikeLaneEndsButton = PathMenuItem(image: Incident.IncidentType.BikeLaneEnds.pinImage, highlightedImage: Incident.IncidentType.BikeLaneEnds.pinImage, ContentImage: nil, highlightedContentImage:nil)
        let unsafeSpeedsButton = PathMenuItem(image: Incident.IncidentType.UnsafeSpeeds.pinImage, highlightedImage: Incident.IncidentType.UnsafeSpeeds.pinImage, ContentImage: nil, highlightedContentImage:nil)
        let aggressiveMotoristButton = PathMenuItem(image: Incident.IncidentType.AggressiveMotorist.pinImage, highlightedImage: Incident.IncidentType.AggressiveMotorist.pinImage, ContentImage: nil, highlightedContentImage:nil)
        let insufficientParkingButton = PathMenuItem(image: Incident.IncidentType.InsufficientParking.pinImage, highlightedImage: Incident.IncidentType.InsufficientParking.pinImage, ContentImage: nil, highlightedContentImage:nil)
        let suspectedBikeTheifButton = PathMenuItem(image: Incident.IncidentType.SuspectedBikeTheif.pinImage, highlightedImage: Incident.IncidentType.SuspectedBikeTheif.pinImage, ContentImage: nil, highlightedContentImage:nil)
        let unknownButton = PathMenuItem(image: Incident.IncidentType.Unknown.pinImage, highlightedImage: Incident.IncidentType.Unknown.pinImage, ContentImage: nil, highlightedContentImage:nil)
        
        var menusButtons: [PathMenuItem] = [roadHazardButton, unsafeIntersectionButton, bikeLaneEndsButton, unsafeSpeedsButton, aggressiveMotoristButton, insufficientParkingButton, suspectedBikeTheifButton, unknownButton]
    }
    
    func pathMenu(menu: PathMenu, didSelectIndex idx: Int) {
        var incidentType : Incident.IncidentType
        if (idx == Incident.IncidentType.count - 1) {
            incidentType = Incident.IncidentType.Unknown
        } else {
            incidentType = Incident.IncidentType(rawValue: idx + 1)!
        }
        let location = self.selectedTrip.closestLocationToCoordinate(self.mapViewController.mapView.centerCoordinate)
        let incident = Incident(location: location, trip: self.selectedTrip)
        incident.type = NSNumber(integer: incidentType.rawValue)
        CoreDataManager.sharedManager.saveContext()
        self.refreshSelectrTrip()
    }
    
    @IBAction func tools(sender: AnyObject) {
        #if DEBUG
            let actionSheet = UIActionSheet(title: nil, delegate: nil, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Edit Privacy Circle", "Report Problem", "Setup Assistant", "Show Geofences")
        #else
            let actionSheet = UIActionSheet(title: nil, delegate: nil, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Edit Privacy Circle", "Report Problem", "Setup Assistant")
        #endif
        actionSheet.tapBlock = {(actionSheet, buttonIndex) -> Void in
            if (buttonIndex == 1) {
                self.mapViewController.enterPrivacyCircleEditor()
            } else if (buttonIndex == 2){
                self.sendLogFile()
            } else if (buttonIndex == 3) {
                self.navigationController?.performSegueWithIdentifier("segueToGettingStarted", sender: self)
            } else if (buttonIndex == 4) {
                self.mapViewController.refreshGeofences()
            }
        }
        
        actionSheet.showFromToolbar(self.navigationController?.toolbar)
    }
    
    @IBAction func pauseResumeTracking(sender: AnyObject) {
        if (RouteManager.sharedManager.isPaused()) {
            RouteManager.sharedManager.resumeTracking()
            refreshPauseResumeTrackingButtonUI()
        } else {
            let actionSheet = UIActionSheet(title: nil, delegate: nil, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Pause Ride for an hour", "Pause Ride for the day", "Pause Ride for the week", "Turn off Ride for now")
            actionSheet.tapBlock = {(actionSheet, buttonIndex) -> Void in
                if (buttonIndex == 1) {
                    RouteManager.sharedManager.pauseTracking(untilDate: NSDate().hoursFrom(1))
                } else if (buttonIndex == 2){
                    RouteManager.sharedManager.pauseTracking(untilDate: NSDate.tomorrow())
                } else if (buttonIndex == 3) {
                    RouteManager.sharedManager.pauseTracking(untilDate: NSDate.nextWeek())
                } else if (buttonIndex == 4) {
                    RouteManager.sharedManager.pauseTracking()
                }
                self.refreshPauseResumeTrackingButtonUI()
            }
            actionSheet.showFromToolbar(self.navigationController?.toolbar)
        }
    }
    
    func refreshPauseResumeTrackingButtonUI() {
        if (RouteManager.sharedManager.isPaused()) {
            self.customButton.maskImage = UIImage(named: "locationArrowDisabled.png")
            self.customButton.primaryColor = UIColor.grayColor()
            self.customButton.secondaryColor = UIColor.grayColor()
            self.customButton.animates = false
            
            if (self.popupView.hidden) {
                self.popupView.popIn()
            }
            if (RouteManager.sharedManager.isPausedDueToUnauthorized()) {
                self.popupView.text = "Ride needs permission to run."
            } else if (RouteManager.sharedManager.isPausedDueToBatteryLife()) {
                self.popupView.text = "Ride is paused until you charge your phone =)."
            } else {
                if let pausedUntilDate = RouteManager.sharedManager.pausedUntilDate() {
                    if (pausedUntilDate.isToday()) {
                        self.popupView.text = "Ride is paused until " + self.timeFormatter.stringFromDate(pausedUntilDate) + "."
                    } else if (pausedUntilDate.isTomorrow()) {
                        self.popupView.text = "Ride is paused until tomorrow."
                    } else if (pausedUntilDate.isThisWeek()) {
                        self.popupView.text = "Ride is paused until " + pausedUntilDate.weekDay() + "."
                    } else {
                        self.popupView.text = "Ride is paused until " + self.dateFormatter.stringFromDate(pausedUntilDate) + "."
                    }
                } else {
                    self.popupView.text = "Ride is paused."
                }
            }
        } else {
            self.customButton.maskImage = UIImage(named: "locationArrow.png")
            self.customButton.primaryColor = UIColor(red: 112/255, green: 234/255, blue: 156/255, alpha: 1.0)
            self.customButton.secondaryColor = UIColor(red: 116.0/255, green: 187.0/255, blue: 240.0/255, alpha: 1.0)
            self.customButton.animates = true
            if (!self.popupView.hidden) {
                self.popupView.fadeOut()
            }
        }
    }
    
    func refreshSelectrTrip() {
        self.mapViewController.refreshTrip(self.selectedTrip)
    }
    
    //
    // MARK: - Action Sheet Actions
    //
    
    func sendLogFile() {
        let fileInfos = AppDelegate.appDelegate().fileLogger.logFileManager.sortedLogFileInfos()
        if (fileInfos == nil || fileInfos.count == 0) {
            return
        }
        
        let bundleID = NSBundle.mainBundle().bundleIdentifier
        let dailyStats = UIDevice.currentDevice().dailyUsageStasticsForBundleIdentifier(bundleID) ?? NSDictionary()
        let weeklyStats = UIDevice.currentDevice().weeklyUsageStasticsForBundleIdentifier(bundleID) ?? NSDictionary()
        let body = String(format: "\n\n\n===BATTERY LIFE USAGE STATISTICS===\nDaily: %@\nWeekly: %@", dailyStats, weeklyStats)
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Bug Report")
        composer.setToRecipients(["logs@ride.report"])
        composer.mailComposeDelegate = self
        composer.setMessageBody(body as String, isHTML: false)
        
        let firstFileInfo = fileInfos.first! as! DDLogFileInfo
        let firstFileData = NSData(contentsOfURL: NSURL(fileURLWithPath: firstFileInfo.filePath)!)
        composer.addAttachmentData(firstFileData, mimeType: "text/plain", fileName: firstFileInfo.fileName)
        
        if (fileInfos.count > 1) {
            let secondFileInfo = fileInfos[1] as! DDLogFileInfo
            let secondFileData = NSData(contentsOfURL: NSURL(fileURLWithPath: secondFileInfo.filePath)!)
            composer.addAttachmentData(secondFileData, mimeType: "text/plain", fileName: secondFileInfo.fileName)
        }
        
        
        self.presentViewController(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}