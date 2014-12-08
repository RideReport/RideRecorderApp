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
    
    @IBAction func done(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
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
        }
        if (trip.startDate != nil) {
            let title = NSString(format: "%@, %i minutes",self.dateFormatter.stringFromDate(trip.startDate), Int(trip.duration())/60)
            tableCell!.textLabel.text = title
        }
        if (trip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
            tableCell!.detailTextLabel!.text = "Automotive"
            tableCell!.detailTextLabel!.textColor = UIColor.redColor()
        } else if (trip.activityType.shortValue == Trip.ActivityType.Walking.rawValue) {
            tableCell!.detailTextLabel!.text = "Walking"
            tableCell!.detailTextLabel!.textColor = UIColor.yellowColor()
        } else if (trip.activityType.shortValue == Trip.ActivityType.Running.rawValue) {
            tableCell!.detailTextLabel!.text = "Running"
            tableCell!.detailTextLabel!.textColor = UIColor.orangeColor()
        } else if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
            tableCell!.detailTextLabel!.text = "Biking"
            tableCell!.detailTextLabel!.textColor = UIColor.greenColor()
        } else {
            tableCell!.detailTextLabel!.text = "Uncategorized"
            tableCell!.detailTextLabel!.textColor = UIColor.grayColor()
        }

        
        return tableCell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let viewController = (self.presentingViewController as UINavigationController).topViewController
        if (viewController != nil && viewController!.isKindOfClass(ViewController)) {
            (viewController as ViewController).setSelectedTrip(trips[indexPath.row])
        }
        
        self.dismissViewControllerAnimated(true, completion: nil)
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