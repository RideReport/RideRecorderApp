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
    @IBOutlet weak var routesContainerView: UIView!
    weak var popupView: PopupView!
    @IBOutlet weak var selectedTripView: UIView!
    @IBOutlet weak var editModeView: UIView!
    weak var rideRushSimulatorView: PushSimulatorView!
    @IBOutlet weak var ridesHistoryButton: UIButton!
    @IBOutlet weak var closeRideButton: UIButton!
    @IBOutlet weak var selectedRideToolBar: UIView!
    
    @IBOutlet weak var counter: RCounter!
    @IBOutlet weak var mapInfoToolBar: UIView!
    @IBOutlet weak var mapInfoText: UILabel!
    @IBOutlet weak var counterText: UILabel!
    
    var mapInfoIsDismissed : Bool = false
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    private var reachability : Reachability!
    private var counterTimer : NSTimer?
    
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
        
        self.reloadTripSelectedToolbar()
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
                self.rideRushSimulatorView.hideControls(false)
                
                if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                    if (trip.rating.shortValue == Trip.Rating.NotSet.rawValue) {
                        self.rideRushSimulatorView.delay(0.1, completionHandler: {
                            self.rideRushSimulatorView.showControls()
                        })
                    }
                    self.rideRushSimulatorView.showsActionButon = true
                    self.rideRushSimulatorView.showsDestructiveActionButon = true
                } else {
                    self.rideRushSimulatorView.showsActionButon = false
                    self.rideRushSimulatorView.showsDestructiveActionButon = false
                    self.rideRushSimulatorView.delay(0.5, completionHandler: {
                        self.rideRushSimulatorView.showControls()
                    })
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
        
        self.refreshHelperPopupUI()
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
            self.refreshHelperPopupUI()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.selectedTrip = nil
        self.reachability = nil
    }
    
    override func viewDidAppear(animated: Bool) {
        self.refreshHelperPopupUI()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let timer = self.counterTimer {
            timer.invalidate()
            self.counterTimer = nil
        }
        
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
        if let timer = self.counterTimer {
            timer.invalidate()
            self.counterTimer = nil
        }
        
        if (!self.mapInfoIsDismissed) {
            self.mapInfoToolBar.hidden = false
            
            switch APIClient.sharedClient.area {
            case .Unknown:
                self.mapInfoToolBar.hidden = true
            case .NonArea:
                self.counter.hidden = true
                self.counterText.hidden = true
                
                self.mapInfoText.text = String(format: "Ride Report is not yet available in your area. Every ride you take get us closer to launching!")
            case .Area(let name, let count, let countPerHour, let launched) where count < 1000 && !launched:
                self.counter.hidden = true
                self.counterText.hidden = true
                
                self.mapInfoText.text = String(format: "Ride Report is not yet available in %@. Every ride you take get us closer to launching!", name)
            case .Area(let name, let count, let countPerHour, let launched):
                self.counter.hidden = false
                self.counterText.hidden = false
                
                self.counter.updateCounter(count, animate: true)
                self.counterTimer = NSTimer.scheduledTimerWithTimeInterval(3600.0/Double(countPerHour), target: self.counter, selector: "incrementCounter", userInfo: nil, repeats: true)
                self.counterText.text = String(format: "Rides in %@", name)

                if (launched) {
                    self.mapInfoText.text = String(format: "Map shows average ratings from %@ riders. Better routes are green, stressful routes are red.", name)
                }  else {
                    self.mapInfoText.text = String(format: "Ride Report is not yet available in %@. Every ride you take get us closer to launching!", name)
                }
            }
        } else {
            self.mapInfoToolBar.hidden = true
        }
    }
    
    @IBAction func dismissMapInfo(sender: AnyObject) {
        self.mapInfoIsDismissed = true
        self.reloadMapInfoToolBar()
    }
    
    @IBAction func showMapInfo(sender: AnyObject) {
        self.mapInfoIsDismissed = false
        self.reloadMapInfoToolBar()
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
    
    @IBAction func transitButton(sender: AnyObject) {
        self.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Transit.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
        self.transitionToTripView()
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
                
        self.navigationController?.view.layer.addAnimation(transition, forKey: kCATransition)
        self.navigationController?.pushViewController(routesVC, animated: false)
        
        routesVC.mainViewController = self
    }
    
    func refreshHelperPopupUI() {
        if (RouteManager.sharedManager.isPaused()) {
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