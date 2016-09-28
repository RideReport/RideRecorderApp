//
//  ConnectedAppsViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import ECSlidingViewController
import WatchConnectivity

class ConnectedAppsViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    private var fetchedResultsController : NSFetchedResultsController! = nil

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.coreDataDidLoad()
            }
        } else {
            self.coreDataDidLoad()
        }
    }
    
    func coreDataDidLoad() {
        let cacheName = "ConnectedAppsFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "ConnectedApp")
        fetchedRequest.predicate = NSPredicate(format: "profile != nil")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: nil, cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error loading connected apps view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        self.slidingViewController().anchorRightRevealAmount = 276.0 // the default
        self.slidingViewController().viewDidLayoutSubviews()
        self.tableView.reloadData()
    }
    
    //
    // MARK: - Fetched Results Controller
    //
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch(type) {
            
        case .Update:
            if let path = indexPath, app = self.fetchedResultsController.objectAtIndexPath(path) as? ConnectedApp,
                cell = self.tableView!.cellForRowAtIndexPath(NSIndexPath(forRow: indexPath!.row, inSection: 1)) {
                configureCell(cell, app:app)
            }
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: 1)],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: 1)],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // health kit cell
            return NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup") ? 1 : 0
        } else if section == 1 {
            let sectionInfo = self.fetchedResultsController.sections![0]
            return sectionInfo.numberOfObjects
        } else {
            // conect app cell
            return 1
        }
    }
    
    //
    // MARK: - Table View
    //
    
    func configureCell(tableCell: UITableViewCell, app: ConnectedApp) {
        if let label = tableCell.textLabel {
            label.text = app.name
        }
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            // health kit cell
            let tableCell = self.tableView.dequeueReusableCellWithIdentifier("SyncWithHealthAppCell", forIndexPath: indexPath)
            if #available(iOS 10.0, *) {
                if WatchManager.sharedManager.paired {
                    // if a watch is paired
                    if let nameLabel = tableCell.viewWithTag(1) as? UILabel {
                        nameLabel.text = "Apple Watch"
                    }
                }
            }
            
            return tableCell
        } else if indexPath.section == 1 {
            let tableCell = self.tableView.dequeueReusableCellWithIdentifier("ConnectedAppCell", forIndexPath: indexPath)
            if let app = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: 0)) as? ConnectedApp {
                self.configureCell(tableCell, app: app)
            }
            
            return tableCell
        } else {
            // conect app cell
            return self.tableView.dequeueReusableCellWithIdentifier("ConnectAppCell", forIndexPath: indexPath)
        }
        
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            return
        }
        
        if (indexPath.section == 1) {
            if let app = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: 0)) as? ConnectedApp,
                let appNC = segue.destinationViewController as?  UINavigationController,
                let appVC = appNC.topViewController as? ConnectedAppSettingsViewController {
                appVC.connectingApp = app
            }
        }
    }

}


