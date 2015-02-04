//
//  RouteDetailViewController.swift
//  Ride
//
//  Created by William Henderson on 12/17/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class RouteDetailViewController: UIViewController, UIActionSheetDelegate {
    var mainViewController: MainViewController! = nil
    @IBOutlet weak var thumbsUpButton: UIButton!
    @IBOutlet weak var thumbsDownButton: UIButton!
    @IBOutlet weak var bikeButton: UIButton!
    @IBOutlet weak var batteryLifeLabel: UILabel!
    @IBOutlet weak var carButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var tripSpeedLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.clearColor()
        
        var blur = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        var effectView = UIVisualEffectView(effect: blur)
        let navHeight = self.navigationController?.navigationBar.frame.size.height
        effectView.frame = CGRectMake(0, navHeight!, self.view.frame.width, self.view.frame.height - navHeight!)
        self.view.addSubview(effectView)
        self.view.sendSubviewToBack(effectView)
        
#if DEBUG
        let toolsButton = UIBarButtonItem(title: "Debug", style: UIBarButtonItemStyle.Bordered, target: self, action: "tools:")
        self.navigationItem.rightBarButtonItem = toolsButton
#endif
    }
    
    override func viewWillAppear(animated: Bool) {        
        super.viewWillAppear(animated)
        
        refreshTripUI()
    }
    
    func refreshTripUI() {
        if self.mainViewController.selectedTrip == nil {
            return
        }
        
        let trip = self.mainViewController.selectedTrip
        
        self.distanceLabel.text = NSString(format: "%.1fm", trip.lengthMiles)
        
        let speedMph = trip.averageSpeed*2.23694
        self.tripSpeedLabel.text = NSString(format: "%.1fmph", speedMph)
        
        self.thumbsUpButton.backgroundColor = UIColor.clearColor()
        self.thumbsDownButton.backgroundColor = UIColor.clearColor()
        
        self.bikeButton.backgroundColor = UIColor.clearColor()
        self.carButton.backgroundColor = UIColor.clearColor()
        
        if trip.activityType.shortValue != Trip.ActivityType.Cycling.rawValue {
            self.thumbsUpButton.hidden = true
            self.thumbsDownButton.hidden = true
            if (trip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
                self.carButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
            }
        } else {
            self.thumbsUpButton.hidden = false
            self.thumbsDownButton.hidden = false
            self.bikeButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
        }
        
        if trip.rating.shortValue == Trip.Rating.Good.rawValue {
            self.thumbsUpButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
        } else if trip.rating.shortValue == Trip.Rating.Bad.rawValue {
            self.thumbsDownButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
        }
        
        if trip.batteryLifeUsed() > 0 {
            self.batteryLifeLabel.text = NSString(format: "%d%% battery used", trip.batteryLifeUsed())
        } else {
            self.batteryLifeLabel.text = ""
        }
    }
    
    @IBAction func thumbsUp(sender: AnyObject) {
        self.mainViewController.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
        
        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
        
        refreshTripUI()
    }
    
    @IBAction func thumbsDown(sender: AnyObject) {
        self.mainViewController.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
        
        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
        
        refreshTripUI()
    }
    
    @IBAction func bikeButton(sender: AnyObject) {
        self.mainViewController.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
        NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
        
        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
    }
    
    @IBAction func carButton(sender: AnyObject) {
        self.mainViewController.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
        NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
        
        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
    }
    
    @IBAction func tools(sender: AnyObject) {
        var smoothButtonTitle = ""
        if (self.mainViewController.selectedTrip.hasSmoothed) {
            smoothButtonTitle = "Unsmooth"
        } else {
            smoothButtonTitle = "Smooth"
        }
        
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Query Core Motion Acitivities", smoothButtonTitle, "Simulate Ride End", "Close Trip", "Sync to Server")
        actionSheet.showFromToolbar(self.navigationController?.toolbar)
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            self.mainViewController.selectedTrip.clasifyActivityType({
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
                    NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
                })
            })
        } else if (buttonIndex == 2) {
            if (self.mainViewController.selectedTrip.hasSmoothed) {
                self.mainViewController.selectedTrip.undoSmoothWithCompletionHandler({
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
                        NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
                    })
                })
            } else {
                self.mainViewController.selectedTrip.smoothIfNeeded({
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
                        NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
                    })
                })
            }
        } else if (buttonIndex == 3) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                self.mainViewController.selectedTrip.sendTripCompletionNotification()
            })
        } else if (buttonIndex == 4) {
            self.mainViewController.selectedTrip.close()
            NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
            
            self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
        } else if (buttonIndex == 5) {
            NetworkMachine.sharedMachine.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
        }
    }

    
    override func performSegueWithIdentifier(identifier: String?, sender: AnyObject?) {
        self.mainViewController = (sender as RoutesViewController).mainViewController
    }

}