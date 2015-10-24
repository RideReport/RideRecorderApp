//
//  MainViewController.swift
//  Ride Report
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SystemConfiguration

class MainViewController: UIViewController, PushSimulatorViewDelegate {
    @IBOutlet weak var counter: RCounter!
    @IBOutlet weak var pauseResumeTrackingButton: UIBarButtonItem!
    @IBOutlet weak var routesContainerView: UIView!
    weak var popupView: PopupView!
    @IBOutlet weak var selectedTripView: UIView!
    @IBOutlet weak var editModeView: UIView!
    weak var rideRushSimulatorView: PushSimulatorView!
    @IBOutlet weak var ridesHistoryButton: UIButton!
    @IBOutlet weak var closeRideButton: UIButton!
    @IBOutlet weak var selectedRideToolBar: UIView!
    @IBOutlet weak var mapInfoToolBar: UIView!
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    private var reachability : Reachability!
    
    var customButton: HBAnimatedGradientMaskButton! = nil
    
    var mapViewController: MapViewController! = nil
    var routesViewController: RoutesViewController! = nil
    
    var selectedTrip : Trip! {
        didSet {
            dispatch_async(dispatch_get_main_queue(), {
                if (oldValue != nil) {
                    self.mapViewController.refreshTrip(oldValue)
                }
                
                if (self.selectedTrip != nil) {
                    if (self.selectedTrip.locationsNotYetDownloaded) {
                        APIClient.sharedClient.getTrip(self.selectedTrip).apiResponse({ (_, _) -> Void in
                            self.mapViewController.refreshTrip(self.selectedTrip)
                            self.reloadTripSelectedToolbar()
                        })
                    } else {
                        self.mapViewController.refreshTrip(self.selectedTrip)
                    }
                }
                self.mapViewController.setSelectedTrip(self.selectedTrip)
                self.reloadTripSelectedToolbar()
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for viewController in self.childViewControllers {
            if (viewController.isKindOfClass(MapViewController)) {
                self.mapViewController = viewController as! MapViewController
            }
        }
        
        self.editModeView.hidden = true
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.customButton = HBAnimatedGradientMaskButton(frame: CGRectMake(0, 0, 22, 22))
        self.customButton.addTarget(self, action: "pauseResumeTracking:", forControlEvents: UIControlEvents.TouchUpInside)
        self.navigationItem.rightBarButtonItem?.customView = self.customButton
        
        self.navigationItem.titleView!.backgroundColor = UIColor.clearColor()
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
        
        self.rideRushSimulatorView.delegate = self
        self.rideRushSimulatorView.showsEditButton = true
                
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
            self.selectedTrip = Trip.mostRecentBikeTrip()
        })
        
        self.refreshPauseResumeTrackingButtonUI()
    }
    
    func reloadTripSelectedToolbar() {
        if (self.selectedTrip != nil) {
            let trip = self.selectedTrip
            var dateTitle = ""
            
            if (trip.locationsNotYetDownloaded) {
                self.rideRushSimulatorView.dateString = ""
                self.rideRushSimulatorView.body = "Downloading Trip Data…"
            } else if (trip.startDate == nil || (trip.startDate.isToday() && !trip.isClosed)) {
                self.rideRushSimulatorView.dateString = ""
                self.rideRushSimulatorView.body = "Trip in Progress…"
            } else {
                if (trip.startDate != nil) {
                    if (trip.startDate.isToday()) {
                        dateTitle = "Today at " + self.timeFormatter.stringFromDate(trip.startDate)
                    } else if (trip.startDate.isYesterday()) {
                        dateTitle = "Yesterday at " + self.timeFormatter.stringFromDate(trip.startDate)
                    } else if (trip.startDate.isInLastWeek()) {
                        dateTitle = trip.startDate.weekDay()
                    } else {
                        dateTitle = String(format: "%@", self.dateFormatter.stringFromDate(trip.startDate)) + " at " + self.timeFormatter.stringFromDate(trip.startDate)
                    }
                }
                self.rideRushSimulatorView.dateString = dateTitle
                self.rideRushSimulatorView.body = trip.notificationString()!
                
                if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                    if (trip.rating.shortValue == Trip.Rating.NotSet.rawValue) {
                        self.rideRushSimulatorView.delay(0.1, completionHandler: {
                            self.rideRushSimulatorView.showControls()
                        })
                    } else {
                        self.rideRushSimulatorView.hideControls(false)
                    }
                    self.rideRushSimulatorView.showsActionButon = true
                    self.rideRushSimulatorView.showsDestructiveActionButon = true
                } else {
                    self.rideRushSimulatorView.showsActionButon = false
                    self.rideRushSimulatorView.showsDestructiveActionButon = false
                }
            }
            
            self.selectedRideToolBar.hidden = false
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
        NSNotificationCenter.defaultCenter().addObserverForName("TripDidCloseOrCancelTrip", object: nil, queue: nil) { (notif) -> Void in
            self.reloadTripSelectedToolbar()
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName("APIClientAccountStatusDidGetArea", object: nil, queue: nil) { (notif) -> Void in
            self.reloadMapInfoToolBar()
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
    
    private func reloadMapInfoToolBar() {
        switch APIClient.sharedClient.area {
        case .Unknown:
            self.counter.hidden = true
        case .NonArea:
            self.counter.hidden = true
        case .Area(let name, let count, let countPerHour, let launched):
            self.counter.hidden = false
            self.counter.updateCounter(count, animate: true)
        }
    }
    
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
            Trip.mostRecentBikeTrip().sendTripCompletionNotification() {
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
                    RouteManager.sharedManager.pauseTracking(NSDate().hoursFrom(1))
                } else if (buttonIndex == 2){
                    RouteManager.sharedManager.pauseTracking(NSDate.tomorrow())
                } else if (buttonIndex == 3) {
                    RouteManager.sharedManager.pauseTracking(NSDate.nextWeek())
                } else if (buttonIndex == 4) {
                    RouteManager.sharedManager.pauseTracking()
                }
                self.refreshPauseResumeTrackingButtonUI()
            }
            actionSheet.showFromToolbar((self.navigationController?.toolbar)!)
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
                self.popupView.text = "Ride Report needs permission to run"
            } else if (RouteManager.sharedManager.isPausedDueToBatteryLife()) {
                self.popupView.text = "Ride Report is paused until you charge your phone"
            } else {
                if let pausedUntilDate = RouteManager.sharedManager.pausedUntilDate() {
                    if (pausedUntilDate.isToday()) {
                        self.popupView.text = "Ride Report is paused until " + self.timeFormatter.stringFromDate(pausedUntilDate)
                    } else if (pausedUntilDate.isTomorrow()) {
                        self.popupView.text = "Ride Report is paused until tomorrow"
                    } else if (pausedUntilDate.isThisWeek()) {
                        self.popupView.text = "Ride Report is paused until " + pausedUntilDate.weekDay()
                    } else {
                        self.popupView.text = "Ride Report is paused until " + self.dateFormatter.stringFromDate(pausedUntilDate)
                    }
                } else {
                    self.popupView.text = "Ride Report is paused"
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
                self.popupView.text = "Ride Report works best when Wi-Fi is on"
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
}