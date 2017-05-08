//
//  TripsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import SystemConfiguration
import Presentr

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}



class TripsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, RideSummaryViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    @IBOutlet weak var emptyTableChick: UIView!
    
    @IBOutlet weak var popupView: PopupView!
    
    private var dateOfLastTableRefresh: Date?

    private var reachability : Reachability!
    
    private var cellToReAnimateOnAppActivate: UITableViewCell?
    private var shouldShowStreakAnimation = false
    private var shouldShowRewardsAnimation = true
    
    private var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>!

    private var dateFormatter : DateFormatter!
    private var yearDateFormatter : DateFormatter!
    private var rewardSectionNeedsReload : Bool = false
    private var sectionNeedingReloadAfterUpdates : Int = -1
    private var sectionHeaderNeedingReloadAfterUpdates : Int = -1
    private var sectionChangeType : NSFetchedResultsChangeType? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Rides", style: .plain, target: nil, action: nil)
        
        self.popupView.isHidden = true
        
        self.tableView.layoutMargins = UIEdgeInsets.zero
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 48
        
        // when the user drags up they should see the right color above the rewards cell
        var headerViewBackgroundViewFrame = self.tableView.bounds
        headerViewBackgroundViewFrame.origin.y = -headerViewBackgroundViewFrame.size.height
        let headerViewBackgroundView = UIView(frame: headerViewBackgroundViewFrame)
        headerViewBackgroundView.backgroundColor = ColorPallete.shared.almostWhite
        self.tableView.insertSubview(headerViewBackgroundView, at: 0)
        
        self.tableView.register(RoutesTableViewHeaderCell.self, forHeaderFooterViewReuseIdentifier: "RoutesViewTableSectionHeaderCell")
        
        // get rid of empty table view seperators
        self.tableView.tableFooterView = UIView()
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d"
        
        self.yearDateFormatter = DateFormatter()
        self.yearDateFormatter.locale = Locale.current
        self.yearDateFormatter.dateFormat = "MMM d ''yy"
        
        self.emptyTableView.isHidden = true
        
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
    
    private func loadFetchedResultsController() {
        guard self.fetchedResultsController == nil else {
            return
        }
        
        let cacheName = "TripsViewControllerFetchedResultsController"
        let context = CoreDataManager.shared.currentManagedObjectContext()
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: cacheName)
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.fetchBatchSize = 20
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "sectionIdentifier", ascending: false), NSSortDescriptor(key: "creationDate", ascending: false)]

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error loading trips view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
    }
    
    func coreDataDidLoad() {
        self.reloadSectionIdentifiersIfNeeded()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        loadFetchedResultsController()
        
        self.refreshEmptyTableView()
        
        self.tableView.reloadData()
        self.dateOfLastTableRefresh = Date()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) {[weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reloadSectionIdentifiersIfNeeded()
            strongSelf.loadFetchedResultsController()
            
            strongSelf.refreshHelperPopupUI()
            strongSelf.tableView.reloadData()
            
            let firstTripIndex = IndexPath(row: 0, section: 1)
            if let currentTableCell = strongSelf.tableView.cellForRow(at: firstTripIndex) {
                if let oldTableCell = strongSelf.cellToReAnimateOnAppActivate,
                    let rideSummaryView = currentTableCell.viewWithTag(1) as? RideSummaryView, oldTableCell != currentTableCell {
                    // if the old first cell is no longer first, we need to re-show the rewards in the old first cell
                    rideSummaryView.showRewards()
                    
                }
                strongSelf.cellToReAnimateOnAppActivate = nil
                
                strongSelf.shouldShowRewardsAnimation = true
                strongSelf.tableView.reloadRows(at: [firstTripIndex], with: .none)
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil) { [weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            
            let firstTripIndex = IndexPath(row: 0, section: 1)
            if let tableCell = strongSelf.tableView.cellForRow(at: firstTripIndex),
                let rideSummaryView = tableCell.viewWithTag(1) as? RideSummaryView {
                rideSummaryView.hideRewards()
                strongSelf.cellToReAnimateOnAppActivate = tableCell
            }
            
            strongSelf.fetchedResultsController.delegate = nil
            strongSelf.fetchedResultsController = nil
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "APIClientStatusTextDidChange"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.refreshHeaderCells()
        }
        
        if APIClient.shared.accountVerificationStatus != .unknown {
            self.runCreateAccountOfferIfNeeded()
        } else {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "APIClientAccountStatusDidChange"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "APIClientAccountStatusDidChange"), object: nil)
                strongSelf.runCreateAccountOfferIfNeeded()
            }
        }
    }
    
    private func runCreateAccountOfferIfNeeded() {
        if (APIClient.shared.accountVerificationStatus == .unverified) {

            if (Trip.numberOfCycledTrips > 10 && !UserDefaults.standard.bool(forKey: "hasBeenOfferedCreateAccountAfter10Trips")) {
                UserDefaults.standard.set(true, forKey: "hasBeenOfferedCreateAccountAfter10Trips")
                UserDefaults.standard.synchronize()
                let alertController = UIAlertController(title: "Don't lose your trips!", message: "Create an account so you can recover your rides if your phone is lost.", preferredStyle: UIAlertControllerStyle.actionSheet)
                alertController.addAction(UIAlertAction(title: "Create Account", style: UIAlertActionStyle.default, handler: { (_) in
                    AppDelegate.appDelegate().transitionToCreatProfile()
                }))
                
                alertController.addAction(UIAlertAction(title: "Nope", style: UIAlertActionStyle.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let shouldGetTripsOnNextAppForeground = UserDefaults.standard.bool(forKey: "shouldGetTripsOnNextAppForeground")
        if shouldGetTripsOnNextAppForeground {
            UserDefaults.standard.set(false, forKey: "shouldGetTripsOnNextAppForeground")
            UserDefaults.standard.synchronize()
            APIClient.shared.getAllTrips()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.refreshEmptyTableView()
        
        self.refreshHelperPopupUI()
        
        self.refreshHeaderCells()
        
        
        self.reachability = Reachability.forLocalWiFi()
        self.reachability.startNotifier()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.reachabilityChanged, object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.refreshHelperPopupUI()
        }
        
        if (self.tableView.indexPathForSelectedRow != nil) {
            self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: animated)
        }
        
        if (CoreDataManager.shared.isStartingUp) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.refreshTitle()
            }
        } else {
            self.refreshTitle()
        }
    }
    
    func refreshHeaderCells() {
        // only support one promo for now
        if let promo = Profile.profile().eligibilePromotion() {
            self.shouldShowStreakAnimation = true
            if let app = promo.connectedApp {
                // if we need to, fetch the app.
                APIClient.shared.getApplication(app)
            }
            
            if let promoCell = self.tableView!.cellForRow(at: IndexPath(row: 0, section: 0)) {
                if promoCell.reuseIdentifier == "PromoViewTableCell" {
                    self.configurePromoCell(promoCell, promotion: promo)
                } else {
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
                }
            }
        } else {
            self.shouldShowStreakAnimation = true
            if let rewardsCell = self.tableView!.cellForRow(at: IndexPath(row: 0, section: 0)) {
                if rewardsCell.reuseIdentifier == "RewardsViewTableCell" {
                    self.configureRewardsCell(rewardsCell)
                }
                else {
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
                }
            }
        }

    }
    
    func bobbleView(_ view: UIView) {
        CATransaction.begin()
        
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        //let rotationOffsets = [M_PI, -M_PI_2, -0.2, 0.2, -0.2, 0.2, -0.2, 0.2, 0.0]
        shakeAnimation.values = [
            NSValue(caTransform3D:CATransform3DMakeRotation(10 * CGFloat(CGFloat.pi/180), 0, 0, -1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(-10 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(6 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(-6 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(2 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(-2 * CGFloat(CGFloat.pi/180), 0, 0, 1))
        ]
        shakeAnimation.keyTimes = [0, 0.2, 0.4, 0.65, 0.8, 1]
        shakeAnimation.isAdditive = true
        shakeAnimation.duration = 0.6
        
        view.layer.add(shakeAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.reachability = nil
    }
    
    func launchPermissions() {
        if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
            UIApplication.shared.openURL(appSettings)
        }
    }
    
    func resumeRideReport() {
        RouteManager.shared.resumeTracking()
        refreshHelperPopupUI()
    }
    
    
    func refreshHelperPopupUI() {
        popupView.removeTarget(self, action: nil, for: UIControlEvents.allEvents)
        
        if (RouteManager.shared.isPaused()) {
            if (self.popupView.isHidden) {
                self.popupView.popIn()
            }
            if (RouteManager.shared.isPausedDueToUnauthorized()) {
                self.popupView.text = "Ride Report needs permission to run"
                popupView.addTarget(self, action: #selector(TripsViewController.launchPermissions), for: UIControlEvents.touchUpInside)
            } else if (RouteManager.shared.isPausedDueToBatteryLife()) {
                self.popupView.text = "Ride Report is paused until you charge your phone"
            } else {
                popupView.addTarget(self, action: #selector(TripsViewController.resumeRideReport), for: UIControlEvents.touchUpInside)
                
                if let pausedUntilDate = RouteManager.shared.pausedUntilDate() {
                    if (pausedUntilDate.isToday()) {
                        self.popupView.text = "Ride Report is paused until " + Trip.timeDateFormatter.string(from: pausedUntilDate)
                    } else if (pausedUntilDate.isTomorrow()) {
                        self.popupView.text = "Ride Report is paused until tomorrow"
                    } else if (pausedUntilDate.isThisWeek()) {
                        self.popupView.text = "Ride Report is paused until " + pausedUntilDate.weekDay()
                    } else {
                        self.popupView.text = "Ride Report is paused until " + self.dateFormatter.string(from: pausedUntilDate as Date)
                    }
                } else {
                    self.popupView.text = "Ride Report is paused"
                }
            }
        } else {
            if (!UIDevice.current.isWiFiEnabled) {
                if (self.popupView.isHidden) {
                    self.popupView.popIn()
                }
                self.popupView.text = "Ride Report works best when Wi-Fi is on"
            } else if (!self.popupView.isHidden) {
                self.popupView.fadeOut()
            }
        }
    }
    
    private func reloadSectionIdentifiersIfNeeded() {
        if let date = self.dateOfLastTableRefresh, date.isToday() {
            // don't refresh if we've already done it today
        } else {
            // refresh to prevent section headers from getting out of date.
            self.dateOfLastTableRefresh = Date()
            
            let hasRunTripsSectionIdentifiersMigration = UserDefaults.standard.bool(forKey: "hasRunTripsSectionIdentifiersMigration")
            if (!hasRunTripsSectionIdentifiersMigration) {
                UserDefaults.standard.set(true, forKey: "hasRunTripsSectionIdentifiersMigration")
                UserDefaults.standard.synchronize()
            }
            
            // if we haven't run the migration, do an exhaustive reload
            Trip.reloadSectionIdentifiers(!hasRunTripsSectionIdentifiersMigration)
        }
        
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
    
    private func refreshTitle() {
        self.title = "Ride Report"
    }
    
    func unloadFetchedResultsController() {
        self.fetchedResultsController.delegate = nil
        self.fetchedResultsController = nil
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if (APIClient.shared.isMigrating) {
            return
        }
        
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if (APIClient.shared.isMigrating) {
            return
        }
        
        self.tableView.endUpdates()
        
        self.refreshEmptyTableView()
        self.refreshTitle()
        
        self.sectionChangeType = nil
        
        if (sectionNeedingReloadAfterUpdates != -1) {
            // reload both the section and the other trips section following, if it exists
            self.tableView!.reloadSections(IndexSet(integer: sectionNeedingReloadAfterUpdates), with: .fade)
            
            if sectionNeedingReloadAfterUpdates < self.fetchedResultsController.sections?.count {
                self.tableView!.reloadSections(IndexSet(integer: sectionNeedingReloadAfterUpdates + 1), with: .fade)
            }
            sectionNeedingReloadAfterUpdates = -1
        }
        
        if (sectionHeaderNeedingReloadAfterUpdates != -1) {
            if let headerView = self.tableView!.headerView(forSection: sectionHeaderNeedingReloadAfterUpdates) {
                self.configureHeaderView(headerView, forHeaderInSection: sectionHeaderNeedingReloadAfterUpdates)
            }
            sectionHeaderNeedingReloadAfterUpdates = -1
        }
        
        // reload the rewards section as needed
        if rewardSectionNeedsReload {
            rewardSectionNeedsReload = false
            self.tableView!.reloadSections(IndexSet(integer: 0), with: .fade)
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView!.insertSections(IndexSet(integer: sectionIndex + 1), with: .fade)
            sectionChangeType = .insert
        case .delete:
            self.tableView!.deleteSections(IndexSet(integer: sectionIndex + 1), with: .fade)
            sectionChangeType = .delete
        case .move, .update:
            // do nothing

            DDLogVerbose("Move/update section. Shouldn't happen?")
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeObject anObject: AnyObject, atIndexPath indexPath: IndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if (APIClient.shared.isMigrating) {
            return
        }
        
        var changeType = type
        var newIndexPath = newIndexPath

        if let trip = anObject as? Trip {
            if (type == .update && trip.didChangeSection == true) {
                // work around dumb bug
                // https://developer.apple.com/library/prerelease/content/releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/index.html
                changeType = .move
                if (newIndexPath == nil) {
                    newIndexPath = indexPath
                }
            }
            trip.didChangeSection = false
        }
        
        switch(changeType) {
            
        case .update:
            let indexPathPlusOne = IndexPath(row: indexPath!.row, section: indexPath!.section + 1)
            if let cell = self.tableView!.cellForRow(at: indexPathPlusOne) {
                configureCell(cell, indexPath: indexPathPlusOne)
            }
            
            sectionHeaderNeedingReloadAfterUpdates = indexPathPlusOne.section
        case .insert:
            if isOtherTripsSection(newIndexPath!.section) && self.fetchedResultsController.sections![newIndexPath!.section].numberOfObjects > 0 {
                // only insert the first row
                return
            }
            
            // only insert a row if the new trip is a bike trip
            self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: newIndexPath!.section + 1)], with: .fade)
            
            sectionHeaderNeedingReloadAfterUpdates = newIndexPath!.section + 1
            
            rewardSectionNeedsReload = true
        case .delete:
            if isOtherTripsSection(indexPath!.section) && self.fetchedResultsController.sections!.count > 0 && self.fetchedResultsController.sections![indexPath!.section].numberOfObjects > 0 {
                // don't delete the row unless it is the last
                return
            }
            
            // only delete a row if the trip was a bike trip
            self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: indexPath!.section + 1)], with: .fade)
            sectionHeaderNeedingReloadAfterUpdates = indexPath!.section + 1

            rewardSectionNeedsReload = true
        case .move:
            sectionHeaderNeedingReloadAfterUpdates = indexPath!.section + 1
            
            guard let trip = anObject as? Trip else {
                return
            }
            
            let theSection = self.fetchedResultsController.sections![indexPath!.section]
            let isInProgresstrip = theSection.name.contains(Trip.inProgressSectionIdentifierSuffix())
        
            if (newIndexPath != indexPath) {
                if isInProgresstrip || (trip.isClosed && trip.activityType != .cycling) ||  sectionChangeType == .delete {
                    // if the trip is moving to in progress, or if it is moving from the cycling trips to other trips, then delete a row
                    self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: indexPath!.section + 1)],
                                               with: .fade)
                } else {
                    sectionNeedingReloadAfterUpdates = indexPath!.section + 1
                }
                if trip.activityType == .cycling ||  sectionChangeType == .insert {
                    // if the trip is a cycling trip, or we are inserting a new section
                    self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: newIndexPath!.section + 1)],
                                               with: .fade)
                } else {
                    sectionNeedingReloadAfterUpdates = newIndexPath!.section + 1
                }
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections!.count + 1
    }
    
    private func isOtherTripsSection(_ section: Int)->Bool {
        guard section >= 0 else {
            return false
        }
        
        let theSection = self.fetchedResultsController.sections![section]
        
        if theSection.name.contains(Trip.inProgressSectionIdentifierSuffix()) {
            // always show full detail for the In Progress section
            return false
        }
        
        return !theSection.name.contains(Trip.cyclingSectionIdentifierSuffix())
    }

    private func otherTripsSectionHasOnlyOtherTrips(_ section: Int)->Bool {
        guard isOtherTripsSection(section) else {
            return false
        }
        
        guard section > 0 else {
            // if section 0 is an otherTripSection then there was no cycling trips section before
            return true
        }
        
        let theSection = self.fetchedResultsController.sections![section]
        let sectionName = theSection.name
        
        let thePreviousSection = self.fetchedResultsController.sections![section - 1]
        
        guard thePreviousSection.name.characters.count > Trip.cyclingSectionIdentifierSuffix().characters.count else {
            // the prior section is the "In Progress" section.
            return true
        }
        
        let previousSectionName = (thePreviousSection.name as NSString).substring(to: thePreviousSection.name.characters.count - Trip.cyclingSectionIdentifierSuffix().characters.count)
        
        // if the section name is not equal to the prior sections name (minus the suffix)
        return (sectionName != previousSectionName)
    }

    
    private func configureHeaderView(_ headerView: UITableViewHeaderFooterView, forHeaderInSection section: Int) {
        guard let view = headerView as? RoutesTableViewHeaderCell else {
            return
        }
        
        let theSection = self.fetchedResultsController.sections![section - 1]
        var sectionName = theSection.name
        
        if (theSection.name.contains(Trip.cyclingSectionIdentifierSuffix())) {
            sectionName = (sectionName as NSString).substring(to: sectionName.characters.count - 2)
        }
        
        var title = ""
        if section == 0 {
            title = "  Trophies"
        }
        
        if let date = Trip.sectionDateFormatter.date(from: sectionName) {
            if (date.isToday()) {
                title = "Today"
            } else if (date.isYesterday()) {
                title = "Yesterday"
            } else if (date.isInLastWeek()) {
                title = date.weekDay()
            } else if (date.isThisYear()) {
                title = self.dateFormatter.string(from: date)
            } else {
                title = self.yearDateFormatter.string(from: date)
            }
        } else {
            view.dateLabel.text = "  In Progress"
            view.milesLabel.text = ""
            return
        }
        
        var totalLength: Meters = 0
        if let tripsInSection = theSection.objects as? [Trip] {
            for trip in tripsInSection {
                if trip.activityType == .cycling {
                    totalLength += trip.length
                }
            }
        }
        
        view.dateLabel.text = "  " + title
        if totalLength > 0 {
            view.milesLabel.text = totalLength.distanceString()
        } else {
            view.milesLabel.text = "no rides"
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section > 0 else {
            return 0
        }
        
        guard !isOtherTripsSection(section - 1) else {
            if otherTripsSectionHasOnlyOtherTrips(section - 1) {
                return 28
            } else {
                return 0
            }
        }
        
        return 28
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let reuseID = "RoutesViewTableSectionHeaderCell"
        
        if let headerView = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: reuseID) {
            self.configureHeaderView(headerView, forHeaderInSection: section)
            return headerView
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section > 0 else {
            return 1
        }
        
        guard !isOtherTripsSection(section - 1) else {
            return 1
        }
        
        return self.fetchedResultsController.sections![section - 1].numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableCell : UITableViewCell!
        
        if indexPath.section == 0 {
            // for now we only support a single promotion
            if let promo = Profile.profile().eligibilePromotion() {
                // do it
                let reuseID = "PromoViewTableCell"
                
                tableCell = self.tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath as IndexPath)
                tableCell.separatorInset = UIEdgeInsetsMake(0, -8, 0, -8)
                tableCell.layoutMargins = UIEdgeInsets.zero
                
                configurePromoCell(tableCell, promotion: promo)
            } else {
                let reuseID = "RewardsViewTableCell"
                
                tableCell = self.tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath as IndexPath)
                tableCell.separatorInset = UIEdgeInsetsMake(0, -8, 0, -8)
                tableCell.layoutMargins = UIEdgeInsets.zero
                if #available(iOS 9.0, *) {} else {
                    // ios 8 devices crash the trophy room due to a bug in sprite kit, so we disable it.
                    tableCell.accessoryType = .none
                }
                
                configureRewardsCell(tableCell)
            }
        } else {
            let reuseID = "RoutesViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath as IndexPath)
            configureCell(tableCell, indexPath: indexPath as IndexPath)
            
            tableCell.layoutMargins = UIEdgeInsets.zero

            tableCell.separatorInset = UIEdgeInsetsMake(0, 20, 0, 0)
        }
        
        return tableCell
    }
    
    func configurePromoCell(_ tableCell: UITableViewCell, promotion: Promotion) {
        guard let bannerImageView = tableCell.viewWithTag(3) as? UIImageView,
            let titleLabel = tableCell.viewWithTag(1) as? UILabel,
            let connectButton = tableCell.viewWithTag(2) as? UIButton else {
                return
        }
        
        
        if let urlString = promotion.bannerImageUrl, let url = URL(string: urlString) {
            if bannerImageView.image == nil {
                tableCell.contentView.layer.opacity = 0.0
                tableCell.contentView.isHidden = true
            }
            
            bannerImageView.kf.setImage(with: url, placeholder: nil, options: [.keepCurrentImageWhileLoading], progressBlock: nil, completionHandler: { (image, error, _, _) in
                if let image = image {
                    for constraint in bannerImageView.constraints {
                        let aspectRatio = image.size.height / image.size.width

                        if constraint.firstAttribute == .height && fabs(aspectRatio - constraint.multiplier) > 0.001 { // if the aspect ratio needs change (minus any rounding error)
                            bannerImageView.removeConstraint(constraint)
                            let newConstraint = NSLayoutConstraint(item: bannerImageView, attribute: .height, relatedBy: NSLayoutRelation.equal, toItem: bannerImageView, attribute: .width, multiplier: aspectRatio, constant: 0)
                            bannerImageView.addConstraint(newConstraint)
                            newConstraint.isActive = true
                            
                            bannerImageView.setNeedsLayout()
                            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
                        }
                        
                        if (tableCell.contentView.isHidden) {
                            tableCell.contentView.isHidden = false
                            tableCell.contentView.delay(0.3) { tableCell.contentView.fadeIn() }
                        }
                        break
                    }
                }
            })
        }
        titleLabel.text = promotion.text
        connectButton.setTitle(promotion.buttonTitle, for: .normal)
    }
    
    func configureRewardsCell(_ tableCell: UITableViewCell) {
        guard let trophySummaryLabel = tableCell.viewWithTag(1) as? UILabel,
            let streakTextLabel = tableCell.viewWithTag(2) as? UILabel,
            let streakJewelLabel = tableCell.viewWithTag(3) as? UILabel,
            let trophyCountLabel = tableCell.viewWithTag(4) as? UILabel else {
                return
        }
        
        if let chevronImage = getDisclosureArrow(tableCell) {
            let accessoryImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: chevronImage.size.width + 8, height: chevronImage.size.height))
            accessoryImageView.contentMode = .right
            accessoryImageView.tintColor = ColorPallete.shared.goodGreen
            accessoryImageView.image = chevronImage
            tableCell.accessoryView = accessoryImageView
        }
        
 
        
        let trophyCount = TripReward.numberOfRewards
        if trophyCount > 1 {
            trophyCountLabel.text = String(trophyCount) + " Trophies"
        } else if trophyCount == 1 {
            trophyCountLabel.text = "You Got a Trophy!"
        } else {
            trophyCountLabel.text = "No Trophies Yet"
        }
        
        var rewardString = ""
        if trophyCount > 1 {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1.2
            
            let emojiWidth = ("👍" as NSString).size(attributes: [NSFontAttributeName: trophySummaryLabel.font]).width
            let columnSeperatorWidth: CGFloat = 6
            let totalWidth = emojiWidth + columnSeperatorWidth
            
            var tabStops : [NSTextTab] = []
            var totalLineWidth : CGFloat = 0
            var columnCount = 0
            while totalLineWidth + totalWidth < (self.view.frame.size.width - 30) {
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.center, location: totalLineWidth, options: [:]))
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.left, location: totalLineWidth + emojiWidth , options: [NSTabColumnTerminatorsAttributeName:CharacterSet(charactersIn:"\t")]))
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.left, location: totalLineWidth + emojiWidth + columnSeperatorWidth , options: [:]))
                totalLineWidth += totalWidth
                columnCount += 1
            }
            
            paragraphStyle.tabStops = tabStops
            
            var i = 1
            var lineCount = 0
            let rewardsTripCounts = TripReward.tripRewardCountsGroupedByAttribute("emoji")
            for countData in rewardsTripCounts {
                if let emoji = countData["emoji"] as? String {
                    if emoji.containsUnsupportEmoji() {
                        // support for older versions of iOS without a given emoji
                        continue
                    }
                      rewardString += emoji + "\t"
                    i += 1
                    if i>=columnCount {
                        i = 1
                        lineCount += 1
                        if let lastEmoji = rewardsTripCounts.last?["emoji"] as? String, lastEmoji != emoji  {
                            rewardString += "\n"
                        }
                    }
                }
            }
        
            let attrString = NSMutableAttributedString(string: rewardString)
            attrString.addAttribute(NSParagraphStyleAttributeName, value:paragraphStyle, range:NSMakeRange(0, attrString.length))

            trophySummaryLabel.attributedText = attrString
        } else {
            trophySummaryLabel.text = ""
        }
        
        if let statusText = Profile.profile().statusText, let statusEmoji = Profile.profile().statusEmoji {
            streakTextLabel.text = statusText
            streakJewelLabel.text = statusEmoji
            if (self.shouldShowStreakAnimation) {
                self.shouldShowStreakAnimation = false
                if statusEmoji == "🐣" {
                    self.bobbleView(streakJewelLabel)
                } else {
                    self.beatHeart(streakJewelLabel)
                }
            }
        } else {
            streakTextLabel.text = ""
            streakJewelLabel.text = ""
        }
    }
    
    func beatHeart(_ view: UIView) {
        CATransaction.begin()
        
        let growAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        let growScale: CGFloat = 1.6
        growAnimation.values = [
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
        ]
        growAnimation.keyTimes = [0, 0.12, 0.50, 0.62, 1]
        growAnimation.isAdditive = true
        growAnimation.duration = 1.2
        
        view.layer.add(growAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    private var disclosureArrow: UIImage? = nil
    func getDisclosureArrow(_ tableCell: UITableViewCell)->UIImage? {
        if disclosureArrow != nil {
            return disclosureArrow
        }
        
        for case let button as UIButton in tableCell.subviews {
            let image = button.backgroundImage(for: .normal)?.withRenderingMode(.alwaysTemplate)
            disclosureArrow = image
            return image
        }
        
        return nil
    }
    
    func configureCell(_ tableCell: UITableViewCell, indexPath: IndexPath) {
        guard let rideSummaryView = tableCell.viewWithTag(1) as? RideSummaryView,
            let otherTripsLabel = tableCell.viewWithTag(2) as? UILabel else {
            return
        }
        rideSummaryView.delegate = self
        
        if !isOtherTripsSection(indexPath.section - 1) {
            otherTripsLabel.isHidden = true
            rideSummaryView.isHidden = false
            
            let trip = self.fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as! Trip
            if !trip.isClosed {
                rideSummaryView.setTripSummary(tripLength: trip.inProgressLength, description: String(format: "Trip starting at %@.", trip.timeString()))
                rideSummaryView.setRewards([])
            } else {
                var rewardDicts: [[String: Any]] = []
                for element in trip.tripRewards {
                    if let reward = element as? TripReward {
                        var rewardDict: [String: Any] = [:]
                        rewardDict["object"] = reward
                        rewardDict["rewardUUID"] = reward.rewardUUID
                        rewardDict["displaySafeEmoji"] = reward.displaySafeEmoji
                        rewardDict["descriptionText"] = reward.descriptionText
                        rewardDicts.append(rewardDict)
                    }
                }
                rideSummaryView.setTripSummary(tripLength: trip.length, description: trip.displayStringWithTime())
                
                var shouldAnimate = false
                if (indexPath.row == 0 && indexPath.section == 1) {
                    // animate only the most recent trip, and only once per viewWillAppear
                    if (self.shouldShowRewardsAnimation) {
                        self.shouldShowRewardsAnimation = false
                        shouldAnimate = true
                    }
                }
                rideSummaryView.setRewards(rewardDicts, animated: shouldAnimate)
            }
            
            if let chevronImage = getDisclosureArrow(tableCell) {
                tableCell.accessoryView = nil
                tableCell.accessoryType = .none
                rideSummaryView.chevronImage = chevronImage
            }
        } else {
            otherTripsLabel.isHidden = false
            //rideSummaryView.isHidden = true
            rideSummaryView.setTripSummary(tripLength: 0, description: "")
            rideSummaryView.setRewards([])
            rideSummaryView.chevronImage = nil
            
            if let chevronImage = getDisclosureArrow(tableCell) {
                tableCell.accessoryType = .none
                let accessoryImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: chevronImage.size.width + 8, height: chevronImage.size.height))
                accessoryImageView.contentMode = .right
                accessoryImageView.tintColor = ColorPallete.shared.unknownGrey
                accessoryImageView.image = chevronImage
                tableCell.accessoryView = accessoryImageView
            }
            
            let otherTripsCount = self.fetchedResultsController.sections![indexPath.section - 1].numberOfObjects
            
            if otherTripsCount == 1 {
                otherTripsLabel.text = " 1 Other Trip"
            } else {
                otherTripsLabel.text = String(otherTripsCount) + " Other Trips"
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = self.tableView!.cellForRow(at: indexPath), cell.reuseIdentifier == "RewardsViewTableCell" {
            self.performSegue(withIdentifier: "showStatsView", sender: self)
            return
        }
        if let cell = self.tableView!.cellForRow(at: indexPath), cell.reuseIdentifier == "PromoViewTableCell" {
            self.tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        if let trip = self.fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as? Trip {
            if trip.activityType == .cycling || trip.isClosed == false {
                self.performSegue(withIdentifier: "showTrip", sender: trip)
            } else {
                self.performSegue(withIdentifier: "showOtherTripsView", sender: trip.creationDate)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showTrip") {
            if let tripVC = segue.destination as? TripViewController,
                let trip = sender as? Trip {
                tripVC.selectedTrip = trip
            }
        } else if (segue.identifier == "showOtherTripsView") {
            if let otherTripVC = segue.destination as? OtherTripsViewController,
                let date = sender as? Date {
                otherTripVC.dateOfTripsToShow = date
            }
        }
    }
    
    func didTapReward(withAssociatedObject object: Any) {
        guard let reward = object as? TripReward else {
            return
        }
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let redeemVC : RedeemRewardViewController = storyBoard.instantiateViewController(withIdentifier: "redeemRewardViewController") as! RedeemRewardViewController
        redeemVC.tripReward = reward
        customPresentViewController(RedeemRewardViewController.presenter(), viewController: redeemVC, animated: true, completion: nil)

        return
    }
    
    func showMapInfo() {
        let directionsNavController = self.storyboard!.instantiateViewController(withIdentifier: "DirectionsNavViewController") as! UINavigationController
        self.present(directionsNavController, animated: true, completion: nil)
        
        weak var directionsVC = directionsNavController.topViewController as? DirectionsViewController
        if directionsVC != nil  {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
                directionsVC?.mapViewController.mapView.attributionButton.sendActions(for: UIControlEvents.touchUpInside)
            }
        }
    }
    
    @IBAction func actOnPromo(_ sender: AnyObject) {
        // only support one promo for now
        if let promo = Profile.profile().promotions.allObjects.first as? Promotion, let app = promo.connectedApp {
            if let app = promo.connectedApp, app.name == nil || app.name?.isEmpty == true {
                // if we need to, fetch the app.
                if let button = sender as? UIButton {
                    button.isEnabled = false
                }
                APIClient.shared.getApplication(app).apiResponse({ (response) in
                    switch response.result {
                    case .success(_):
                        if let button = sender as? UIButton {
                            button.isEnabled = true
                        }
                        AppDelegate.appDelegate().transitionToConnectApp(app)
                    case .failure(_):
                        if let button = sender as? UIButton {
                            button.isEnabled = true
                        }
                        DDLogInfo("Failed to load connected application!")
                    }
                })
            } else {
                AppDelegate.appDelegate().transitionToConnectApp(app)
            }
        }
    }
    
    @IBAction func dismissPromo(_ sender: AnyObject) {
        // only support one promo for now
        if let promo = Profile.profile().promotions.allObjects.first as? Promotion {
            promo.userDismissed = true
            CoreDataManager.shared.saveContext()
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
        }
    }
    
    @IBAction func showDirections(_ sender: AnyObject) {
        let directionsNavController = self.storyboard!.instantiateViewController(withIdentifier: "DirectionsNavViewController") as! UINavigationController
        self.present(directionsNavController, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if (indexPath.section == 0) {
            return nil
        }
        
        let trip : Trip = self.fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as! Trip
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
            let trip : Trip = self.fetchedResultsController.object(at: NSIndexPath(row: indexPath.row, section: indexPath.section - 1) as IndexPath) as! Trip
            self.tableView.setEditing(false, animated: true)
            
            let alertController = UIAlertController(title: "🐞 Tools", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
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
        if (indexPath.section == 0) {
            return
        }
        
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            let trip : Trip = self.fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as! Trip
            APIClient.shared.deleteTrip(trip)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (indexPath.section == 0) {
            return false
        }
        
        if (isOtherTripsSection(indexPath.section - 1)) {
            return false
        }
        
        return true
    }
}

class RoutesTableViewHeaderCell: UITableViewHeaderFooterView {
    fileprivate var separatorView: UIView!
    fileprivate var dateLabel: UILabel!
    fileprivate var milesLabel: UILabel!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        guard self.dateLabel == nil else {
            return
        }
        
        self.backgroundView = UIView()
        
        self.contentView.backgroundColor = UIColor.white
        
        self.dateLabel = UILabel()
        self.dateLabel.font = UIFont.boldSystemFont(ofSize: 16.0)
        self.dateLabel.textColor = ColorPallete.shared.darkGrey
        self.dateLabel.translatesAutoresizingMaskIntoConstraints = false
        self.dateLabel.numberOfLines = 1
        self.contentView.addSubview(self.dateLabel)
        NSLayoutConstraint(item: self.dateLabel, attribute: .leading, relatedBy: NSLayoutRelation.equal, toItem: self.contentView, attribute: .leadingMargin, multiplier: 1, constant: -6).isActive = true
        NSLayoutConstraint(item: self.dateLabel, attribute: .lastBaseline, relatedBy: NSLayoutRelation.equal, toItem: self.contentView, attribute: .lastBaseline, multiplier: 1, constant: -4).isActive = true
        
        self.milesLabel = UILabel()
        self.milesLabel.font = UIFont.systemFont(ofSize: 16.0)
        self.milesLabel.textColor = ColorPallete.shared.unknownGrey
        self.milesLabel.translatesAutoresizingMaskIntoConstraints = false
        self.milesLabel.numberOfLines = 1
        self.milesLabel.textAlignment = .right
        self.contentView.addSubview(self.milesLabel)
        NSLayoutConstraint(item: self.milesLabel, attribute: .trailing, relatedBy: NSLayoutRelation.equal, toItem: self.contentView, attribute: .trailingMargin, multiplier: 1, constant: -10).isActive = true
        NSLayoutConstraint(item: self.milesLabel, attribute: .lastBaseline, relatedBy: NSLayoutRelation.equal, toItem: self.contentView, attribute: .lastBaseline, multiplier: 1, constant: -4).isActive = true
        
        self.separatorView = UIView()
        self.separatorView.backgroundColor = ColorPallete.shared.unknownGrey
        self.separatorView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.separatorView)
        NSLayoutConstraint(item: self.separatorView, attribute: .width, relatedBy: NSLayoutRelation.equal, toItem: self.contentView, attribute: .width, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: self.separatorView, attribute: .height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 1/UIScreen.main.scale).isActive = true
        NSLayoutConstraint(item: self.separatorView, attribute: .leading, relatedBy: NSLayoutRelation.equal, toItem: self.contentView, attribute: .leadingMargin, multiplier: 1, constant: -8).isActive = true
        NSLayoutConstraint(item: self.separatorView, attribute: .top, relatedBy: NSLayoutRelation.equal, toItem: self.contentView, attribute: .top, multiplier: 1, constant: -1).isActive = true
    }
}
