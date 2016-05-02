
//
//  ConnectedAppsBrowseViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class ConnectedAppsBrowseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!

    private var fetchedResultsController : NSFetchedResultsController! = nil
    
    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
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
        let cacheName = "ConnectedAppsBrowserFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "ConnectedApp")
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
                cell = self.tableView!.cellForRowAtIndexPath(NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)) {
                configureCell(cell, app:app)
            }
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects + 1
    }
    
    //
    // MARK: - Table View
    //
    
    func configureCell(tableCell: UITableViewCell, app: ConnectedApp) {
        if let nameLabel = tableCell.viewWithTag(1) as? UILabel,
            descriptionLabel = tableCell.viewWithTag(2) as? UILabel,
            imageView = tableCell.viewWithTag(3) as? UIImageView {
            nameLabel.text = app.name
            descriptionLabel.text = app.description
            imageView.image = UIImage(named: "Icon")
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.min
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let tableCell = self.tableView.dequeueReusableCellWithIdentifier("HealthAppCell", forIndexPath: indexPath)
            let priorHealthKitState = NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup")
            tableCell.userInteractionEnabled = !priorHealthKitState
            for view in tableCell.contentView.subviews {
                view.alpha = priorHealthKitState ? 0.5 : 1
            }
            
            return tableCell
        } else {
            let tableCell = self.tableView.dequeueReusableCellWithIdentifier("ConnectedAppCell", forIndexPath: indexPath)
            if let app = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row - 1, inSection: indexPath.section)) as? ConnectedApp {
                self.configureCell(tableCell, app: app)
            }
            return tableCell
        }
    }
    
}