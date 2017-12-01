//
//  TripsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder
import CoreData
import SystemConfiguration
import Presentr
import CocoaLumberjack

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
    
    private var dateOfLastTableRefresh: Date = Date()

    private var reachability : Reachability!
    
    private weak var cellToReAnimateOnAppActivate: UITableViewCell?
    private var shouldShowStreakAnimation = false
    private var shouldShowRewardsAnimation = true
    
    private var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Rides", style: .plain, target: nil, action: nil)
        
        self.tableView.layoutMargins = UIEdgeInsets.zero
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 48
        
        self.tableView.register(RoutesTableViewHeaderCell.self, forHeaderFooterViewReuseIdentifier: "RoutesViewTableSectionHeaderCell")
        
        // when the user drags up they should see the right color above the rewards cell
        var headerViewBackgroundViewFrame = self.tableView.bounds
        headerViewBackgroundViewFrame.origin.y = -headerViewBackgroundViewFrame.size.height
        headerViewBackgroundViewFrame.size.width += headerViewBackgroundViewFrame.size.width // dont know why this is needed to get it to fill
        let headerViewBackgroundView = UIView(frame: headerViewBackgroundViewFrame)
        headerViewBackgroundView.backgroundColor = UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1.0)
        self.tableView.insertSubview(headerViewBackgroundView, at: 0)
        
        if let navVC = self.navigationController {
            navVC.navigationBar.shadowImage = UIImage()
        }
        
        // get rid of empty table view seperators
        self.tableView.tableFooterView = UIView()
        
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
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TripsListRow")
        fetchedRequest.predicate = NSPredicate(format: "(isOtherTripsRow == false AND bikeTrip != nil) OR otherTrips.@count >= 1")
        fetchedRequest.fetchBatchSize = 20
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "section.date", ascending: false), NSSortDescriptor(key: "isOtherTripsRow", ascending: true), NSSortDescriptor(key: "sortName", ascending: false)]

        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "section.date", cacheName:cacheName )
        self.fetchedResultsController!.delegate = self
        do {
            try self.fetchedResultsController!.performFetch()
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
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) {[weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reloadSectionIdentifiersIfNeeded()
            strongSelf.loadFetchedResultsController()
            
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
            
            if let fetchedResultsController = strongSelf.fetchedResultsController {
                fetchedResultsController.delegate = nil
                strongSelf.fetchedResultsController = nil
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RideReportAPIClientStatusTextDidChange"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.refreshHeaderCells()
        }
        
        RideReportAPIClient.shared.syncTrips()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.4 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) { _ in
                RideReportAPIClient.shared.syncTrips()
            }
        })
        
        if RideReportAPIClient.shared.accountVerificationStatus != .unknown {
            self.runCreateAccountOfferIfNeeded()
        } else {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RideReportAPIClientAccountStatusDidChange"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "RideReportAPIClientAccountStatusDidChange"), object: nil)
                strongSelf.runCreateAccountOfferIfNeeded()
            }
        }
    }
    
    private func runCreateAccountOfferIfNeeded() {
        if (RideReportAPIClient.shared.accountVerificationStatus == .unverified) {

            if (Trip.numberOfCycledTrips > 10 && !UserDefaults.standard.bool(forKey: "hasBeenOfferedCreateAccountAfter10Trips")) {
                UserDefaults.standard.set(true, forKey: "hasBeenOfferedCreateAccountAfter10Trips")
                UserDefaults.standard.synchronize()
                let alertController = UIAlertController(title: "Don't lose your rides!", message: "Create an account so you can recover your rides if your phone is lost.", preferredStyle: UIAlertControllerStyle.actionSheet)
                alertController.addAction(UIAlertAction(title: "Create Account", style: UIAlertActionStyle.default, handler: { (_) in
                    AppDelegate.appDelegate().transitionToCreatProfile()
                }))
                
                alertController.addAction(UIAlertAction(title: "Nope", style: UIAlertActionStyle.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let navVC = self.navigationController {
            navVC.setNavigationBarHidden(true, animated: animated)
        }

        self.refreshEmptyTableView()
        self.refreshHeaderCells()
        
        
        self.reachability = Reachability.forLocalWiFi()
        self.reachability.startNotifier()
        
        if (self.tableView.indexPathForSelectedRow != nil) {
            self.tableView.deselectRow(at: self.tableView.indexPathForSelectedRow!, animated: animated)
        }
        
        self.title = "Ride Report"
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let navVC = self.navigationController {
            navVC.setNavigationBarHidden(false, animated: animated)
        }
    }
    
    func refreshHeaderCells() {
        // only support one promo for now
        if let promo = Profile.profile().eligibilePromotion() {
            self.shouldShowStreakAnimation = true
            if let app = promo.connectedApp {
                // if we need to, fetch the app.
                RideReportAPIClient.shared.getApplication(app)
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
    
    private func reloadSectionIdentifiersIfNeeded() {
        if self.dateOfLastTableRefresh.isToday() {
            // don't refresh if we've already done it today
        } else {
            // refresh to prevent section headers from getting out of date.
            self.dateOfLastTableRefresh = Date()
            
            self.tableView.reloadData()
        }
        
    }

    
    private func refreshEmptyTableView() {
        guard let fetchedResultsController = self.fetchedResultsController else {
            // Core Data hasn't loaded yet
            self.emptyTableView.isHidden = true
            return
        }
        
        if let sections = fetchedResultsController.sections, sections.count > 0 && sections[0].numberOfObjects > 0 {
            self.emptyTableView.isHidden = true
        } else {
            self.emptyTableView.isHidden = false
        }
    }
    
    func unloadFetchedResultsController() {
        guard let fetchedResultsController = self.fetchedResultsController else {
            return
        }
        
        fetchedResultsController.delegate = nil
        self.fetchedResultsController = nil
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
        
        self.refreshEmptyTableView()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView!.insertSections(IndexSet(integer: sectionIndex + 1), with: .fade)
        case .delete:
            self.tableView!.deleteSections(IndexSet(integer: sectionIndex + 1), with: .fade)
        case .move, .update:
            // do nothing

            DDLogVerbose("Move/update section. Shouldn't happen?")
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch(type) {
        case .update:
            let indexPathPlusOne = IndexPath(row: indexPath!.row, section: indexPath!.section + 1)
            if let cell = self.tableView!.cellForRow(at: indexPathPlusOne) {
                var newIndexPathPlusOne = indexPathPlusOne
                if let newIndexPath = newIndexPath {
                    newIndexPathPlusOne = IndexPath(row: newIndexPath.row, section: newIndexPath.section + 1)
                }
                configureCell(cell, indexPath: newIndexPathPlusOne)
            }
        case .insert:
            self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: newIndexPath!.section + 1)], with: .fade)
        case .delete:
            self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: indexPath!.section + 1)], with: .fade)
        case .move:
            self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: newIndexPath!.section + 1)],
                                       with: .fade)
            self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: indexPath!.section + 1)],
                                       with: .fade)
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        guard let fetchedResultsController = self.fetchedResultsController else {
            return 0
        }
        
        guard let sections = fetchedResultsController.sections else {
            return 0
        }
        
        return sections.count + 2
    }
    
    private func configureHeaderView(_ headerView: UITableViewHeaderFooterView, forHeaderInSection section: Int) {
        guard let view = headerView as? RoutesTableViewHeaderCell else {
            return
        }
        guard let fetchedResultsController = self.fetchedResultsController else {
            return
        }
        
        if section == 0 {
            view.dateLabel.text = "    Trophies"
            view.milesLabel.text = ""
        } else if let row = fetchedResultsController.object(at: IndexPath(row: 0, section: section - 1)) as? TripsListRow {
            let section = row.section
            
            if (section.isInProgressSection) {
                view.dateLabel.text = "  In Progress"
                view.milesLabel.text = ""
            } else {
                let title = section.date.colloquialDate().capitalized

                view.dateLabel.text = "  " + title
                var totalLength: Meters = 0
                for row in section.rows {
                    if let trip = row.bikeTrip {
                        totalLength += trip.length
                    }
                }
                
                if totalLength > 0 {
                    view.milesLabel.text = totalLength.distanceString()
                } else {
                    view.milesLabel.text = "no rides"
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let fetchedResultsController = self.fetchedResultsController, let sections = fetchedResultsController.sections else {
            return 0
        }
        
        guard section > 0 && section < sections.count else {
            return 0
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
        
        guard let fetchedResultsController = self.fetchedResultsController, let sections = fetchedResultsController.sections else {
            return 0
        }
        
        if section == sections.count + 1 {
            // include a loading indicator in the last section if there are more trips to download
            return 1
        }
        
        return fetchedResultsController.sections![section - 1].numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if cell.reuseIdentifier == "LoadMoreViewTableCell" && RideReportAPIClient.shared.hasMoreTripsRemaining {
            RideReportAPIClient.shared.getMoreTrips().apiResponse({ (_) in
                self.configureLoadMoreCell(cell)
            })
        }
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
        } else if let fetchedResultsController = self.fetchedResultsController, let sections = fetchedResultsController.sections, indexPath.section == sections.count + 1 {
            let reuseID = "LoadMoreViewTableCell"
            tableCell = self.tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath as IndexPath)
            
            configureLoadMoreCell(tableCell)
        } else {
            let reuseID = "RoutesViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath as IndexPath)
            configureCell(tableCell, indexPath: indexPath as IndexPath)
            
            tableCell.layoutMargins = UIEdgeInsets.zero

            tableCell.separatorInset = UIEdgeInsetsMake(0, 20, 0, 0)
        }
        
        return tableCell
    }
    
    func configureLoadMoreCell(_ tableCell: UITableViewCell) {
         // hide the separator
        tableCell.separatorInset = UIEdgeInsetsMake(0, tableCell.bounds.size.width, 0, 0)
        
        if RideReportAPIClient.shared.hasMoreTripsRemaining {
            tableCell.contentView.isHidden = false
            if let activitySpinner = tableCell.viewWithTag(1) as? UIActivityIndicatorView{
                activitySpinner.startAnimating()
            }
        } else {
            tableCell.contentView.isHidden = true
        }
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
        guard let stackView = tableCell.viewWithTag(1) as? UIStackView else {
            return
        }
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        for encouragement in Profile.profile().encouragements.array {
            guard let encouragement = encouragement as? Encouragement else {
                continue
            }
            
            let rewardsView = TrophyView()
            rewardsView.translatesAutoresizingMaskIntoConstraints = false
            rewardsView.emojiFont = UIFont.systemFont(ofSize: 50)
            rewardsView.bodyFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            rewardsView.emoji = encouragement.emoji
            rewardsView.body = encouragement.descriptionText

            stackView.addArrangedSubview(rewardsView)
            
            if (self.shouldShowStreakAnimation) {
                self.shouldShowStreakAnimation = false
                // do the animation here…
            }
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
        
        guard let fetchedResultsController = self.fetchedResultsController else {
            return
        }
        
        guard let row = fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as? TripsListRow else {
            return
        }
        
        rideSummaryView.delegate = self
        
        if let trip = row.bikeTrip, !row.isOtherTripsRow {
            otherTripsLabel.isHidden = true
            rideSummaryView.isHidden = false
            
            if trip.isInProgress {
                if (rideSummaryView.tripLength != trip.length) {
                    rideSummaryView.setTripSummary(tripLength: trip.length, description: String(format: "Ride started at %@.", trip.timeString()))
                    rideSummaryView.setRewards([])
                }
            } else {
                var rewardDicts: [[String: Any]] = []
                for element in trip.tripRewards {
                    if let reward = element as? TripReward {
                        var rewardDict: [String: Any] = [:]
                        rewardDict["object"] = reward
                        rewardDict["reward_uuid"] = reward.rewardUUID
                        rewardDict["emoji"] = reward.displaySafeEmoji
                        rewardDict["description"] = reward.descriptionText
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
            
            if row.otherTrips.count == 1 {
                otherTripsLabel.text = " 1 Other Trip"
            } else {
                otherTripsLabel.text = String(row.otherTrips.count) + " Other Trips"
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let fetchedResultsController = self.fetchedResultsController else {
            return
        }
        
        if let cell = self.tableView!.cellForRow(at: indexPath), cell.reuseIdentifier == "RewardsViewTableCell" {
            // does nothing
            return
        }
        if let cell = self.tableView!.cellForRow(at: indexPath), cell.reuseIdentifier == "PromoViewTableCell" {
            self.tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        if let row = fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as? TripsListRow {
            if let trip = row.bikeTrip {
                self.performSegue(withIdentifier: "showTrip", sender: trip)
            } else {
                self.performSegue(withIdentifier: "showOtherTripsView", sender: row.section.date)
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
    
    @IBAction func actOnPromo(_ sender: AnyObject) {
        // only support one promo for now
        if let promo = Profile.profile().promotions.array.first as? Promotion, let app = promo.connectedApp {
            if let app = promo.connectedApp, app.name == nil || app.name?.isEmpty == true {
                // if we need to, fetch the app.
                if let button = sender as? UIButton {
                    button.isEnabled = false
                }
                RideReportAPIClient.shared.getApplication(app).apiResponse({ (response) in
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
        if let promo = Profile.profile().promotions.array.first as? Promotion {
            promo.isUserDismissed = true
            CoreDataManager.shared.saveContext()
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
        }
    }
    
    @IBAction func showDirections(_ sender: AnyObject) {
        let directionsNavController = self.storyboard!.instantiateViewController(withIdentifier: "DirectionsNavViewController") as! UINavigationController
        self.present(directionsNavController, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if (indexPath.section <= 0) {
            return nil
        }
        guard let fetchedResultsController = self.fetchedResultsController else {
            return nil
        }
        
        guard let row = fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as? TripsListRow else {
            return nil
        }
        
        guard let trip = row.bikeTrip else {
            return nil
        }
        if trip.isInProgress {
            return [UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "End Ride") { (action, indexPath) -> Void in
                RouteRecorder.shared.routeManager.stopRoute()
            }]
        }
        
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Delete") { (action, indexPath) -> Void in
            let alertController = UIAlertController(title: "Delete Ride?", message: "This will permanently delete your ride", preferredStyle: .actionSheet)
            
            let deleteAlertAction = UIAlertAction(title: "Delete", style: .destructive) { (_) in
                RideReportAPIClient.shared.deleteTrip(trip).apiResponse({ (response) in
                    if case .failure = response.result {
                        let alertController = UIAlertController(title: "There was an error deleting that ride. Please try again later.!", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
                        alertController.addAction(UIAlertAction(title: "Darn", style: UIAlertActionStyle.cancel, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
                })
            }
            let cancelAlertAction = UIAlertAction(title: "Cancel", style: .cancel) {(_) in }
            
            alertController.addAction(deleteAlertAction)
            alertController.addAction(cancelAlertAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
        
    #if DEBUG
        let toolsAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "🐞 Tools") { (action, indexPath) -> Void in
            self.tableView.setEditing(false, animated: true)
            
            let alertController = UIAlertController(title: "🐞 Tools", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
            if let route = trip.route {
                alertController.addAction(UIAlertAction(title: "⬆️ Upload Prediction Aggregators", style: UIAlertActionStyle.default, handler: { (_) in
                    APIClient.shared.uploadPredictionAggregators(forRoute: route)
                }))
                alertController.addAction(UIAlertAction(title: "〰 Re-simplifiy", style: UIAlertActionStyle.default, handler: { (_) in
                    route.resimplify()
                }))
                alertController.addAction(UIAlertAction(title: "🏁 Simulate Ride End", style: UIAlertActionStyle.default, handler: { (_) in
                    trip.sendTripCompletionNotificationLocally(secondsFromNow:5.0)
                }))
                alertController.addAction(UIAlertAction(title: "⚙️ Re-Classify", style: UIAlertActionStyle.default, handler: { (_) in
//                    for prediction in route.predictionAggregators {
//                        RouteRecorder.shared.randomForestManager.classify(prediction)
//                    }
//                    route.calculateAggregatePredictedActivityType()
                }))
                
                alertController.addAction(UIAlertAction(title: "❤️ Sync to Health App", style: UIAlertActionStyle.default, handler: { (_) in
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
                alertController.addAction(UIAlertAction(title: "🔁 Replay", style: .default, handler: { (_) in
                    var cllocs: [CLLocation] = []
                    for location in route.fetchOrderedLocationsForReplay() {
                        cllocs.append(location.clLocation())
                    }
                    
                    let date = Date()
                    RouteRecorder.shared.locationManager.setLocations(locations: GpxLocationGenerator.generate(locations: cllocs, fromOffsetDate: date))
                }))
                alertController.addAction(UIAlertAction(title: "📦 Export", style: .default, handler: { (_) in
                    let urls = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                    let url = urls.last!
                    
                    var cllocs: [CLLocation] = []
                    let locs = route.fetchOrderedLocationsForReplay()
                    for location in locs {
                        cllocs.append(location.clLocation())
                    }
                    
                    let path = url + "/" + route.uuid + ".archive"
                    if NSKeyedArchiver.archiveRootObject(cllocs, toFile: path) {
                        UIPasteboard.general.string = path
                        let alertController = UIAlertController(title: "Save Location Copied to Clipboard.", message: path, preferredStyle: UIAlertControllerStyle.actionSheet)
                        alertController.addAction(UIAlertAction(title: "k", style: UIAlertActionStyle.cancel, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    } else {
                        let alertController = UIAlertController(title: "Failed to save file!", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
                        alertController.addAction(UIAlertAction(title: "k", style: UIAlertActionStyle.cancel, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
                }))
            } else {
                alertController.addAction(UIAlertAction(title: "⬇️ Download Route", style: .default) { (_) in
                    APIClient.shared.getRouteLocations(withUUID: trip.uuid)
                })
            }
            
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
        return [deleteAction, toolsAction]
    #else
        return [deleteAction]
    #endif
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (indexPath.section == 0) {
            return false
        }
        
        guard let fetchedResultsController = self.fetchedResultsController, let sections = fetchedResultsController.sections else {
            return false
        }
        
        if (indexPath.section > sections.count) {
            return false
        }
        
        guard let row = fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: indexPath.section - 1)) as? TripsListRow else {
            return false
        }

        
        if row.isOtherTripsRow {
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
