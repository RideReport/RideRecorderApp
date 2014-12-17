//
//  RoutesViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    var mainViewController: MainViewController! = nil
    
    private var fetchedResultsController : NSFetchedResultsController! = nil
    
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd HH:mm"
        
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: nil, cacheName: "RoutesViewControllerFetchedResultsControllerCache")
        self.fetchedResultsController.delegate = self
        self.fetchedResultsController.performFetch(nil)
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
        
        let trips = self.fetchedResultsController.fetchedObjects! as [Trip]
        let index = find(trips, trip)
        if (index == nil) {
            return
        }
        
        self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: index!, inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.Middle)
    }
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch(type) {
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Update:
            let trip = self.fetchedResultsController.objectAtIndexPath(indexPath!) as Trip
            configureCell(self.tableView!.cellForRowAtIndexPath(indexPath!)!, trip:trip)
            
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!],
                withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!],
                withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.fetchedResultsController.fetchedObjects!.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as Trip
        let reuseID = "RoutesViewTableCell"
        
        var tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID) as UITableViewCell?
        if (tableCell == nil) {
            tableCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: reuseID)
            tableCell?.backgroundColor = UIColor.clearColor()
            tableCell?.detailTextLabel?.textColor = UIColor.whiteColor()
            tableCell?.textLabel.textColor = UIColor.whiteColor()
        }
        
        configureCell(tableCell!, trip: trip)
        
        return tableCell!
    }
    
    func configureCell(tableCell: UITableViewCell, trip: Trip) {
        if (trip.startDate != nil) {
            var title = NSString(format: "%@ for %i minutes",self.dateFormatter.stringFromDate(trip.startDate), Int(trip.duration())/60)
            if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
                title = title + "👍"
            } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
                title = title + "👎"
            }
            tableCell.textLabel.text = title
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
        
        tableCell.detailTextLabel!.text = NSString(format: "%@ %.1f miles",tripTypeString, trip.lengthMiles)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        mainViewController.setSelectedTrip(self.fetchedResultsController.objectAtIndexPath(indexPath) as Trip)
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as Trip
            trip.managedObjectContext?.deleteObject(trip)
            CoreDataController.sharedCoreDataController.saveContext()
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}