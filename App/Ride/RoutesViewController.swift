//
//  RoutesViewController.swift
//  Ride
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    
    var mainViewController: MainViewController! = nil
    
    
    private var _fetchedResultsController : NSFetchedResultsController? = nil
    private var fetchedResultsController : NSFetchedResultsController  {
        get {
            if (_fetchedResultsController != nil) {
                return _fetchedResultsController!
            }
            
            let cacheName = "RoutesViewControllerFetchedResultsController"
            let context = CoreDataManager.sharedCoreDataManager.currentManagedObjectContext()
            NSFetchedResultsController.deleteCacheWithName(cacheName)
            let fetchedRequest = NSFetchRequest(entityName: "Trip")
            fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            _fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
            _fetchedResultsController!.delegate = self
            _fetchedResultsController!.performFetch(nil)
            
            return _fetchedResultsController!
        }
    }

    private var timeFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Rides"
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        var blur = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        var effectView = UIVisualEffectView(effect: blur)
        effectView.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        self.view.insertSubview(effectView, belowSubview: self.tableView)
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.layoutMargins = UIEdgeInsetsZero
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mma"
    }
    
    @IBAction func done(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        (segue.destinationViewController as RouteDetailViewController).mainViewController = self.mainViewController
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
        self.mainViewController.setSelectedTrip(nil, sender:self)
        self.refreshEmptyTableView()
        
        if (self.tableView.indexPathForSelectedRow() != nil) {
            self.tableView.deselectRowAtIndexPath(self.tableView.indexPathForSelectedRow()!, animated: animated)
        }
    }
    
    private func refreshEmptyTableView() {
        let shouldHideEmptyTableView = (self.fetchedResultsController.fetchedObjects!.count > 0)
        self.emptyTableView.hidden = shouldHideEmptyTableView
        self.tableView.hidden = !shouldHideEmptyTableView
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.unloadFetchedResultsController()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    func unloadFetchedResultsController() {
        _fetchedResultsController?.delegate = nil
        _fetchedResultsController = nil
    }
    
    func setSelectedTrip(trip : Trip!) {
        if (trip != nil) {
            if (self.navigationController?.topViewController != self) {
                (self.navigationController?.topViewController as RouteDetailViewController).refreshTripUI()
            } else {
                self.performSegueWithIdentifier("routeSelectedSegue", sender: self)
            }
        }
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
            DDLogWrapper.logVerbose("Move/update section. Shouldn't happen?")
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch(type) {
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Update:
            let trip = self.fetchedResultsController.objectAtIndexPath(indexPath!) as Trip
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
        let theSection = self.fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
        
        return "  ".stringByAppendingString(theSection.name!)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as Trip
        let reuseID = "RoutesViewTableCell"
        
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath) as UITableViewCell
        tableCell.layoutMargins = UIEdgeInsetsZero

        configureCell(tableCell, trip: trip)
        
        return tableCell
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as UITableViewHeaderFooterView
        headerView.tintColor = UIColor(white: 0.2, alpha: 1.0)
        headerView.opaque = false
        headerView.textLabel.font = UIFont.boldSystemFontOfSize(14.0)
        headerView.textLabel.textColor = UIColor(white: 0.9, alpha: 1.0)
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
            dateTitle = NSString(format: "%@", self.timeFormatter.stringFromDate(trip.startDate))
            
        }
        tableCell.textLabel!.text = NSString(format: "%@ %@ for %.1f miles", trip.isSynced ? "" : "🔹", dateTitle, trip.lengthMiles)
        
        tableCell.detailTextLabel!.text = NSString(format: "%@", ratingString)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.mainViewController.setSelectedTrip(self.fetchedResultsController.objectAtIndexPath(indexPath) as Trip, sender:self)
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as Trip
            trip.managedObjectContext?.deleteObject(trip)
            NetworkManager.sharedManager.saveAndSyncTripIfNeeded(trip)
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}