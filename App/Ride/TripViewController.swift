//
//  TripViewController.swift
//  Ride Report
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class TripViewController: UIViewController, RideSummaryViewDelegate {
    @IBOutlet weak var selectedTripView: UIView!
    @IBOutlet weak var editModeView: UIView!
    weak var rideSummaryView: RideSummaryView!
    @IBOutlet weak var ridesHistoryButton: UIButton!
    @IBOutlet weak var closeRideButton: UIButton!
    @IBOutlet weak var selectedRideToolBar: UIView!
    
    var mapInfoIsDismissed : Bool = false
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    weak var mapViewController: MapViewController! = nil
    
    var selectedTrip : Trip! {
        didSet {
            dispatch_async(dispatch_get_main_queue(), { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                if (strongSelf.selectedTrip != nil) {
                    if (strongSelf.selectedTrip.locationsNotYetDownloaded || !strongSelf.selectedTrip.summaryIsSynced) {
                        APIClient.sharedClient.getTrip(strongSelf.selectedTrip).apiResponse({ (_) -> Void in
                            strongSelf.mapViewController.setSelectedTrip(strongSelf.selectedTrip)
                            strongSelf.reloadTripSelectedToolbar()
                        })
                    } else {
                        strongSelf.mapViewController.setSelectedTrip(strongSelf.selectedTrip)
                    }
                }
                strongSelf.mapViewController.setSelectedTrip(strongSelf.selectedTrip)
                strongSelf.reloadTripSelectedToolbar()
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

        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
        
        self.rideSummaryView.delegate = self
        self.rideSummaryView.showsEditButton = true
    }
    
    func reloadTripSelectedToolbar() {
        if (self.selectedTrip != nil) {
            let trip = self.selectedTrip
            var dateTitle = ""
            
            if (trip.locationsNotYetDownloaded) {
                self.rideSummaryView.dateString = ""
                self.rideSummaryView.body = "Downloading Trip Data…"
            } else if ((trip.startDate.isToday() && !trip.isClosed)) {
                self.rideSummaryView.dateString = ""
                self.rideSummaryView.body = "Trip in Progress…"
            } else {
                if (trip.startDate.isToday()) {
                    dateTitle = "Today at " + self.timeFormatter.stringFromDate(trip.startDate)
                } else if (trip.startDate.isYesterday()) {
                    dateTitle = "Yesterday at " + self.timeFormatter.stringFromDate(trip.startDate)
                } else if (trip.startDate.isInLastWeek()) {
                    dateTitle = trip.startDate.weekDay()
                } else {
                    dateTitle = String(format: "%@", self.dateFormatter.stringFromDate(trip.startDate)) + " at " + self.timeFormatter.stringFromDate(trip.startDate)
                }
                
                self.rideSummaryView.dateString = dateTitle
                self.rideSummaryView.body = trip.notificationString()!
                self.rideSummaryView.hideControls(false)
                
                if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                    if (trip.rating.shortValue == Trip.Rating.NotSet.rawValue) {
                        self.rideSummaryView.delay(0.1, completionHandler: {
                            self.rideSummaryView.showControls()
                        })
                    }
                    self.rideSummaryView.showsShareButon = true
                    self.rideSummaryView.showsActionButon = true
                    self.rideSummaryView.showsDestructiveActionButon = true
                } else {
                    self.rideSummaryView.showsShareButon = false
                    self.rideSummaryView.showsActionButon = false
                    self.rideSummaryView.showsDestructiveActionButon = false
                    self.rideSummaryView.delay(0.5, completionHandler: {
                        self.rideSummaryView.showControls()
                    })
                }
            }
            
            self.selectedRideToolBar.hidden = false
        } else {
            self.selectedRideToolBar.hidden = true
        }
    }
    
    //
    // MARK: - UIVIewController
    //
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        NSNotificationCenter.defaultCenter().addObserverForName("TripDidCloseOrCancelTrip", object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reloadTripSelectedToolbar()
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextObjectsDidChangeNotification, object: CoreDataManager.sharedManager.managedObjectContext, queue: nil) {[weak self] (notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.selectedTrip != nil else {
                return
            }
            
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? NSSet {
                if updatedObjects.containsObject(strongSelf.selectedTrip) {
                    let trip = strongSelf.selectedTrip
                    strongSelf.selectedTrip = trip
                }
            }
            
            if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? NSSet {
                if deletedObjects.containsObject(strongSelf.selectedTrip) {
                    strongSelf.selectedTrip = nil
                }
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
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
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func refreshSelectrTrip() {
        self.mapViewController.setSelectedTrip(self.selectedTrip)
        self.reloadTripSelectedToolbar()
    }

    //
    // MARK: - Push Simulator View Actions
    //
    
    func didTapEditButton(view: RideSummaryView) {
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
    
    func didTapShareButton(view: RideSummaryView) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let rideShareNavVC = storyBoard.instantiateViewControllerWithIdentifier("RideShareNavViewController") as! UINavigationController
        if let rideShareVC = rideShareNavVC.topViewController as? RideShareViewController {
            rideShareVC.trip = self.selectedTrip
        }
        self.presentViewController(rideShareNavVC, animated: true, completion: nil)
    }
    
    func didTapDestructiveButton(view: RideSummaryView) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
    }
    
    func didTapActionButton(view: RideSummaryView) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.refreshSelectrTrip()
    }
    
    func didTapClearButton(view: RideSummaryView) {
        self.selectedTrip = nil
    }
}