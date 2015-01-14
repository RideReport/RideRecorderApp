//
//  RouteDetailViewController.swift
//  HoneyBee
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
    @IBOutlet weak var carButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var tripSpeedLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        if (self.mainViewController.selectedTrip == nil) {
            return
        }
        
        self.distanceLabel.text = NSString(format: "%.1fm", self.mainViewController.selectedTrip.lengthMiles)
        
        let speedMph = self.mainViewController.selectedTrip.averageSpeed*2.23694
        self.tripSpeedLabel.text = NSString(format: "%.1fmph", speedMph)
        
        self.thumbsUpButton.backgroundColor = UIColor.clearColor()
        self.thumbsDownButton.backgroundColor = UIColor.clearColor()
        
        self.bikeButton.backgroundColor = UIColor.clearColor()
        self.carButton.backgroundColor = UIColor.clearColor()
        
        if (self.mainViewController.selectedTrip.activityType.shortValue != Trip.ActivityType.Cycling.rawValue) {
            self.thumbsUpButton.hidden = true
            self.thumbsDownButton.hidden = true
            if (self.mainViewController.selectedTrip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
                self.carButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
            }
        } else {
            self.thumbsUpButton.hidden = false
            self.thumbsDownButton.hidden = false
            self.bikeButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
        }
        
        if self.mainViewController.selectedTrip.rating.shortValue == Trip.Rating.Good.rawValue {
            self.thumbsUpButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
        } else if self.mainViewController.selectedTrip.rating.shortValue == Trip.Rating.Bad.rawValue {
            self.thumbsDownButton.backgroundColor = UIColor.orangeColor().colorWithAlphaComponent(0.3)
        }
    }
    
    @IBAction func thumbsUp(sender: AnyObject) {
        self.mainViewController.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
        
        refreshTripUI()
    }
    
    @IBAction func thumbsDown(sender: AnyObject) {
        self.mainViewController.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
        
        refreshTripUI()
    }
    
    @IBAction func bikeButton(sender: AnyObject) {
        self.mainViewController.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
    }
    
    @IBAction func carButton(sender: AnyObject) {
        self.mainViewController.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
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
                })
            })
        } else if (buttonIndex == 2) {
            if (self.mainViewController.selectedTrip.hasSmoothed) {
                self.mainViewController.selectedTrip.undoSmoothWithCompletionHandler({
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
                    })
                })
            } else {
                self.mainViewController.selectedTrip.smoothIfNeeded({
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
                    })
                })
            }
        } else if (buttonIndex == 3) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                self.mainViewController.selectedTrip.sendTripCompletionNotification()
            })
        } else if (buttonIndex == 4) {
            self.mainViewController.selectedTrip.closeTrip()
            
            self.mainViewController.mapViewController.refreshTrip(self.mainViewController.selectedTrip)
        } else if (buttonIndex == 5) {
            self.mainViewController.selectedTrip.syncToServer()
        }
    }

    
    override func performSegueWithIdentifier(identifier: String?, sender: AnyObject?) {
        self.mainViewController = (sender as RoutesViewController).mainViewController
    }

}