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


class TripsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    @IBOutlet weak var emptyTableChick: UIView!
    
    @IBOutlet weak var popupView: PopupView!
    
    private var dateOfLastTableRefresh: NSDate?

    private var reachability : Reachability!
    
    private var shouldShowStreakAnimation = false
    
    private var fetchedResultsController : NSFetchedResultsController! = nil

    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    private var yearDateFormatter : NSDateFormatter!
    private var rewardSectionNeedsReload : Bool = false
    private var sectionNeedingReload: Int = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Rides", style: .Plain, target: nil, action: nil)
        
        self.popupView.hidden = true
        
        self.tableView.layoutMargins = UIEdgeInsetsZero
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 48
        
        // when the user drags up they should see the right color above the rewards cell
        var headerViewBackgroundViewFrame = self.tableView.bounds
        headerViewBackgroundViewFrame.origin.y = -headerViewBackgroundViewFrame.size.height
        let headerViewBackgroundView = UIView(frame: headerViewBackgroundViewFrame)
        headerViewBackgroundView.backgroundColor = ColorPallete.sharedPallete.almostWhite
        self.tableView.insertSubview(headerViewBackgroundView, atIndex: 0)
        
        self.tableView.registerClass(RoutesTableViewHeaderCell.self, forHeaderFooterViewReuseIdentifier: "RoutesViewTableSectionHeaderCell")
        
        // get rid of empty table view seperators
        self.tableView.tableFooterView = UIView()
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mma"
        self.timeFormatter.AMSymbol = (self.timeFormatter.AMSymbol as NSString).lowercaseString
        self.timeFormatter.PMSymbol = (self.timeFormatter.PMSymbol as NSString).lowercaseString
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.yearDateFormatter = NSDateFormatter()
        self.yearDateFormatter.locale = NSLocale.currentLocale()
        self.yearDateFormatter.dateFormat = "MMM d ''yy"
        
        self.emptyTableView.hidden = true
        
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
        self.reloadSectionIdentifiersIfNeeded()
        
        let cacheName = "TripsViewControllerFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.fetchBatchSize = 20
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "sectionIdentifier", ascending: false), NSSortDescriptor(key: "isBikeTrip", ascending: false), NSSortDescriptor(key: "creationDate", ascending: false)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error loading trips view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        
        self.refreshEmptyTableView()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
        self.dateOfLastTableRefresh = NSDate()
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) {[weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reloadSectionIdentifiersIfNeeded()
        }
        
        if APIClient.sharedClient.accountVerificationStatus != .Unknown {
            self.runCreateAccountOfferIfNeeded()
        } else {
            NSNotificationCenter.defaultCenter().addObserverForName("APIClientStatusTextDidChange", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.shouldShowStreakAnimation = true
                if let rewardsCell = strongSelf.tableView!.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)) {
                    strongSelf.configureRewardsCell(rewardsCell)
                }
            }
            
            NSNotificationCenter.defaultCenter().addObserverForName("APIClientAccountStatusDidChange", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NSNotificationCenter.defaultCenter().removeObserver(strongSelf, name: "APIClientAccountStatusDidChange", object: nil)
                strongSelf.runCreateAccountOfferIfNeeded()
            }
        }
    }
    
    private func runCreateAccountOfferIfNeeded() {
        if (APIClient.sharedClient.accountVerificationStatus == .Unverified) {

            if (Trip.numberOfCycledTrips > 10 && !NSUserDefaults.standardUserDefaults().boolForKey("hasBeenOfferedCreateAccountAfter10Trips")) {
                NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasBeenOfferedCreateAccountAfter10Trips")
                NSUserDefaults.standardUserDefaults().synchronize()
                let alertController = UIAlertController(title: "Don't lose your trips!", message: "Create an account so you can recover your rides if your phone is lost.", preferredStyle: UIAlertControllerStyle.ActionSheet)
                alertController.addAction(UIAlertAction(title: "Create Account", style: UIAlertActionStyle.Default, handler: { (_) in
                    AppDelegate.appDelegate().transitionToCreatProfile()
                }))
                
                alertController.addAction(UIAlertAction(title: "Nope", style: UIAlertActionStyle.Cancel, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        self.refreshEmptyTableView()
        
        self.refreshHelperPopupUI()
        
        
        self.reachability = Reachability.reachabilityForLocalWiFi()
        self.reachability.startNotifier()
        
        NSNotificationCenter.defaultCenter().addObserverForName(kReachabilityChangedNotification, object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.refreshHelperPopupUI()
        }
        
        if (self.tableView.indexPathForSelectedRow != nil) {
            self.tableView.deselectRowAtIndexPath(self.tableView.indexPathForSelectedRow!, animated: animated)
        }
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.refreshTitle()
            }
        } else {
            self.refreshTitle()
        }
    }
    
    func bobbleView(view: UIView) {
        CATransaction.begin()
        
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        //let rotationOffsets = [M_PI, -M_PI_2, -0.2, 0.2, -0.2, 0.2, -0.2, 0.2, 0.0]
        shakeAnimation.values = [
            NSValue(CATransform3D:CATransform3DMakeRotation(10 * CGFloat(M_PI/180), 0, 0, -1)),
            NSValue(CATransform3D: CATransform3DMakeRotation(-10 * CGFloat(M_PI/180), 0, 0, 1)),
            NSValue(CATransform3D: CATransform3DMakeRotation(6 * CGFloat(M_PI/180), 0, 0, 1)),
            NSValue(CATransform3D: CATransform3DMakeRotation(-6 * CGFloat(M_PI/180), 0, 0, 1)),
            NSValue(CATransform3D: CATransform3DMakeRotation(2 * CGFloat(M_PI/180), 0, 0, 1)),
            NSValue(CATransform3D: CATransform3DMakeRotation(-2 * CGFloat(M_PI/180), 0, 0, 1))
        ]
        shakeAnimation.keyTimes = [0, 0.2, 0.4, 0.65, 0.8, 1]
        shakeAnimation.additive = true
        shakeAnimation.duration = 0.6
        
        view.layer.addAnimation(shakeAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.reachability = nil
    }
    
    
    func refreshHelperPopupUI() {
        if (RouteManager.sharedManager.isPaused()) {
            if (self.popupView.hidden) {
                self.popupView.popIn()
            }
            if (RouteManager.sharedManager.isPausedDueToUnauthorized()) {
                self.popupView.text = "Ride Report needs permission to run"
            } else if (RouteManager.sharedManager.isPausedDueToBatteryLife()) {
                self.popupView.text = "Ride Report is paused until you charge your phone"
            } else {
                if let pausedUntilDate = RouteManager.sharedManager.pausedUntilDate() {
                    if (pausedUntilDate.isToday()) {
                        self.popupView.text = "Ride Report is paused until " + self.timeFormatter.stringFromDate(pausedUntilDate)
                    } else if (pausedUntilDate.isTomorrow()) {
                        self.popupView.text = "Ride Report is paused until tomorrow"
                    } else if (pausedUntilDate.isThisWeek()) {
                        self.popupView.text = "Ride Report is paused until " + pausedUntilDate.weekDay()
                    } else {
                        self.popupView.text = "Ride Report is paused until " + self.dateFormatter.stringFromDate(pausedUntilDate)
                    }
                } else {
                    self.popupView.text = "Ride Report is paused"
                }
            }
        } else {
            if (!UIDevice.currentDevice().wifiEnabled) {
                if (self.popupView.hidden) {
                    self.popupView.popIn()
                }
                self.popupView.text = "Ride Report works best when Wi-Fi is on"
            } else if (!self.popupView.hidden) {
                self.popupView.fadeOut()
            }
        }
    }
    
    private func reloadSectionIdentifiersIfNeeded() {
        if let date = self.dateOfLastTableRefresh where date.isToday() {
            // don't refresh if we've already done it today
        } else {
            // refresh to prevent section headers from getting out of date.
            self.dateOfLastTableRefresh = NSDate()
            Trip.reloadSectionIdentifiers()
            self.tableView.reloadData()
        }
        
    }

    
    private func refreshEmptyTableView() {
        guard let frc = self.fetchedResultsController else {
            // Core Data hasn't loaded yet
            self.emptyTableView.hidden = true
            return
        }
        
        if let sections = frc.sections where sections.count > 0 && sections[0].numberOfObjects > 0 {
            self.emptyTableView.hidden = true
        } else {
            self.emptyTableView.hidden = false
        }
    }
    
    private func refreshTitle() {
        self.title = "Ride Report"
    }
    
    func unloadFetchedResultsController() {
        self.fetchedResultsController.delegate = nil
        self.fetchedResultsController = nil
    }

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        if (APIClient.sharedClient.isMigrating) {
            return
        }
        
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        if (APIClient.sharedClient.isMigrating) {
            return
        }
        
        self.tableView.endUpdates()
        
        self.refreshEmptyTableView()
        self.refreshTitle()
        
        // reload the rewards section as needed
        if rewardSectionNeedsReload {
            rewardSectionNeedsReload = false
            self.tableView!.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Fade)
        }
        
        if sectionNeedingReload != -1 {
            let numberOfRowsToReload = max(self.tableView(tableView, numberOfRowsInSection: sectionNeedingReload), self.tableView.numberOfRowsInSection(sectionNeedingReload))
            var pathsToReload: [NSIndexPath] = []
            for i in 0..<numberOfRowsToReload {
                let indexPath = NSIndexPath(forRow: i, inSection: sectionNeedingReload)
                pathsToReload.append(indexPath)
            }
            for indexPath in pathsToReload {
                if let cell = self.tableView!.cellForRowAtIndexPath(indexPath) {
                    configureCell(cell, indexPath: indexPath)
                }
            }
            
            sectionNeedingReload = -1
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            self.tableView!.insertSections(NSIndexSet(index: sectionIndex + 1), withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteSections(NSIndexSet(index: sectionIndex + 1), withRowAnimation: UITableViewRowAnimation.Fade)
        case .Move, .Update:
            // do nothing

            DDLogVerbose("Move/update section. Shouldn't happen?")
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        if (APIClient.sharedClient.isMigrating) {
            return
        }
        
        switch(type) {
            
        case .Update:
            let indexPath = NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)
            if let cell = self.tableView!.cellForRowAtIndexPath(indexPath) {
                configureCell(cell, indexPath: indexPath)
            }

            if let headerView = self.tableView!.headerViewForSection(indexPath.section) {
                self.configureHeaderView(headerView, forHeaderInSection: indexPath.section)
            }
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
            if let headerView = self.tableView!.headerViewForSection(newIndexPath!.section + 1) {
                self.configureHeaderView(headerView, forHeaderInSection: newIndexPath!.section + 1)
            }
            rewardSectionNeedsReload = true
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
            if let headerView = self.tableView!.headerViewForSection(indexPath!.section + 1) {
                self.configureHeaderView(headerView, forHeaderInSection: indexPath!.section + 1)
            }
            rewardSectionNeedsReload = true
        case .Move:
            // caused when a trip's isBikeTrip status changes
            // in this case, we should reload the whole section.
            sectionNeedingReload = indexPath!.section + 1
            self.tableView!.reloadSections(NSIndexSet(index: indexPath!.section + 1), withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections!.count + 1
    }
    
    private func configureHeaderView(headerView: UITableViewHeaderFooterView, forHeaderInSection section: Int) {
        guard let view = headerView as? RoutesTableViewHeaderCell else {
            return
        }
        
        var title = ""
        if section == 0 {
            title = "  Trophies"
        }
        
        let theSection = self.fetchedResultsController.sections![section - 1]
        
        if let date = Trip.sectionDateFormatter.dateFromString(theSection.name) {
            if (date.isToday()) {
                title = "Today"
            } else if (date.isYesterday()) {
                title = "Yesterday"
            } else if (date.isInLastWeek()) {
                title = date.weekDay()
            } else if (date.isThisYear()) {
                title = self.dateFormatter.stringFromDate(date)
            } else {
                title = self.yearDateFormatter.stringFromDate(date)
            }
        } else {
            title = "In Progress"
        }
        
        var totalLength: Meters = 0
        if let tripsInSection = theSection.objects as? [Trip] {
            for trip in tripsInSection {
                if trip.activityType == .Cycling {
                    totalLength += trip.length
                }
            }
        }
        
        view.dateLabel.text = "  " + title
        if totalLength > 0 {
            view.milesLabel.text = totalLength.distanceString
        } else {
            view.milesLabel.text = "no rides"
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        
        return 28
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let reuseID = "RoutesViewTableSectionHeaderCell"
        
        if let headerView = self.tableView.dequeueReusableHeaderFooterViewWithIdentifier(reuseID) {
            self.configureHeaderView(headerView, forHeaderInSection: section)
            return headerView
        }
        
        return nil
    }
    
    private func numberOfBikeTripsInSection(section: Int)->Int {
        guard section > 0 else {
            return 0
        }
        
        var count = 0
        if let objects = self.fetchedResultsController.sections![section - 1].objects {
            for obj in objects {
                if let trip = obj as? Trip where trip.isBikeTrip {
                    count += 1
                }
            }
        }
        
        return count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        
        let numBikeTrips = numberOfBikeTripsInSection(section)
        if self.fetchedResultsController.sections![section - 1].numberOfObjects > numBikeTrips {
            // if there are other types of trips too, then we one extra row for 'Other trips'
            return numBikeTrips + 1
        } else {
            return numBikeTrips
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let tableCell : UITableViewCell!
        let numRowsInSection = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
        
        if indexPath.section == 0 {
            let reuseID = "RewardsViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
            tableCell.separatorInset = UIEdgeInsetsMake(0, -8, 0, -8)
            tableCell.layoutMargins = UIEdgeInsetsZero
            if #available(iOS 9.0, *) {} else {
                // ios 8 devices crash the trophy room due to a bug in sprite kit, so we disable it.
                tableCell.accessoryType = .None
            }
            
            configureRewardsCell(tableCell)
        }  else {
            let reuseID = "RoutesViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
            configureCell(tableCell, indexPath: indexPath)
            
            tableCell.layoutMargins = UIEdgeInsetsZero

            tableCell.separatorInset = UIEdgeInsetsMake(0, 20, 0, 0)
        }
        
        return tableCell
    }
    
    func configureRewardsCell(tableCell: UITableViewCell) {
        setDisclosureArrowColor(tableCell)
        
        guard let trophySummaryLabel = tableCell.viewWithTag(1) as? UILabel,
        streakTextLabel = tableCell.viewWithTag(2) as? UILabel,
        streakJewelLabel = tableCell.viewWithTag(3) as? UILabel,
        trophyCountLabel = tableCell.viewWithTag(4) as? UILabel else {
            return
        }
        
        let trophyCount = Trip.numberOfRewardedTrips
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
            
            let emojiWidth = ("👍" as NSString).sizeWithAttributes([NSFontAttributeName: trophySummaryLabel.font]).width
            let columnSeperatorWidth: CGFloat = 6
            let totalWidth = emojiWidth + columnSeperatorWidth
            
            var tabStops : [NSTextTab] = []
            var totalLineWidth : CGFloat = 0
            var columnCount = 0
            while totalLineWidth + totalWidth < (self.view.frame.size.width - 30) {
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Center, location: totalLineWidth, options: [:]))
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Left, location: totalLineWidth + emojiWidth , options: [NSTabColumnTerminatorsAttributeName:NSCharacterSet(charactersInString:"\t")]))
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Left, location: totalLineWidth + emojiWidth + columnSeperatorWidth , options: [:]))
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
                        if let lastEmoji = rewardsTripCounts.last?["emoji"] as? String where lastEmoji == emoji  {
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
        
        if let statusText = Profile.profile().statusText, statusEmoji = Profile.profile().statusEmoji {
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
    
    func beatHeart(view: UIView) {
        CATransaction.begin()
        
        let growAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        let growScale: CGFloat = 1.6
        growAnimation.values = [
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
        ]
        growAnimation.keyTimes = [0, 0.12, 0.50, 0.62, 1]
        growAnimation.additive = true
        growAnimation.duration = 1.2
        
        view.layer.addAnimation(growAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    func setDisclosureArrowColor(tableCell: UITableViewCell) {
        for case let button as UIButton in tableCell.subviews {
            let image = button.backgroundImageForState(.Normal)?.imageWithRenderingMode(.AlwaysTemplate)
            button.setBackgroundImage(image, forState: .Normal)
        }
    }
    
    func configureCell(tableCell: UITableViewCell, indexPath: NSIndexPath) {
        guard let textLabel = tableCell.viewWithTag(1) as? UILabel else {
            return
        }
        
        setDisclosureArrowColor(tableCell)
        
        if (indexPath.row < numberOfBikeTripsInSection(indexPath.section)) {
            let trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
            var dateTitle = ""
            if (trip.creationDate != nil) {
                dateTitle = String(format: "%@", self.timeFormatter.stringFromDate(trip.creationDate))
                
            }
            
            let areaDescriptionString = trip.areaDescriptionString
            var description = String(format: "%@ %@ for %@%@.", trip.climacon ?? "", dateTitle, trip.length.distanceString, (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
            
            for reward in trip.tripRewards.array as! [TripReward] {
                if let emoji = reward.displaySafeEmoji where reward.descriptionText.rangeOfString("day ride streak") == nil {
                    description += ("\n\n" + emoji + " " + reward.descriptionText)
                }
            }
            
            textLabel.textColor = ColorPallete.sharedPallete.darkGrey
            textLabel.text = description
        } else {
            let otherTripsCount = self.fetchedResultsController.sections![indexPath.section - 1].numberOfObjects - numberOfBikeTripsInSection(indexPath.section)
            textLabel.textColor = ColorPallete.sharedPallete.unknownGrey
            
            if otherTripsCount == 1 {
                textLabel.text = " 1 Other Trip"
            } else {
                textLabel.text = String(otherTripsCount) + " Other Trips"
            }
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.section == 0) {
            if #available(iOS 9.0, *) {
                // ios 8 devices crash the trophy room due to a bug in sprite kit, so we disable it.
                self.performSegueWithIdentifier("showRewardsView", sender: self)
            } else {
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
            }
            
            return
        }
        
        if let trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as? Trip {
            if trip.activityType == .Cycling {
                self.performSegueWithIdentifier("showTrip", sender: trip)
            } else {
                self.performSegueWithIdentifier("showOtherTripsView", sender: trip.creationDate)
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "showTrip") {
            if let tripVC = segue.destinationViewController as? TripViewController,
                trip = sender as? Trip {
                tripVC.selectedTrip = trip
            }
        } else if (segue.identifier == "showOtherTripsView") {
            if let otherTripVC = segue.destinationViewController as? OtherTripsViewController,
                date = sender as? NSDate {
                otherTripVC.dateOfTripsToShow = date
            }
        }
    }
    
    func showMapInfo() {
        let directionsNavController = self.storyboard!.instantiateViewControllerWithIdentifier("DirectionsNavViewController") as! UINavigationController
        self.presentViewController(directionsNavController, animated: true, completion: nil)
        
        weak var directionsVC = directionsNavController.topViewController as? DirectionsViewController
        if directionsVC != nil  {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                directionsVC?.mapViewController.mapView.attributionButton.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
            }
        }
    }
    
    @IBAction func showDirections(sender: AnyObject) {
        let directionsNavController = self.storyboard!.instantiateViewControllerWithIdentifier("DirectionsNavViewController") as! UINavigationController
        self.presentViewController(directionsNavController, animated: true, completion: nil)
    }

    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if (indexPath.section == 0) {
            return nil
        }
        
        let trip : Trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
        if !trip.isClosed {
            return [UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Cancel Trip") { (action, indexPath) -> Void in
                RouteManager.sharedManager.abortTrip()
            }]
        }
        
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete") { (action, indexPath) -> Void in
            APIClient.sharedClient.deleteTrip(trip)
        }
        
    #if DEBUG
        let toolsAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "🐞 Tools") { (action, indexPath) -> Void in
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
            self.tableView.setEditing(false, animated: true)
            
            let alertController = UIAlertController(title: "🐞 Tools", message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
            alertController.addAction(UIAlertAction(title: "Simulate Ride End", style: UIAlertActionStyle.Default, handler: { (_) in
                trip.sendTripCompletionNotificationLocally(forFutureDate: NSDate().secondsFrom(5))
            }))
            alertController.addAction(UIAlertAction(title: "Re-Classify", style: UIAlertActionStyle.Default, handler: { (_) in
                for sensorCollection in trip.sensorDataCollections {
                    RandomForestManager.sharedForest.classify(sensorCollection as! SensorDataCollection)
                }
                trip.calculateAggregatePredictedActivityType()
            }))
            alertController.addAction(UIAlertAction(title: "Sync to Health App", style: UIAlertActionStyle.Default, handler: { (_) in
                let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                })
                
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(30 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                    trip.isSavedToHealthKit = false
                    CoreDataManager.sharedManager.saveContext()
                    HealthKitManager.sharedManager.saveOrUpdateTrip(trip) {_ in 
                        if (backgroundTaskID != UIBackgroundTaskInvalid) {
                            
                            UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
                        }
                    }
                })
            }))
            
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Cancel, handler: nil))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        return [deleteAction, toolsAction]
    #else
        return [deleteAction]
    #endif
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.section == 0) {
            return
        }
        
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
            APIClient.sharedClient.deleteTrip(trip)
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if (indexPath.section == 0) {
            return false
        }
        return true
    }
}

class RoutesTableViewHeaderCell: UITableViewHeaderFooterView {
    private var separatorView: UIView!
    private var dateLabel: UILabel!
    private var milesLabel: UILabel!
    
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
        
        self.contentView.backgroundColor = UIColor.whiteColor()
        
        self.dateLabel = UILabel()
        self.dateLabel.font = UIFont.boldSystemFontOfSize(16.0)
        self.dateLabel.textColor = ColorPallete.sharedPallete.darkGrey
        self.dateLabel.translatesAutoresizingMaskIntoConstraints = false
        self.dateLabel.numberOfLines = 1
        self.contentView.addSubview(self.dateLabel)
        NSLayoutConstraint(item: self.dateLabel, attribute: .Leading, relatedBy: NSLayoutRelation.Equal, toItem: self.contentView, attribute: .LeadingMargin, multiplier: 1, constant: -6).active = true
        NSLayoutConstraint(item: self.dateLabel, attribute: .Baseline, relatedBy: NSLayoutRelation.Equal, toItem: self.contentView, attribute: .Baseline, multiplier: 1, constant: -4).active = true
        
        self.milesLabel = UILabel()
        self.milesLabel.font = UIFont.systemFontOfSize(16.0)
        self.milesLabel.textColor = ColorPallete.sharedPallete.unknownGrey
        self.milesLabel.translatesAutoresizingMaskIntoConstraints = false
        self.milesLabel.numberOfLines = 1
        self.milesLabel.textAlignment = .Right
        self.contentView.addSubview(self.milesLabel)
        NSLayoutConstraint(item: self.milesLabel, attribute: .Trailing, relatedBy: NSLayoutRelation.Equal, toItem: self.contentView, attribute: .TrailingMargin, multiplier: 1, constant: -10).active = true
        NSLayoutConstraint(item: self.milesLabel, attribute: .Baseline, relatedBy: NSLayoutRelation.Equal, toItem: self.contentView, attribute: .Baseline, multiplier: 1, constant: -4).active = true
        
        self.separatorView = UIView()
        self.separatorView.backgroundColor = ColorPallete.sharedPallete.unknownGrey
        self.separatorView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.separatorView)
        NSLayoutConstraint(item: self.separatorView, attribute: .Width, relatedBy: NSLayoutRelation.Equal, toItem: self.contentView, attribute: .Width, multiplier: 1, constant: 0).active = true
        NSLayoutConstraint(item: self.separatorView, attribute: .Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 1/UIScreen.mainScreen().scale).active = true
        NSLayoutConstraint(item: self.separatorView, attribute: .Leading, relatedBy: NSLayoutRelation.Equal, toItem: self.contentView, attribute: .LeadingMargin, multiplier: 1, constant: -8).active = true
        NSLayoutConstraint(item: self.separatorView, attribute: .Top, relatedBy: NSLayoutRelation.Equal, toItem: self.contentView, attribute: .Top, multiplier: 1, constant: -1).active = true
    }
}