//
//  RouteIncidentsViewController.swift
//  Ride
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class RouteIncidentsViewController: UITableViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    var mainViewController: MainViewController! = nil
    
    private var fetchedResultsController : NSFetchedResultsController! = nil
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        self.title = "Incidents"
        
        self.view.backgroundColor = UIColor.clearColor()
        
        var blur = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        var effectView = UIVisualEffectView(effect: blur)
        effectView.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        self.view.addSubview(effectView)
        self.view.sendSubviewToBack(effectView)
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
        
        let cacheName = "RouteIncidentsViewController"
        let context = CoreDataManager.sharedCoreDataManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "Incident")
        fetchedRequest.predicate = NSPredicate(format: "trip = %@", self.mainViewController.selectedTrip)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: nil, cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        self.fetchedResultsController.performFetch(nil)
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.layoutMargins = UIEdgeInsetsZero
        
        let toolsButton = UIBarButtonItem(title: "New", style: UIBarButtonItemStyle.Bordered, target: self, action: "newIncident:")
        self.navigationItem.rightBarButtonItem = toolsButton
        
        super.viewDidLoad()
    }
    
    @IBAction func newIncident(sender: AnyObject) {
        let incident = Incident(location: self.mainViewController.selectedTrip.mostRecentLocation()!, trip: self.mainViewController.selectedTrip)
        CoreDataManager.sharedCoreDataManager.saveContext()
        self.mainViewController.refreshSelectrTrip()
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
            let incident = self.fetchedResultsController.objectAtIndexPath(indexPath!) as! Incident
            let cell = self.tableView!.cellForRowAtIndexPath(indexPath!)
            if (cell != nil) {
                configureCell(cell!, incident: incident)
            }
            
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!],
                withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!],
                withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.fetchedResultsController.fetchedObjects!.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let incident = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Incident
        let reuseID = "RouteIncidentsTableCell"
        
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath) as! UITableViewCell
        tableCell.layoutMargins = UIEdgeInsetsZero

        configureCell(tableCell, incident: incident)
        
        return tableCell
    }
    
    func configureCell(tableCell: UITableViewCell, incident: Incident) {
        tableCell.textLabel!.text = Incident.IncidentType(rawValue: incident.type.integerValue)!.text
        
        var dateTitle = ""
        if (incident.creationDate != nil) {
            var dateString = ""
            if (incident.creationDate.isToday()) {
                dateString = ""
            } else if (incident.creationDate.isYesterday()) {
                dateString = "Yesterday at"
            } else if (incident.creationDate.isThisWeek()) {
                dateString = incident.creationDate.weekDay() + " at"
            } else {
                dateString = self.dateFormatter.stringFromDate(incident.creationDate) + " at"
            }
            
            dateTitle = String(format: "%@ %@", dateString, self.timeFormatter.stringFromDate(incident.creationDate))
            tableCell.detailTextLabel!.text = dateTitle
        } else {
            tableCell.detailTextLabel!.text = "Sometime"
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let incident = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Incident
        
        self.mainViewController.performSegueWithIdentifier("presentIncidentEditor", sender: incident)
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            let incident : Incident = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Incident
            incident.managedObjectContext?.deleteObject(incident)
            if (incident.trip != nil) {
                NetworkManager.sharedManager.saveAndSyncTripIfNeeded(incident.trip!)
            }
            self.mainViewController.refreshSelectrTrip()
        }
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}