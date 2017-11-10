//
//  ConnectedAppsViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import WatchConnectivity
import CocoaLumberjack

class ConnectedAppsViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    private var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>?

    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        if (CoreDataManager.shared.isStartingUp) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: cacheName)
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ConnectedApp")
        fetchedRequest.predicate = NSPredicate(format: "profile != nil")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController<NSFetchRequestResult>(fetchRequest:fetchedRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName:cacheName )
        self.fetchedResultsController!.delegate = self
        do {
            try self.fetchedResultsController!.performFetch()
        } catch let error {
            DDLogError("Error loading connected apps view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }
    
    //
    // MARK: - Fetched Results Controller
    //
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let frc = self.fetchedResultsController else {
            return
        }
        
        switch(type) {
            
        case .update:
            if let path = indexPath, let app = frc.object(at: path) as? ConnectedApp,
                let cell = self.tableView!.cellForRow(at: IndexPath(row: indexPath!.row, section: 0)) {
                configureCell(cell, app:app)
            }
        case .insert:
            self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: 0)], with: UITableViewRowAnimation.fade)
        case .delete:
            self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: 0)], with: UITableViewRowAnimation.fade)
        case .move:
            self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: 0)],
                                                   with: UITableViewRowAnimation.fade)
            self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: 0)],
                                                   with: UITableViewRowAnimation.fade)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let frc = self.fetchedResultsController, let sections = frc.sections else {
            return 0
        }
        
        let sectionInfo = sections[0]
        return sectionInfo.numberOfObjects + 1 + (UserDefaults.standard.bool(forKey: "healthKitIsSetup") ? 1 : 0)
    }
    
    //
    // MARK: - Table View
    //
    
    func configureCell(_ tableCell: UITableViewCell, app: ConnectedApp) {
        if let label = tableCell.textLabel {
            label.text = app.name
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let frc = self.fetchedResultsController else {
            return self.tableView.dequeueReusableCell(withIdentifier: "ConnectAppCell", for: indexPath)
        }
        
        let healthKitRowCount = UserDefaults.standard.bool(forKey: "healthKitIsSetup") ? 1 : 0
        let frcRowCount = (self.fetchedResultsController?.fetchedObjects?.count ?? 0)
        
        if healthKitRowCount > 0 && indexPath.row + 1 == frcRowCount + healthKitRowCount {
            // health kit cell
            let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "SyncWithHealthAppCell", for: indexPath)
            if #available(iOS 10.0, *) {
                if WatchManager.shared.paired {
                    // if a watch is paired
                    if let nameLabel = tableCell.viewWithTag(1) as? UILabel {
                        nameLabel.text = "Apple Watch"
                    }
                }
            }
            
            return tableCell
        } else if indexPath.row >= frcRowCount + healthKitRowCount {
            // conect app cell
            return self.tableView.dequeueReusableCell(withIdentifier: "ConnectAppCell", for: indexPath)
        } else {
            let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "ConnectedAppCell", for: indexPath)
            if let app = frc.object(at: IndexPath(row: indexPath.row, section: 0)) as? ConnectedApp {
                self.configureCell(tableCell, app: app)
            }
            
            return tableCell
        }
        
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let frc = self.fetchedResultsController else {
            return
        }
        
        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            return
        }
        
        if (indexPath.row < self.fetchedResultsController?.fetchedObjects?.count ?? 0) {
            if let app = frc.object(at: IndexPath(row: indexPath.row, section: 0)) as? ConnectedApp,
                let appVC = segue.destination as?  ConnectedAppSettingsViewController {
                appVC.connectingApp = app
            }
        }
    }

}


