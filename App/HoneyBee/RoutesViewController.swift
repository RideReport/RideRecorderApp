//
//  RoutesViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    var mainViewController: MainViewController! = nil
    
    private var trips : [Trip]! = nil
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.trips = Trip.allTrips() as [Trip]!
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd HH:mm"
    }
    
    override func didMoveToParentViewController(parent: UIViewController?) {
        self.mainViewController = parent as MainViewController
    }
    
    @IBAction func done(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func sync(sender: AnyObject) {
        for trip in Trip.allTrips()! {
            (trip as Trip).syncToServer()
        }
    }
    
    func setSelectedTrip(trip : Trip!) {
        if (trip == nil) {
            return
        }
        
        let index = find(trips, trip)
        if (index == nil) {
            return
        }
        
        self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: index!, inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.Middle)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.trips.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let trip = trips[indexPath.row]
        let reuseID = "RoutesViewTableCell"
        
        var tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID) as UITableViewCell?
        if (tableCell == nil) {
            tableCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: reuseID)
            tableCell?.backgroundColor = UIColor.clearColor()
            tableCell?.detailTextLabel?.textColor = UIColor.whiteColor()
            tableCell?.textLabel.textColor = UIColor.whiteColor()
        }
        if (trip.startDate != nil) {
            var title = NSString(format: "%@ for %i minutes",self.dateFormatter.stringFromDate(trip.startDate), Int(trip.duration())/60)
            if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
                title = title + "👍"
            } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
                title = title + "👎"
            }
            tableCell!.textLabel.text = title
        }
        var tripTypeString = ""
        if (trip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
            tripTypeString = "🚗"
        } else if (trip.activityType.shortValue == Trip.ActivityType.Walking.rawValue) {
            tripTypeString = "🚶"
        } else if (trip.activityType.shortValue == Trip.ActivityType.Running.rawValue) {
            tripTypeString = "🏃"
        } else if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
            tripTypeString = "🚲"
        } else {
            tripTypeString = "Traveled"
        }
        
        tableCell!.detailTextLabel!.text = NSString(format: "%@ %.1f miles",tripTypeString, trip.lengthMiles)


        
        return tableCell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        mainViewController.setSelectedTrip(trips[indexPath.row])
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            let trip : Trip = self.trips[indexPath.row]
            trip.managedObjectContext?.deleteObject(trip)
            CoreDataController.sharedCoreDataController.saveContext()
            
            self.trips = Trip.allTrips() as [Trip]!
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}