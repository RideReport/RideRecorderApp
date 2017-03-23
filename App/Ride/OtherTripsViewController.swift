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
    
    var dateOfTripsToShow: Date? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self, let _ = strongSelf.dateOfTripsToShow else {
                    return
                }
                
                strongSelf.loadCoreData()
            }
        }
    }
    
    private var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>!
    
    private var timeFormatter : DateFormatter!
    private var dateFormatter : DateFormatter!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.timeFormatter = DateFormatter()
        self.timeFormatter.locale = Locale.current
        self.timeFormatter.dateFormat = "h:mma"
        self.timeFormatter.amSymbol = (self.timeFormatter.amSymbol as NSString).lowercased
        self.timeFormatter.pmSymbol = (self.timeFormatter.pmSymbol as NSString).lowercased
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Other Trips", style: .plain, target: nil, action: nil)
        
        self.tableView.layoutMargins = UIEdgeInsets.zero
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 48
        
        // get rid of empty table view seperators
        self.tableView.tableFooterView = UIView()
        
        self.emptyTableView.isHidden = true
        
        loadCoreData()
    }
    
    func loadCoreData() {
        guard let date = self.dateOfTripsToShow else {
            return
        }
        
        guard fetchedResultsController == nil else {
            return
        }
        
        guard tableView != nil else {
            return
        }
        
        let cacheName = "OtherTripsViewControllerFetchedResultsController"
        let context = CoreDataManager.shared.currentManagedObjectContext()
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: cacheName)
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.predicate = NSPredicate(format: "isClosed = YES AND activityType != %i AND creationDate > %@ AND creationDate < %@", ActivityType.cycling.rawValue, date.beginingOfDay() as CVarArg, date.daysFrom(1).beginingOfDay() as CVarArg)
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error loading trips view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            _ = self.navigationController?.popViewController(animated: true)
        }
        
        self.title = "Other trips on " + self.dateFormatter.string(from: date)
                
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
        self.refreshEmptyTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refreshEmptyTableView()
    }
    
    private func refreshEmptyTableView() {
        guard let frc = self.fetchedResultsController else {
            // Core Data hasn't loaded yet
            self.emptyTableView.isHidden = true
            return
        }
        
        if let sections = frc.sections, sections.count > 0 && sections[0].numberOfObjects > 0 {
            self.emptyTableView.isHidden = true
        } else {
            self.emptyTableView.isHidden = false
        }
    }
    
    func unloadFetchedResultsController() {
        self.fetchedResultsController.delegate = nil
        self.fetchedResultsController = nil
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView!.insertSections(IndexSet(integer: sectionIndex), with: UITableViewRowAnimation.fade)
        case .delete:
            self.tableView!.deleteSections(IndexSet(integer: sectionIndex), with: UITableViewRowAnimation.fade)
        case .move, .update:
            // do nothing
            
            DDLogVerbose("Move/update section. Shouldn't happen?")
        }
    }
    
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let tableView = self.tableView else {
            return
        }
        
        if (APIClient.shared.isMigrating) {
            return
        }
        
        switch(type) {
            
        case .update:
            let trip = self.fetchedResultsController.object(at: indexPath!) as! Trip
            let cell = tableView.cellForRow(at: indexPath!)
            if (cell != nil) {
                configureCell(cell!, trip:trip)
            }
            
        case .insert:
            self.tableView!.insertRows(at: [newIndexPath!], with: UITableViewRowAnimation.fade)
        case .delete:
            self.tableView!.deleteRows(at: [indexPath!], with: UITableViewRowAnimation.fade)
        case .move:
            self.tableView!.deleteRows(at: [indexPath!],
                                       with: UITableViewRowAnimation.fade)
            self.tableView!.insertRows(at: [newIndexPath!],
                                       with: UITableViewRowAnimation.fade)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections!.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.fetchedResultsController.sections!.count == 0 {
            return 0
        }
        
        return self.fetchedResultsController.sections![0].numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "OtherTripsViewControllerCell"
        
        let tableCell = self.tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath)
        
        let trip = self.fetchedResultsController.object(at: indexPath) as! Trip
        configureCell(tableCell, trip: trip)
        
        return tableCell
    }
    
    func setDisclosureArrowColor(_ tableCell: UITableViewCell) {
        for case let button as UIButton in tableCell.subviews {
            let image = button.backgroundImage(for: UIControlState())?.withRenderingMode(.alwaysTemplate)
            button.setBackgroundImage(image, for: UIControlState())
        }
    }
    
    func configureCell(_ tableCell: UITableViewCell, trip: Trip) {
        guard let textLabel = tableCell.viewWithTag(1) as? UILabel, let detailLabel = tableCell.viewWithTag(2) as? UILabel else {
            return
        }
        
        setDisclosureArrowColor(tableCell)
        
        var dateTitle = ""
        if (trip.creationDate != nil) {
            dateTitle = String(format: "%@", self.timeFormatter.string(from: trip.creationDate))
            
        }
        
        let areaDescriptionString = trip.areaDescriptionString
        var description = String(format: "%@ %@ for %@%@.", trip.climacon ?? "", dateTitle, trip.length.distanceString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        for reward in trip.tripRewards.array as! [TripReward] {
            if let emoji = reward.displaySafeEmoji, reward.descriptionText.range(of: "day ride streak") == nil {
                description += ("\n\n" + emoji + " " + reward.descriptionText)
            }
        }
        
        textLabel.text = description
        detailLabel.text = trip.activityType.emoji
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let trip = self.fetchedResultsController.object(at: indexPath) as? Trip {
            self.performSegue(withIdentifier: "showOtherTrip", sender: trip)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showOtherTrip") {
            if let tripVC = segue.destination as? TripViewController,
                let trip = sender as? Trip {
                tripVC.selectedTrip = trip
            }
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let trip : Trip = self.fetchedResultsController.object(at: indexPath) as! Trip
        if !trip.isClosed {
            return [UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Cancel Trip") { (action, indexPath) -> Void in
                RouteManager.shared.abortTrip()
                }]
        }
        
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Delete") { (action, indexPath) -> Void in
            APIClient.shared.deleteTrip(trip)
        }
        
        #if DEBUG
            let toolsAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "🐞 Tools") { (action, indexPath) -> Void in
                let trip : Trip = self.fetchedResultsController.object(at: indexPath) as! Trip
                self.tableView.setEditing(false, animated: true)
                
                let alertController = UIAlertController(title: "🐞 Tools", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
                alertController.addAction(UIAlertAction(title: "Simulate Ride End", style: UIAlertActionStyle.default, handler: { (_) in
                    trip.sendTripCompletionNotificationLocally(secondsFromNow:5.0)
                }))
                alertController.addAction(UIAlertAction(title: "Simulate Ride End", style: UIAlertActionStyle.default, handler: { (_) in
                    trip.sendTripCompletionNotificationLocally(secondsFromNow:5.0)
                }))
                alertController.addAction(UIAlertAction(title: "Re-Classify", style: UIAlertActionStyle.default, handler: { (_) in
                    for sensorCollection in trip.sensorDataCollections {
                        RandomForestManager.shared.classify(sensorCollection as! SensorDataCollection)
                    }
                    trip.calculateAggregatePredictedActivityType()
                }))
                alertController.addAction(UIAlertAction(title: "Sync to Health App", style: UIAlertActionStyle.default, handler: { (_) in
                    let backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    })
                    
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { () -> Void in
                        trip.isSavedToHealthKit = false
                        CoreDataManager.shared.saveContext()
                        HealthKitManager.shared.saveOrUpdateTrip(trip) {_ in
                            if (backgroundTaskID != UIBackgroundTaskInvalid) {
                                
                                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                            }
                        }
                    }
                }))
                
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
            return [deleteAction, toolsAction]
        #else
            return [deleteAction]
        #endif
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            let trip : Trip = self.fetchedResultsController.object(at: indexPath) as! Trip
            APIClient.shared.deleteTrip(trip)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
