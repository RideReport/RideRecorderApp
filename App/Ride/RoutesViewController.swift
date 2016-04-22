//
//  RoutesViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import SystemConfiguration

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    @IBOutlet weak var emptyTableChick: UIView!
    
    @IBOutlet weak var popupView: PopupView!
    
    private var dateOfLastTableRefresh: NSDate?

    private var reachability : Reachability!
    
    private var hasShownStreakAnimation = false
    
    private var fetchedResultsController : NSFetchedResultsController! = nil

    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    private var yearDateFormatter : NSDateFormatter!
    private var rewardSectionNeedsReload : Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.navigationItem.hidesBackButton = true
        
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
        
        let cacheName = "RoutesViewControllerFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.fetchBatchSize = 20
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "sectionIdentifier", ascending: false), NSSortDescriptor(key: "creationDate", ascending: false)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
        self.fetchedResultsController!.delegate = self
        do {
            try self.fetchedResultsController!.performFetch()
        } catch let error {
            DDLogError("Error loading trips view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        
        self.refreshEmptyTableView()
        Profile.profile().updateCurrentRideStreakLength()
        
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
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: nil) {[weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.hasShownStreakAnimation = false
            strongSelf.tableView!.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Fade)
        }
        
        if APIClient.sharedClient.accountVerificationStatus != .Unknown {
            self.runCreateAccountOfferIfNeeded()
        } else {
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
        self.fetchedResultsController?.delegate = nil
        self.fetchedResultsController = nil
    }

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
        
        self.refreshEmptyTableView()
        self.refreshTitle()
        
        // reload the rewards section as needed
        if rewardSectionNeedsReload {
            rewardSectionNeedsReload = false
            Profile.profile().updateCurrentRideStreakLength()
            self.tableView!.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Fade)
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
        switch(type) {
            
        case .Update:
            let trip = self.fetchedResultsController.objectAtIndexPath(indexPath!) as! Trip
            let cell = self.tableView!.cellForRowAtIndexPath(NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1))
            if (cell != nil) {
                configureCell(cell!, trip:trip)
            }
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
            rewardSectionNeedsReload = true
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
            rewardSectionNeedsReload = true
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)],
                withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)],
                withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections!.count + 1
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        
        return 26
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "  Trophies"
        }
        
        let theSection = self.fetchedResultsController.sections![section - 1]
        
        var title = ""
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
        
        return "  ".stringByAppendingString(title)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 2
        }
        
        let sectionInfo = self.fetchedResultsController.sections![section - 1]
        
        // an extra row for our dummy cell
        return sectionInfo.numberOfObjects + 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let tableCell : UITableViewCell!
        
        if ((indexPath.section == 0 && indexPath.row == 1) || (indexPath.section > 0 && indexPath.row == self.fetchedResultsController.sections![indexPath.section - 1].numberOfObjects)) {
            // dummy cell to force a separator view to draw between rewards and next section
            let reuseID = "RoutesViewTableDummyCell"
            
            tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
            tableCell.separatorInset = UIEdgeInsetsMake(0, -8, 0, -8)
            tableCell.layoutMargins = UIEdgeInsetsZero

        } else if indexPath.section == 0 {
            let reuseID = "RewardsViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
            tableCell.separatorInset = UIEdgeInsetsMake(0, -8, 0, -8)
            tableCell.layoutMargins = UIEdgeInsetsZero
            
            configureRewardsCell(tableCell)
        }  else {
            let reuseID = "RoutesViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
            tableCell.layoutMargins = UIEdgeInsetsZero

            let trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
            configureCell(tableCell, trip: trip)
            if (indexPath.row == self.fetchedResultsController.sections![indexPath.section - 1].numberOfObjects - 1) {
                tableCell.separatorInset = UIEdgeInsetsMake(0, -8, 0, -8)
            } else {
                tableCell.separatorInset = UIEdgeInsetsMake(0, 46, 0, 0)
            }
        }
        
        return tableCell
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        
        headerView.tintColor = self.view.backgroundColor
        headerView.opaque = false
        headerView.textLabel!.font = UIFont.boldSystemFontOfSize(16.0)
        headerView.textLabel!.textColor = ColorPallete.sharedPallete.darkGrey
    }
    
    func configureRewardsCell(tableCell: UITableViewCell) {
        // make sure the disclosure arrow tint color can be set
        for case let button as UIButton in tableCell.subviews {
            let image = button.backgroundImageForState(.Normal)?.imageWithRenderingMode(.AlwaysTemplate)
            button.setBackgroundImage(image, forState: .Normal)
        }
        
        
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
            let rewardsTripCounts = Trip.bikeTripCountsGroupedByAttribute("rewardEmoji")
            for countData in rewardsTripCounts {
                if let rewardEmoji = countData["rewardEmoji"] as? String {
                      rewardString += rewardEmoji + "\t"
                    i += 1
                    if i>=columnCount {
                        i = 1
                        lineCount += 1
                        if let lastEmoji = rewardsTripCounts.last?["rewardEmoji"] as? String where lastEmoji == rewardEmoji  {
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
        
        let animationDelay: NSTimeInterval = 0.6
        
        if let currentStreakLength = Profile.profile().currentStreakLength?.integerValue where currentStreakLength > 0 {
            if currentStreakLength == 1 {
                if (Trip.bikeTripsToday() == nil) {
                    streakTextLabel.text = "You rode yesterday"
                    streakJewelLabel.text = "💖"
                } else {
                    streakTextLabel.text = "You rode today"
                    streakJewelLabel.text = "💖"
                }
                if (!self.hasShownStreakAnimation) {
                    self.hasShownStreakAnimation = true
                    streakJewelLabel.delay(animationDelay) { self.bobbleView(streakJewelLabel) }
                }
            } else if currentStreakLength == 2 {
                if (Trip.bikeTripsToday() == nil) {
                    streakTextLabel.text = "Ride today to start a ride streak!"
                    streakJewelLabel.text = "💗"
                } else {
                    streakTextLabel.text = "Ride tomorrow to start a ride streak"
                    streakJewelLabel.text = "💗"
                }
                if (!self.hasShownStreakAnimation) {
                    self.hasShownStreakAnimation = true
                    streakJewelLabel.delay(animationDelay) { self.beatHeart(streakJewelLabel) }
                }
            } else {
                if (Trip.bikeTripsToday() == nil) {
                    if (NSDate().isBeforeNoon()) {
                        streakTextLabel.text = String(format: "Keep your %i day streak rolling", currentStreakLength)
                        streakJewelLabel.text = "💗"
                    } else {
                        streakTextLabel.text = String(format: "Don't end your %i day streak!", currentStreakLength)
                        streakJewelLabel.text = "💔"
                    }
                } else {
                    streakTextLabel.text = String(format: "%i day ride streak", currentStreakLength)
                    streakJewelLabel.text = Profile.profile().currentStreakJewel
                }
                if (!self.hasShownStreakAnimation) {
                    self.hasShownStreakAnimation = true
                    streakJewelLabel.delay(animationDelay) { self.beatHeart(streakJewelLabel) }
                }
            }
        } else {
            streakTextLabel.text = "No rides today"
            streakJewelLabel.text = "🐣"
            if (!self.hasShownStreakAnimation) {
                self.hasShownStreakAnimation = true
                streakJewelLabel.delay(animationDelay) { self.bobbleView(streakJewelLabel) }
            }
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
    
    func configureCell(tableCell: UITableViewCell, trip: Trip) {
        guard let textLabel = tableCell.viewWithTag(1) as? UILabel, detailTextLabel = tableCell.viewWithTag(2) as? UILabel else {
            return
        }
        var dateTitle = ""
        if (trip.creationDate != nil) {
            dateTitle = String(format: "%@", self.timeFormatter.stringFromDate(trip.creationDate))
            
        }
        
        let areaDescriptionString = trip.areaDescriptionString
        var description = String(format: "%@ %@ for %@%@.", trip.climacon ?? "", dateTitle, trip.length.distanceString, (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        if let rewardDescription = trip.rewardDescription,
            rewardEmoji = trip.rewardEmoji where rewardDescription.rangeOfString("day ride streak") == nil {
            description += ("\n\n" + rewardEmoji + " " + rewardDescription)
        }
     
        textLabel.text = description
        
        if trip.isClosed {
            detailTextLabel.text = trip.activityType.emoji
        } else {
            detailTextLabel.text = ""
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.section == 0) {
            // handled via interface builder
            return
        }
        
        if let trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as? Trip {
            self.performSegueWithIdentifier("showTrip", sender: trip)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "showTrip") {
            if let tripVC = segue.destinationViewController as? TripViewController,
                trip = sender as? Trip {
                tripVC.selectedTrip = trip
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
                HealthKitManager.sharedManager.saveTrip(trip)
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