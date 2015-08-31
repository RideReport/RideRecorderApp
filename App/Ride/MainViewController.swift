//
//  MainViewController.swift
//  Ride Report
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import MessageUI
import ionicons
import SystemConfiguration

class MainViewController: UIViewController, MFMailComposeViewControllerDelegate, PushSimulatorViewDelegate {
    @IBOutlet weak var pauseResumeTrackingButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var routesContainerView: UIView!
    @IBOutlet weak var popupView: PopupView!
    @IBOutlet weak var newIncidentButton: UIButton!
    @IBOutlet weak var selectedTripView: UIView!
    @IBOutlet weak var editModeView: UIView!
    @IBOutlet weak var rideRushSimulatorView: PushSimulatorView!
    @IBOutlet weak var ridesHistoryButton: UIButton!
    @IBOutlet weak var closeRideButton: UIButton!
    @IBOutlet weak var selectedRideToolBar: UIView!
    
    private var settingsBarButtonItem: UIBarButtonItem!
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    private var reachability : Reachability!
    
    var customButton: HBAnimatedGradientMaskButton! = nil
    
    var mapViewController: MapViewController! = nil
    var routesViewController: RoutesViewController! = nil
    
    var selectedTrip : Trip! {
        didSet {
            if (oldValue != nil) {
                self.mapViewController.refreshTrip(oldValue)
            }
            
            self.newIncidentButton.hidden = true // disabling incidents for now
            
            if (selectedTrip != nil) {
                self.mapViewController.refreshTrip(self.selectedTrip)
            }
            self.mapViewController.setSelectedTrip(selectedTrip)
            self.reloadTripSelectedToolbar()
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
        
        self.editModeView.hidden = true
        
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
        
        self.navigationItem.titleView!.backgroundColor = UIColor.clearColor()
        
        self.settingsBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.Plain, target: self, action: "tools:")
        
        let settingsCustomButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 25, 25))
        settingsCustomButton.addTarget(self, action: "tools:", forControlEvents: UIControlEvents.TouchUpInside)
        settingsCustomButton.maskImage = UIImage(named: "gear.png")
        settingsCustomButton.primaryColor = UIColor.whiteColor()
        settingsCustomButton.secondaryColor = UIColor.whiteColor()
        settingsCustomButton.animates = false
        self.settingsBarButtonItem.customView = settingsCustomButton
        self.navigationItem.leftBarButtonItem = self.settingsBarButtonItem
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
        
        self.rideRushSimulatorView.delegate = self
        self.rideRushSimulatorView.showsEditButton = true
        
        self.selectedTrip = Trip.mostRecentTrip()
        
        self.refreshPauseResumeTrackingButtonUI()
    }
    
    func reloadTripSelectedToolbar() {
        if (self.selectedTrip != nil) {
            let trip = self.selectedTrip
            var dateTitle = ""
            if (trip.startDate != nil) {
                if (trip.startDate == nil || (trip.startDate.isToday() && !trip.isClosed)) {
                    dateTitle = "In progress"
                } else if (trip.startDate.isToday()) {
                    dateTitle = "Today at " + self.timeFormatter.stringFromDate(trip.startDate)
                } else if (trip.startDate.isYesterday()) {
                    dateTitle = "Yesterday at " + self.timeFormatter.stringFromDate(trip.startDate)
                } else if (trip.startDate.isInLastWeek()) {
                    dateTitle = trip.startDate.weekDay()
                } else {
                    dateTitle = String(format: "%@", self.dateFormatter.stringFromDate(trip.startDate)) + " at " + self.timeFormatter.stringFromDate(trip.startDate)
                }
            }
            
            self.selectedRideToolBar.hidden = false
            
            self.rideRushSimulatorView.dateString = dateTitle
            self.rideRushSimulatorView.body = trip.notificationString()!
            
            if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                if (trip.rating.shortValue == Trip.Rating.NotSet.rawValue) {
                    self.rideRushSimulatorView.delay(0.1, completionHandler: {
                        self.rideRushSimulatorView.showControls()
                    })
                } else {
                    self.rideRushSimulatorView.hideControls(animated: false)
                }
                self.rideRushSimulatorView.showsActionButon = true
                self.rideRushSimulatorView.showsDestructiveActionButon = true
            } else {
                self.rideRushSimulatorView.showsActionButon = false
                self.rideRushSimulatorView.showsDestructiveActionButon = false
            }
        } else {
            self.selectedRideToolBar.hidden = true
        }
    }
    
    func reloadTitleView() {
        let count = Trip.numberOfCycledTrips
        if (count == 0) {
            self.ridesHistoryButton.setTitle("No Trips ▾", forState: UIControlState.Normal)
        } else {
            self.ridesHistoryButton.setTitle(String(format: "%i Trips ▾", count), forState: UIControlState.Normal)
        }
        self.navigationItem.titleView!.frame = CGRectMake(0, 0, self.view.frame.size.width, self.navigationController!.navigationBar.frame.size.height)
    }
    
    //
    // MARK: - UIVIewController
    //
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refreshPauseResumeTrackingButtonUI()
        self.reloadTitleView()
        NSNotificationCenter.defaultCenter().addObserverForName("RouteManagerDidUpdatePoints", object: nil, queue: nil) { (notif) -> Void in
            if (RouteManager.sharedManager.currentTrip != nil) {
                self.selectedTrip = RouteManager.sharedManager.currentTrip
            }
            self.reloadTripSelectedToolbar()
        }

        self.reachability = Reachability.reachabilityForLocalWiFi()
        self.reachability.startNotifier()
        
        NSNotificationCenter.defaultCenter().addObserverForName(kReachabilityChangedNotification, object: nil, queue: nil) { (notif) -> Void in
            self.refreshPauseResumeTrackingButtonUI()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.selectedTrip = nil
        self.reachability = nil
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "showIncidentEditor") {
            (segue.destinationViewController as! IncidentEditorViewController).mainViewController = self
            (segue.destinationViewController as! IncidentEditorViewController).incident = (sender as! Incident)
        }
    }
    
    //
    // MARK: - UI Actions
    //
    
    private func transitionToTripView() {
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.editModeView.layer.addAnimation(transition, forKey: "transition")
        self.editModeView.hidden = true
        self.selectedTripView.hidden = false
        CATransaction.commit()
    }
    
    @IBAction func bikeButton(sender: AnyObject) {
        self.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
        self.transitionToTripView()
    }
    
    @IBAction func carButton(sender: AnyObject) {
        self.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
        self.transitionToTripView()
    }
    
    @IBAction func walkButton(sender: AnyObject) {
        self.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
        self.transitionToTripView()
    }
    
    @IBAction func runButton(sender: AnyObject) {
        self.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Running.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
        self.transitionToTripView()
    }
    
    @IBAction func showRides(sender: AnyObject) {
        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionMoveIn
        transition.subtype = kCATransitionFromBottom
        
        let routesVC = self.storyboard!.instantiateViewControllerWithIdentifier("RoutesViewController") as! RoutesViewController
        routesVC.mainViewController = self
        
        routesVC.view.layer.addAnimation(transition, forKey: kCATransition)
        self.navigationController?.pushViewController(routesVC, animated: false)
    }
    
    @IBAction func newIncident(sender: AnyObject) {
        var titles: [AnyObject] = []
        var images: [AnyObject] = []
        
        for index in 0..<Incident.IncidentType.count {
            titles.append(Incident.IncidentType(rawValue: index)!.text)
            images.append(Incident.IncidentType(rawValue: index)!.pinImage)
        }
        
        let height = (images.first as! UIImage).size.height
        
        self.newIncidentButton.hidden = true
        PCStackMenu.showStackMenuWithTitles(titles, withImages: images, atStartPoint: CGPointMake(self.newIncidentButton.frame.origin.x + self.newIncidentButton.frame.size.width, self.newIncidentButton.frame.origin.y + self.newIncidentButton.frame.size.height), inView: self.view, itemHeight: height, menuDirection: PCStackMenuDirectionClockWiseUp) { (selectedIndex) -> Void in
            var incidentType : Incident.IncidentType
            self.newIncidentButton.hidden = false
            
            if (selectedIndex != NSNotFound) {
                incidentType = Incident.IncidentType(rawValue: selectedIndex)!
                let location = self.selectedTrip.closestLocationToCoordinate(self.mapViewController.mapView.centerCoordinate)
                let incident = Incident(location: location, trip: self.selectedTrip)
                incident.type = NSNumber(integer: incidentType.rawValue)
                CoreDataManager.sharedManager.saveContext()
                self.mapViewController.addIncidentToMap(incident)
            }
        }
    }
    
    @IBAction func tools(sender: AnyObject) {
        var accountButtonTitle = ""
        switch APIClient.sharedClient.accountVerificationStatus {
            case .Unknown: accountButtonTitle = "Updating Account Status…"
            case .Unverified: accountButtonTitle = "Create Account"
            case .Verified: accountButtonTitle = "Log Out…"
        }
        let actionSheet = UIActionSheet(title: nil, delegate: nil, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles:"Report Problem", accountButtonTitle, "Map Info")
        actionSheet.tapBlock = {(actionSheet, buttonIndex) -> Void in
            if (buttonIndex == 1) {
                self.sendLogFile()
            } else if (buttonIndex == 2) {
                if (APIClient.sharedClient.accountVerificationStatus == .Unverified) {
                    AppDelegate.appDelegate().transitionToCreatProfile()
                } else {
                    // other cases currently do nothing
                    let alert = UIAlertView(title:nil, message: "You can't. (・_・)ヾ", delegate: nil, cancelButtonTitle:"But soon")
                    alert.show()
                }
            } else if (buttonIndex == 3) {
                // show map attribution info
                self.mapViewController.mapView.attributionButton.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
            }
        }
        
        actionSheet.showFromToolbar(self.navigationController?.toolbar)
    }
    
#if DEBUG
    
    override func canBecomeFirstResponder()->Bool {
        return true
    }
    
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if (motion == UIEventSubtype.MotionShake) {
            showSampleNotification()
        }
    }

    func showSampleNotification() {
        let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
        })
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
            Trip.mostRecentTrip().sendTripCompletionNotification() {
                if (backgroundTaskID != UIBackgroundTaskInvalid) {
                    UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
                }
            }
        })
    }
    
#endif
    
    @IBAction func pauseResumeTracking(sender: AnyObject) {
        if (RouteManager.sharedManager.isPaused()) {
            RouteManager.sharedManager.resumeTracking()
            refreshPauseResumeTrackingButtonUI()
        } else {
            let actionSheet = UIActionSheet(title: nil, delegate: nil, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Pause Ride Report for an hour", "Pause Ride Report for the day", "Pause Ride Report for the week", "Turn off Ride Report for now")
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
                self.popupView.text = "Ride Report needs permission to run."
            } else if (RouteManager.sharedManager.isPausedDueToBatteryLife()) {
                self.popupView.text = "Ride Report is paused until you charge your phone =)."
            } else {
                if let pausedUntilDate = RouteManager.sharedManager.pausedUntilDate() {
                    if (pausedUntilDate.isToday()) {
                        self.popupView.text = "Ride Report is paused until " + self.timeFormatter.stringFromDate(pausedUntilDate) + "."
                    } else if (pausedUntilDate.isTomorrow()) {
                        self.popupView.text = "Ride Report is paused until tomorrow."
                    } else if (pausedUntilDate.isThisWeek()) {
                        self.popupView.text = "Ride Report is paused until " + pausedUntilDate.weekDay() + "."
                    } else {
                        self.popupView.text = "Ride Report is paused until " + self.dateFormatter.stringFromDate(pausedUntilDate) + "."
                    }
                } else {
                    self.popupView.text = "Ride Report is paused."
                }
            }
        } else {
            self.customButton.maskImage = UIImage(named: "locationArrow.png")
            self.customButton.primaryColor = UIColor(red: 112/255, green: 234/255, blue: 156/255, alpha: 1.0)
            self.customButton.secondaryColor = UIColor(red: 116.0/255, green: 187.0/255, blue: 240.0/255, alpha: 1.0)
            self.customButton.animates = true
            
            if (!UIDevice.currentDevice().wifiEnabled) {
                if (self.popupView.hidden) {
                    self.popupView.popIn()
                }
                self.popupView.text = "Ride Report's accuracy is improved when Wi-Fi is on."
            } else if (!self.popupView.hidden) {
                self.popupView.fadeOut()
            }
        }
    }
    
    func refreshSelectrTrip() {
        self.mapViewController.refreshTrip(self.selectedTrip)
        self.reloadTripSelectedToolbar()
    }
    
    //
    // MARK: - Push Simulator View Actions
    //
    
    func didTapEditButton(view: PushSimulatorView) {
        CATransaction.begin()
            let transition = CATransition()
            transition.duration = 0.5
            transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            transition.type = kCATransitionReveal
            transition.subtype = kCATransitionFromRight
            self.selectedTripView.layer.addAnimation(transition, forKey: "transition")
            self.editModeView.hidden = false
            self.selectedTripView.hidden = true
        CATransaction.commit()
    }
    
    func didTapDestructiveButton(view: PushSimulatorView) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
    }
    
    func didTapActionButton(view: PushSimulatorView) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
    }
    
    func didTapClearButton(view: PushSimulatorView) {
        self.selectedTrip = nil
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
        let body = "What happened?\n"
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Report Bug Report")
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