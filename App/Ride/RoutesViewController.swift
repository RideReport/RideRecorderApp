//
//  RoutesViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerLabel1: UILabel!
    
    var mainViewController: MainViewController! = nil
    
    
    private var fetchedResultsController : NSFetchedResultsController! = nil

    private var timeFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        
        var headerFrame = self.headerView.frame;
        headerFrame.size.height = 36
        self.headerView.frame = headerFrame
        self.tableView.tableHeaderView = self.headerView
        self.headerView.backgroundColor = UIColor.clearColor()
        
        let count = Trip.numberOfCycledTrips
        if (count == 0) {
            self.title = "No Trips"
            self.headerView.hidden = false
        } else {
            self.title = String(format: "%i Trips ", Trip.numberOfCycledTrips)
            let formatter = NSNumberFormatter()
            formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
            formatter.maximumFractionDigits = 0
            self.headerLabel1.text = String(format: "%@ miles and counting…", formatter.stringFromNumber(NSNumber(float: Trip.totalCycledMiles))!)
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: UIBarButtonItemStyle.Plain, target: self, action: "pop")
        
        let blur = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let effectView = UIVisualEffectView(effect: blur)
        effectView.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        self.view.insertSubview(effectView, belowSubview: self.tableView)
        
        self.tableView.layoutMargins = UIEdgeInsetsZero
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mma"
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                self.coreDataDidLoad()
            }
        } else {
            self.coreDataDidLoad()
        }
    }
    
    func coreDataDidLoad() {
        let cacheName = "RoutesViewControllerFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
        self.fetchedResultsController!.delegate = self
        do {
            try self.fetchedResultsController!.performFetch()
        } catch _ {
        }
        
        self.refreshEmptyTableView()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.mainViewController.selectedTrip = nil
        self.refreshEmptyTableView()
        
        if (self.tableView.indexPathForSelectedRow != nil) {
            self.tableView.deselectRowAtIndexPath(self.tableView.indexPathForSelectedRow!, animated: animated)
        }
    }
    
    private func refreshEmptyTableView() {
        if (self.fetchedResultsController != nil) {
            let shouldHideEmptyTableView = (self.fetchedResultsController.fetchedObjects!.count > 0)
            self.emptyTableView.hidden = shouldHideEmptyTableView
            self.tableView.hidden = !shouldHideEmptyTableView
        } else {
            self.emptyTableView.hidden = true
            self.tableView.hidden = true
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func unloadFetchedResultsController() {
        self.fetchedResultsController?.delegate = nil
        self.fetchedResultsController = nil
    }

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.refreshEmptyTableView()
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
        switch(type) {
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Update:
            let trip = self.fetchedResultsController.objectAtIndexPath(indexPath!) as! Trip
            let cell = self.tableView!.cellForRowAtIndexPath(indexPath!)
            if (cell != nil) {
                configureCell(cell!, trip:trip)
            }
            
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
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let theSection = self.fetchedResultsController.sections![section] 
        
        return "  ".stringByAppendingString(theSection.name)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] 
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
        let reuseID = "RoutesViewTableCell"
        
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath) 
        tableCell.layoutMargins = UIEdgeInsetsZero

        configureCell(tableCell, trip: trip)
        
        return tableCell
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.tintColor = UIColor(white: 0.2, alpha: 1.0)
        headerView.opaque = false
        headerView.textLabel!.font = UIFont.boldSystemFontOfSize(14.0)
        headerView.textLabel!.textColor = UIColor(white: 0.9, alpha: 1.0)
    }
    
    func configureCell(tableCell: UITableViewCell, trip: Trip) {
        var ratingString = "  "
        if (trip.activityType.shortValue != Trip.ActivityType.Cycling.rawValue) {
            // for non-bike trips, show activity type instead of a rating
            ratingString = trip.activityTypeString()
        } else if (trip.incidents != nil && trip.incidents.count > 0) {
            ratingString = "🚩"
        } else if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
            ratingString = "👍"
        } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
            ratingString = "👎"
        }
        
        var dateTitle = ""
        if (trip.startDate != nil) {
            dateTitle = String(format: "%@", self.timeFormatter.stringFromDate(trip.startDate))
            
        }
        tableCell.textLabel!.text = String(format: "%@ %@ %@ for %.1f miles", trip.climoticon,  trip.isSynced ? "" : "🔹", dateTitle, trip.lengthMiles)
        
        tableCell.detailTextLabel!.text = String(format: "%@", ratingString)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.mainViewController.selectedTrip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
        
        self.pop()
    }
    
    func pop() {
        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionReveal
        transition.subtype = kCATransitionFromTop
        
        self.mainViewController.navigationController?.view.layer.addAnimation(transition, forKey: kCATransition)
        self.mainViewController.navigationController?.popToRootViewControllerAnimated(false)
    }

    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete") { (action, indexPath) -> Void in
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
            APIClient.sharedClient.deleteTrip(trip)
        }
        
    #if DEBUG
        let toolsAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "🐞 Tools") { (action, indexPath) -> Void in
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
            self.tableView.setEditing(false, animated: true)
            
            var smoothButtonTitle = ""
            if (trip.hasSmoothed) {
                smoothButtonTitle = "Unsmooth"
            } else {
                smoothButtonTitle = "Smooth"
            }
            
            UIActionSheet.showInView(self.view, withTitle: nil, cancelButtonTitle: nil, destructiveButtonTitle: nil, otherButtonTitles: ["Query Core Motion Acitivities", smoothButtonTitle, "Simulate Ride End", "Close Trip", "Sync to Server", "HealthKit!"], tapBlock: { (actionSheet, tappedIndex) -> Void in
                self.tappedButtonIndex(tappedIndex, trip: trip)
            })
        }
        return [deleteAction, toolsAction]
    #else
        return [deleteAction]
    #endif
    }
    
    func tappedButtonIndex(buttonIndex: Int, trip: Trip) {
        if (buttonIndex == 0) {
            trip.clasifyActivityType({})
        } else if (buttonIndex == 1) {
            if (trip.hasSmoothed) {
                trip.undoSmoothWithCompletionHandler({})
            } else {
                trip.smoothIfNeeded({})
            }
        } else if (buttonIndex == 2) {
            let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            })
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                trip.sendTripCompletionNotification() {
                    if (backgroundTaskID != UIBackgroundTaskInvalid) {
                        UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
                    }
                }
            })
        } else if (buttonIndex == 3) {
            trip.close() {
                APIClient.sharedClient.saveAndSyncTripIfNeeded(trip)
            }
        } else if (buttonIndex == 4) {
            APIClient.sharedClient.saveAndSyncTripIfNeeded(trip)
        } else if (buttonIndex == 5) {
            HealthKitManager.sharedManager.logTrip(trip)
        }
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