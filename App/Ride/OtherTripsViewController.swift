//
//  OtherTripsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


class OtherTripsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    
    var dateOfTripsToShow: NSDate? {
        didSet {
            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                guard let strongSelf = self, let _ = strongSelf.dateOfTripsToShow else {
                    return
                }
                
                strongSelf.loadCoreData()
            }
        }
    }
    
    private var fetchedResultsController : NSFetchedResultsController! = nil
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mma"
        self.timeFormatter.AMSymbol = (self.timeFormatter.AMSymbol as NSString).lowercaseString
        self.timeFormatter.PMSymbol = (self.timeFormatter.PMSymbol as NSString).lowercaseString
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Other Trips", style: .Plain, target: nil, action: nil)
        
        self.tableView.layoutMargins = UIEdgeInsetsZero
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 48
        
        // get rid of empty table view seperators
        self.tableView.tableFooterView = UIView()
        
        self.emptyTableView.hidden = true
        
        loadCoreData()
    }
    
    func loadCoreData() {
        guard let date = self.dateOfTripsToShow else {
            return
        }
        
        guard fetchedResultsController == nil else {
            return
        }
        
        let cacheName = "OtherTripsViewControllerFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.predicate = NSPredicate(format: "activityType != %i AND creationDate > %@ AND creationDate < %@", ActivityType.Cycling.rawValue, date.beginingOfDay(), date.daysFrom(1).beginingOfDay())
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error loading trips view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        
        self.title = "Other trips on " + self.dateFormatter.stringFromDate(date)
                
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
        self.refreshEmptyTableView()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refreshEmptyTableView()
    }
    
    private func refreshEmptyTableView() {
        guard let frc = self.fetchedResultsController else {
            // Core Data hasn't loaded yet
            self.emptyTableView.hidden = true
            return
        }
        
        if let sections = frc.sections where sections.count > 0 && sections[0].numberOfObjects > 0 {
            self.emptyTableView.hidden = true
        } else {
            self.emptyTableView.hidden = false
        }
    }
    
    func unloadFetchedResultsController() {
        self.fetchedResultsController.delegate = nil
        self.fetchedResultsController = nil
    }
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            self.tableView!.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: UITableViewRowAnimation.Fade)
        case .Move, .Update:
            // do nothing
            
            DDLogVerbose("Move/update section. Shouldn't happen?")
        }
    }
    
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        guard let tableView = self.tableView else {
            return
        }
        
        if (APIClient.sharedClient.isMigrating) {
            return
        }
        
        switch(type) {
            
        case .Update:
            let trip = self.fetchedResultsController.objectAtIndexPath(indexPath!) as! Trip
            let cell = tableView.cellForRowAtIndexPath(indexPath!)
            if (cell != nil) {
                configureCell(cell!, trip:trip)
            }
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections!.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.fetchedResultsController.sections!.count == 0 {
            return 0
        }
        
        return self.fetchedResultsController.sections![0].numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let reuseID = "OtherTripsViewControllerCell"
        
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
        
        let trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
        configureCell(tableCell, trip: trip)
        
        return tableCell
    }
    
    func setDisclosureArrowColor(tableCell: UITableViewCell) {
        for case let button as UIButton in tableCell.subviews {
            let image = button.backgroundImageForState(.Normal)?.imageWithRenderingMode(.AlwaysTemplate)
            button.setBackgroundImage(image, forState: .Normal)
        }
    }
    
    func configureCell(tableCell: UITableViewCell, trip: Trip) {
        guard let textLabel = tableCell.viewWithTag(1) as? UILabel, let detailLabel = tableCell.viewWithTag(2) as? UILabel else {
            return
        }
        
        setDisclosureArrowColor(tableCell)
        
        var dateTitle = ""
        if (trip.creationDate != nil) {
            dateTitle = String(format: "%@", self.timeFormatter.stringFromDate(trip.creationDate))
            
        }
        
        let areaDescriptionString = trip.areaDescriptionString
        var description = String(format: "%@ %@ for %@%@.", trip.climacon ?? "", dateTitle, trip.length.distanceString, (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        for reward in trip.tripRewards.array as! [TripReward] {
            if let emoji = reward.displaySafeEmoji where reward.descriptionText.rangeOfString("day ride streak") == nil {
                description += ("\n\n" + emoji + " " + reward.descriptionText)
            }
        }
        
        textLabel.text = description
        detailLabel.text = trip.activityType.emoji
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as? Trip {
            self.performSegueWithIdentifier("showOtherTrip", sender: trip)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "showOtherTrip") {
            if let tripVC = segue.destinationViewController as? TripViewController,
                trip = sender as? Trip {
                tripVC.selectedTrip = trip
            }
        }
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if (indexPath.section == 0) {
            return nil
        }
        
        let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
        if !trip.isClosed {
            return [UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Cancel Trip") { (action, indexPath) -> Void in
                RouteManager.sharedManager.abortTrip()
                }]
        }
        
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete") { (action, indexPath) -> Void in
            APIClient.sharedClient.deleteTrip(trip)
        }
        
        #if DEBUG
            let toolsAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "🐞 Tools") { (action, indexPath) -> Void in
                let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
                self.tableView.setEditing(false, animated: true)
                
                let alertController = UIAlertController(title: "🐞 Tools", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
                alertController.addAction(UIAlertAction(title: "Simulate Ride End", style: UIAlertActionStyle.Default, handler: { (_) in
                    trip.sendTripCompletionNotificationLocally(secondsFromNow:5.0)
                }))
                alertController.addAction(UIAlertAction(title: "Re-Classify", style: UIAlertActionStyle.Default, handler: { (_) in
                    for sensorCollection in trip.sensorDataCollections {
                        RandomForestManager.sharedForest.classify(sensorCollection as! SensorDataCollection)
                    }
                    trip.calculateAggregatePredictedActivityType()
                }))
                alertController.addAction(UIAlertAction(title: "Sync to Health App", style: UIAlertActionStyle.Default, handler: { (_) in
                    let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                    })
                    
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(30 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                        trip.isSavedToHealthKit = false
                        CoreDataManager.sharedManager.saveContext()
                        HealthKitManager.sharedManager.saveOrUpdateTrip(trip) {_ in
                            if (backgroundTaskID != UIBackgroundTaskInvalid) {
                                
                                UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
                            }
                        }
                    })
                }))
                
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Cancel, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            return [deleteAction, toolsAction]
        #else
            return [deleteAction]
        #endif
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
            APIClient.sharedClient.deleteTrip(trip)
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {

        return true
    }
}
