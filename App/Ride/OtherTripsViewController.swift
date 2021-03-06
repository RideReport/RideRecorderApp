//
//  OtherTripsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import RouteRecorder
import CocoaLumberjack

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
        self.tableView.rowHeight = UITableView.automaticDimension
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
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger != %i AND startDate > %@ AND startDate < %@", ActivityType.cycling.rawValue, date.beginingOfDay() as CVarArg, date.daysFrom(1).beginingOfDay() as CVarArg)
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: nil, cacheName:cacheName )
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
        
        if let navVC = self.navigationController {
            navVC.setNavigationBarHidden(false, animated: animated)
        }
        
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
            self.tableView!.insertSections(IndexSet(integer: sectionIndex), with: UITableView.RowAnimation.fade)
        case .delete:
            self.tableView!.deleteSections(IndexSet(integer: sectionIndex), with: UITableView.RowAnimation.fade)
        case .move, .update:
            // do nothing
            
            DDLogVerbose("Move/update section. Shouldn't happen?")
        }
    }
    
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let tableView = self.tableView else {
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
            self.tableView!.insertRows(at: [newIndexPath!], with: UITableView.RowAnimation.fade)
        case .delete:
            self.tableView!.deleteRows(at: [indexPath!], with: UITableView.RowAnimation.fade)
        case .move:
            self.tableView!.deleteRows(at: [indexPath!],
                                       with: UITableView.RowAnimation.fade)
            self.tableView!.insertRows(at: [newIndexPath!],
                                       with: UITableView.RowAnimation.fade)
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
            let image = button.backgroundImage(for: UIControl.State())?.withRenderingMode(.alwaysTemplate)
            button.setBackgroundImage(image, for: UIControl.State())
        }
    }
    
    func configureCell(_ tableCell: UITableViewCell, trip: Trip) {
        guard let textLabel = tableCell.viewWithTag(1) as? UILabel, let detailLabel = tableCell.viewWithTag(2) as? UILabel else {
            return
        }
        
        setDisclosureArrowColor(tableCell)
        
        let dateTitle = String(format: "%@", self.timeFormatter.string(from: trip.startDate))

        if trip.isInProgress {
            textLabel.text = String(format: "In Progress trip started at %@.", trip.timeString())
        } else {
            let areaDescriptionString = trip.areaDescriptionString
            textLabel.text = String(format: "%@ %@ for %@%@.", trip.climacon ?? "", dateTitle, trip.length.distanceString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        }

        
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
        if trip.isInProgress {
            return [UITableViewRowAction(style: UITableViewRowAction.Style.default, title: "End Trip") { (action, indexPath) -> Void in
                RouteRecorder.shared.routeManager.stopRoute()
                }]
        }
        
        let deleteAction = UITableViewRowAction(style: UITableViewRowAction.Style.default, title: "Delete") { (action, indexPath) -> Void in
            let alertController = UIAlertController(title: "Delete Trip?", message: "This will permanently delete your trip", preferredStyle: .actionSheet)
            
            let deleteAlertAction = UIAlertAction(title: "Delete", style: .destructive) { (_) in
                trip.managedObjectContext?.delete(trip)
                CoreDataManager.shared.saveContext()
            }
            let cancelAlertAction = UIAlertAction(title: "Cancel", style: .cancel) {(_) in }
            
            alertController.addAction(deleteAlertAction)
            alertController.addAction(cancelAlertAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
        
        #if DEBUG
        let toolsAction = UITableViewRowAction(style: UITableViewRowAction.Style.normal, title: "🐞 Tools") { (action, indexPath) -> Void in
                let trip : Trip = self.fetchedResultsController.object(at: indexPath) as! Trip
                self.tableView.setEditing(false, animated: true)
                
            let alertController = UIAlertController(title: "🐞 Tools", message: nil, preferredStyle: UIAlertController.Style.actionSheet)
//                alertController.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.default, handler: { (_) in
//                    trip.isClosed = false
//                    trip.close()
//                }))
//                alertController.addAction(UIAlertAction(title: "Simulate Ride End", style: UIAlertActionStyle.default, handler: { (_) in
//                    trip.sendTripCompletionNotificationLocally(secondsFromNow:5.0)
//                }))
//                alertController.addAction(UIAlertAction(title: "Re-Classify", style: UIAlertActionStyle.default, handler: { (_) in
//                    for prediction in trip.predictionAggregators {
//                        //RouteRecorder.shared.randomForestManager.classify(prediction)
//                    }
//                    //trip.calculateAggregatePredictedActivityType()
//                }))
            alertController.addAction(UIAlertAction(title: "Sync to Health App", style: UIAlertAction.Style.default, handler: { (_) in
                var backgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
                    backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = UIBackgroundTaskIdentifier.invalid

                    })
                    
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { () -> Void in
                        trip.isSavedToHealthKit = false
                        CoreDataManager.shared.saveContext()
                        HealthKitManager.shared.saveOrUpdateTrip(trip) {_ in
                            if (backgroundTaskID != UIBackgroundTaskIdentifier.invalid) {
                                
                                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                            }
                        }
                    }
                }))
                
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
            return [deleteAction, toolsAction]
        #else
            return [deleteAction]
        #endif
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
