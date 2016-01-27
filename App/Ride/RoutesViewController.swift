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
import PNChart

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    @IBOutlet weak var emptyTableChick: UIView!
    
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerLabel1: UILabel!
    @IBOutlet weak var popupView: PopupView!
    
    private var dateOfLastTableRefresh: NSDate?

    private var reachability : Reachability!
    
    var pieChartModeShare: PNPieChart!
    var pieChartRatings: PNPieChart!
    var pieChartDaysBiked: PNPieChart!
    var pieChartWeather: PNPieChart!
    
    
    private var fetchedResultsController : NSFetchedResultsController! = nil

    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.navigationItem.hidesBackButton = true
        
        self.popupView.hidden = true
        
        self.headerView.backgroundColor = UIColor.clearColor()
        
        self.tableView.layoutMargins = UIEdgeInsetsZero
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mma"
        self.timeFormatter.AMSymbol = (self.timeFormatter.AMSymbol as NSString).lowercaseString
        self.timeFormatter.PMSymbol = (self.timeFormatter.PMSymbol as NSString).lowercaseString
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "bobbleChick")
        self.emptyTableChick.addGestureRecognizer(tapRecognizer)
        self.emptyTableView.hidden = true
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                self.coreDataDidLoad()
            }
        } else {
            self.coreDataDidLoad()
        }
    }
    
    func coreDataDidLoad() {
        let cacheName = "RoutesViewControllerFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: "sectionIdentifier", cacheName:cacheName )
        self.fetchedResultsController!.delegate = self
        do {
            try self.fetchedResultsController!.performFetch()
        } catch let error {
            DDLogError("Error loading trips view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        
        self.refreshEmptyTableView()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
        self.dateOfLastTableRefresh = NSDate()
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) { (_) in
            self.reloadTableIfNeeded()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        self.refreshEmptyTableView()
        
        self.refreshHelperPopupUI()
        
        self.reachability = Reachability.reachabilityForLocalWiFi()
        self.reachability.startNotifier()
        
        NSNotificationCenter.defaultCenter().addObserverForName(kReachabilityChangedNotification, object: nil, queue: nil) { (notif) -> Void in
            self.refreshHelperPopupUI()
        }
        
        if (self.tableView.indexPathForSelectedRow != nil) {
            self.tableView.deselectRowAtIndexPath(self.tableView.indexPathForSelectedRow!, animated: animated)
        }
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                self.refreshCharts()
            }
        } else {
            self.refreshCharts()
        }
    }
    
    func bobbleChick() {
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
        
        self.emptyTableChick.layer.addAnimation(shakeAnimation, forKey:"transform")
        
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
    
    private func reloadTableIfNeeded() {
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
        if (self.fetchedResultsController != nil) {
            let shouldHideEmptyTableView = (self.fetchedResultsController.fetchedObjects!.count > 0)
            let emptyTableViewWasHidden = self.emptyTableView.hidden
            
            self.emptyTableView.hidden = shouldHideEmptyTableView
            self.tableView.hidden = !shouldHideEmptyTableView
            
            if emptyTableViewWasHidden && !shouldHideEmptyTableView {
                self.emptyTableView.delay(0.5) {
                    self.bobbleChick()
                }
            }
        } else {
            self.emptyTableView.hidden = true
            self.tableView.hidden = true
        }
    }
    
    private func refreshCharts() {
        let count = Trip.numberOfCycledTrips
        if (count == 0) {
            self.title = "Ride Report"
            self.headerView.hidden = true
        } else {
            let numCharts = 4
            let margin: CGFloat = 16
            let chartWidth = (self.view.frame.size.width - (CGFloat(numCharts + 1)) * margin)/CGFloat(numCharts)
            
            self.title = String(format: "%i Rides", Trip.numberOfCycledTrips)
            
            Profile.profile().updateCurrentRideStreakLength()
            
            if let currentStreakLength = Profile.profile().currentStreakLength?.integerValue where currentStreakLength > 0 {
                if (Trip.bikeTripsToday() == nil) {
                    if (NSDate().isBeforeNoon()) {
                        self.headerLabel1.text = String(format: "💗  Keep your %i day streak rolling", currentStreakLength)
                    } else {
                        self.headerLabel1.text = String(format: "💔  Don't end your %i day streak!", currentStreakLength)
                    }
                } else {
                    self.headerLabel1.text = String(format: "%@  %i day ride streak", Profile.profile().currentStreakJewel, currentStreakLength)
                }
            } else {
                self.headerLabel1.text = "🐣  No rides today"
            }
            
            if count < 10 {
                // Don't show stats until they get to >=10 rides
                var headerFrame = self.headerView.frame
                headerFrame.size.height = self.headerLabel1.frame.size.height + 10
                self.headerView.frame = headerFrame
                self.tableView.tableHeaderView = self.headerView
                
                return
            } else {
                var headerFrame = self.headerView.frame
                headerFrame.size.height = chartWidth + margin + self.headerLabel1.frame.size.height + 50
                self.headerView.frame = headerFrame
                self.tableView.tableHeaderView = self.headerView
            }
            
            if let sections = self.fetchedResultsController.sections {
                let bikedDays = sections.count
                let firstTrip = (self.fetchedResultsController.fetchedObjects?.last as! Trip)
                let unbikedDays = firstTrip.creationDate.countOfDaysSinceNow() - sections.count + 1
                
                let daysBikedData = [PNPieChartDataItem(value: CGFloat((bikedDays)), color: ColorPallete.sharedPallete.goodGreen),
                    PNPieChartDataItem(value: CGFloat(unbikedDays), color: ColorPallete.sharedPallete.unknownGrey)]
                
                self.pieChartDaysBiked = PNPieChart(frame: CGRectMake(margin, margin, chartWidth, chartWidth), items: daysBikedData)
                self.pieChartDaysBiked.showOnlyDescriptions = true
                self.pieChartDaysBiked.strokeChart()
                self.pieChartDaysBiked.descriptionTextFont = UIFont.boldSystemFontOfSize(14)
                self.headerView.addSubview(self.pieChartDaysBiked)
                
                let daysBikedLabel = UILabel()
                daysBikedLabel.textColor = self.headerLabel1.textColor
                daysBikedLabel.font = UIFont.boldSystemFontOfSize(14)
                daysBikedLabel.adjustsFontSizeToFitWidth = true
                daysBikedLabel.minimumScaleFactor = 0.6
                daysBikedLabel.numberOfLines = 2
                daysBikedLabel.textAlignment = NSTextAlignment.Center
                daysBikedLabel.text = "All Time\nDays Biked"
                daysBikedLabel.sizeToFit()
                if daysBikedLabel.frame.width > chartWidth {
                    daysBikedLabel.frame = CGRectMake(daysBikedLabel.frame.origin.x, daysBikedLabel.frame.origin.y, chartWidth, daysBikedLabel.frame.size.height)
                }
                daysBikedLabel.frame = CGRectMake(margin + (chartWidth - daysBikedLabel.frame.width)/2, margin + 8 + chartWidth, daysBikedLabel.frame.width, daysBikedLabel.frame.height)
                self.headerView.addSubview(daysBikedLabel)
            }
            
            var modeShareData : [PNPieChartDataItem] = []
            var modeShareLabelTitle = ""
            let numCycledTripsAllTime = CGFloat(Trip.numberOfCycledTrips)
            let numCarTripsAllTime = CGFloat(Trip.numberOfAutomotiveTrips)
            
            if (numCycledTripsAllTime/numCarTripsAllTime >= 2) {
                // if they have at least a 2/3 mode share by bike, show all time
                modeShareData = [PNPieChartDataItem(value: numCycledTripsAllTime, color: ColorPallete.sharedPallete.goodGreen, description: "🚲"),
                    PNPieChartDataItem(value: numCarTripsAllTime, color: ColorPallete.sharedPallete.autoBrown, description: "🚗"),
                    PNPieChartDataItem(value: CGFloat(Trip.numberOfTransitTrips), color: ColorPallete.sharedPallete.transitBlue)]
                modeShareLabelTitle = "All Time\nMode Use"
            } else {
                // otherwise show last 30 days to make it more actionable
                modeShareData = [PNPieChartDataItem(value: CGFloat(Trip.numberOfCycledTripsLast30Days), color: ColorPallete.sharedPallete.goodGreen, description: "🚲"),
                    PNPieChartDataItem(value: CGFloat(Trip.numberOfAutomotiveTripsLast30Days), color: ColorPallete.sharedPallete.autoBrown, description: "🚗"),
                    PNPieChartDataItem(value: CGFloat(Trip.numberOfTransitTripsLast30Days), color: ColorPallete.sharedPallete.transitBlue)]
                modeShareLabelTitle = "Mode Use\nThis Month"
            }
            
            self.pieChartModeShare = PNPieChart(frame: CGRectMake(margin*2 + chartWidth, margin, chartWidth, chartWidth), items: modeShareData)
            self.pieChartModeShare.showOnlyDescriptions = true
            self.pieChartModeShare.strokeChart()
            self.pieChartModeShare.descriptionTextFont = UIFont.boldSystemFontOfSize(14)
            self.headerView.addSubview(self.pieChartModeShare)
            let modeShareLabel = UILabel()
            modeShareLabel.textColor = self.headerLabel1.textColor
            modeShareLabel.font = UIFont.boldSystemFontOfSize(14)
            modeShareLabel.adjustsFontSizeToFitWidth = true
            modeShareLabel.minimumScaleFactor = 0.6
            modeShareLabel.numberOfLines = 2
            modeShareLabel.textAlignment = NSTextAlignment.Center
            modeShareLabel.text = modeShareLabelTitle
            modeShareLabel.sizeToFit()
            if modeShareLabel.frame.width > chartWidth {
                modeShareLabel.frame = CGRectMake(modeShareLabel.frame.origin.x, modeShareLabel.frame.origin.y, chartWidth, modeShareLabel.frame.size.height)
            }
            modeShareLabel.frame = CGRectMake(margin*2 + chartWidth + (chartWidth - modeShareLabel.frame.width)/2, margin + 8 + chartWidth, modeShareLabel.frame.width, modeShareLabel.frame.height)
            self.headerView.addSubview(modeShareLabel)

            var ratingsData : [PNPieChartDataItem] = []
            for countData in Trip.bikeTripCountsGroupedByAttribute("rating") {
                if let rating = countData["rating"] as? NSNumber,
                    count = countData["count"]  as? NSNumber {
                    if rating.shortValue == Trip.Rating.NotSet.rawValue {
                        ratingsData.append(PNPieChartDataItem(value: CGFloat(count.floatValue), color: ColorPallete.sharedPallete.unknownGrey))
                    } else if rating.shortValue == Trip.Rating.Good.rawValue {
                        ratingsData.append(PNPieChartDataItem(value: CGFloat(count.floatValue), color: ColorPallete.sharedPallete.goodGreen, description: "👍"))
                    } else if rating.shortValue == Trip.Rating.Bad.rawValue {
                        ratingsData.append(PNPieChartDataItem(value: CGFloat(count.floatValue), color: ColorPallete.sharedPallete.badRed, description: "👎"))
                    }
                }
            }
            
            self.pieChartRatings = PNPieChart(frame: CGRectMake(margin*3 + 2*chartWidth, margin, chartWidth, chartWidth), items: ratingsData)
            self.pieChartRatings.showOnlyDescriptions = true
            self.pieChartRatings.strokeChart()
            self.pieChartRatings.descriptionTextFont = UIFont.boldSystemFontOfSize(14)
            self.headerView.addSubview(self.pieChartRatings)
            let ratingsLabel = UILabel()
            ratingsLabel.textColor = self.headerLabel1.textColor
            ratingsLabel.font = UIFont.boldSystemFontOfSize(14)
            ratingsLabel.adjustsFontSizeToFitWidth = true
            ratingsLabel.minimumScaleFactor = 0.6
            ratingsLabel.text = "Ratings"
            ratingsLabel.sizeToFit()
            if ratingsLabel.frame.width > chartWidth {
                ratingsLabel.frame = CGRectMake(ratingsLabel.frame.origin.x, ratingsLabel.frame.origin.y, chartWidth, ratingsLabel.frame.size.height)
            }
            ratingsLabel.frame = CGRectMake(margin*3 + chartWidth*2 + (chartWidth - ratingsLabel.frame.width)/2, margin + 8 + chartWidth, ratingsLabel.frame.width, ratingsLabel.frame.height)
            self.headerView.addSubview(ratingsLabel)
            
            var weatherData : [PNPieChartDataItem] = []
            for countData in Trip.bikeTripCountsGroupedByAttribute("climacon") {
                if let climacon = countData["climacon"] as? String,
                    count = countData["count"]  as? NSNumber {
                        if climacon == "☀️" {
                            weatherData.append(PNPieChartDataItem(value: CGFloat(count.floatValue), color: ColorPallete.sharedPallete.goodGreen, description: "☀️"))
                        } else if climacon == "☔️" {
                            weatherData.append(PNPieChartDataItem(value: CGFloat(count.floatValue), color: ColorPallete.sharedPallete.unknownGrey, description: "☔️"))
                        } else if climacon == "❄️" {
                            weatherData.append(PNPieChartDataItem(value: CGFloat(count.floatValue), color: ColorPallete.sharedPallete.transitBlue, description: "❄️"))
                        }
                }
            }
            
            self.pieChartWeather = PNPieChart(frame: CGRectMake(margin*4 + 3*chartWidth, margin, chartWidth, chartWidth), items: weatherData)
            self.pieChartWeather.showOnlyDescriptions = true
            self.pieChartWeather.strokeChart()
            self.pieChartWeather.descriptionTextFont = UIFont.boldSystemFontOfSize(14)
            self.headerView.addSubview(self.pieChartWeather)
            let weatherLabel = UILabel()
            weatherLabel.textColor = self.headerLabel1.textColor
            weatherLabel.font = UIFont.boldSystemFontOfSize(14)
            weatherLabel.adjustsFontSizeToFitWidth = true
            weatherLabel.minimumScaleFactor = 0.6
            weatherLabel.numberOfLines = 2
            weatherLabel.textAlignment = NSTextAlignment.Center
            weatherLabel.text = "Weather\nBiked In"
            weatherLabel.sizeToFit()
            if weatherLabel.frame.width > chartWidth {
                weatherLabel.frame = CGRectMake(weatherLabel.frame.origin.x, weatherLabel.frame.origin.y, chartWidth, weatherLabel.frame.size.height)
            }
            weatherLabel.frame = CGRectMake(margin*4 + chartWidth*3 + (chartWidth - weatherLabel.frame.width)/2, margin + 8 + chartWidth, weatherLabel.frame.width, weatherLabel.frame.height)
            self.headerView.addSubview(weatherLabel)
        }
    }
    
    func unloadFetchedResultsController() {
        self.fetchedResultsController?.delegate = nil
        self.fetchedResultsController = nil
    }

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.refreshEmptyTableView()
        // reload the rewards section as needed
        self.tableView!.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Fade)
        
        self.tableView.endUpdates()
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
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Update:
            let trip = self.fetchedResultsController.objectAtIndexPath(indexPath!) as! Trip
            let cell = self.tableView!.cellForRowAtIndexPath(NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1))
            if (cell != nil) {
                configureCell(cell!, trip:trip)
            }
            
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
        
        return 22
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 48
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "  Rewards"
        }
        
        let theSection = self.fetchedResultsController.sections![section - 1]
        
        return "  ".stringByAppendingString(theSection.name)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if Trip.numberOfRewardedTrips > 0 {
                return 1
            } else {
                return 0
            }
        }
        
        let sectionInfo = self.fetchedResultsController.sections![section - 1]
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let tableCell : UITableViewCell!
        
        if indexPath.section == 0 {
            let reuseID = "RewardsViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
            tableCell.layoutMargins = UIEdgeInsetsZero
            
            configureRewardsCell(tableCell)
        }  else {
            let reuseID = "RoutesViewTableCell"
            
            tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath)
            tableCell.layoutMargins = UIEdgeInsetsZero

            let trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
            configureCell(tableCell, trip: trip)
        }
        
        return tableCell
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.tintColor = ColorPallete.sharedPallete.unknownGrey
        headerView.opaque = false
        headerView.textLabel!.font = UIFont.boldSystemFontOfSize(14.0)
        headerView.textLabel!.textColor = self.headerLabel1.textColor
    }
    
    func configureRewardsCell(tableCell: UITableViewCell) {
        if let text1 = tableCell.viewWithTag(1) as? UILabel {
            var rewardString = ""
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1.2
            
            let emojiWidth = ("👍" as NSString).sizeWithAttributes([NSFontAttributeName: text1.font]).width
            let crossWidth = ("x" as NSString).sizeWithAttributes([NSFontAttributeName: text1.font]).width
            let countWidth = ("99" as NSString).sizeWithAttributes([NSFontAttributeName: text1.font]).width
            let columnSeperatorWidth : CGFloat = 10
            let totalWidth = emojiWidth + crossWidth + countWidth + columnSeperatorWidth
            
            var tabStops : [NSTextTab] = []
            var totalLineWidth : CGFloat = 0
            var columnCount = 0
            while totalLineWidth + totalWidth < text1.frame.size.width {
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Center, location: totalLineWidth + emojiWidth , options: [NSTabColumnTerminatorsAttributeName:NSCharacterSet(charactersInString:"x")]))
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Right, location: totalLineWidth + emojiWidth + crossWidth + countWidth, options: [:]))
                tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Left, location: totalLineWidth + emojiWidth + crossWidth + countWidth + columnSeperatorWidth, options: [:]))
                totalLineWidth += totalWidth
                columnCount += 1
                print(String(totalLineWidth))
            }
            
            paragraphStyle.tabStops = tabStops
            
            var i = 0
            var lineCount = 0
            let rewardsTripCounts = Trip.bikeTripCountsGroupedByAttribute("rewardEmoji")
            for countData in rewardsTripCounts {
                if let rewardEmoji = countData["rewardEmoji"] as? String,
                    count = countData["count"]  as? NSNumber {
                      rewardString += rewardEmoji + "×\t" + count.stringValue  + "\t"
                    i += 1
                    if i>=columnCount {
                        i = 0
                        lineCount += 1
                        rewardString += "\n"
                    }
                }
            }
        
            let attrString = NSMutableAttributedString(string: rewardString)
            attrString.addAttribute(NSParagraphStyleAttributeName, value:paragraphStyle, range:NSMakeRange(0, attrString.length))

            text1.attributedText = attrString
        }
    }
    
    func configureCell(tableCell: UITableViewCell, trip: Trip) {
        var ratingString = "  "
        if (trip.activityType.shortValue != Trip.ActivityType.Cycling.rawValue) {
            // for non-bike trips, show activity type instead of a rating
            ratingString = trip.activityTypeString()
        } else if (trip.incidents != nil && trip.incidents.count > 0) {
            ratingString = "🚩"
        } else if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
            ratingString = "👍"
        } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
            ratingString = "👎"
        }
        
        var dateTitle = ""
        if (trip.creationDate != nil) {
            dateTitle = String(format: "%@", self.timeFormatter.stringFromDate(trip.creationDate))
            
        }
        
        var rewardString = ""
        if let emoji = trip.rewardEmoji {
            rewardString = " " + emoji
        }
        
        var lengthString = String(format: "%.1f miles", trip.lengthMiles)
        if (trip.lengthMiles < 0.2) {
            // rounded to nearest 50
            lengthString = String(format: "%.0f feet", round(Float(trip.lengthFeet)/50) * 50.0)
        }
        
        tableCell.textLabel!.text = String(format: "%@ %@ %@ for %@%@", trip.climacon ?? "",  trip.isSynced ? "" : "🔹", dateTitle, lengthString, rewardString)
        
        tableCell.detailTextLabel!.text = String(format: "%@", ratingString)
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
        
        if let directionsVC = directionsNavController.topViewController as? DirectionsViewController {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                directionsVC.mapViewController.mapView.attributionButton.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
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
        
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete") { (action, indexPath) -> Void in
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
            APIClient.sharedClient.deleteTrip(trip)
        }
        
    #if DEBUG
        let toolsAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "🐞 Tools") { (action, indexPath) -> Void in
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
            self.tableView.setEditing(false, animated: true)
            
            var smoothButtonTitle = ""
            if (trip.hasSmoothed) {
                smoothButtonTitle = "Unsmooth"
            } else {
                smoothButtonTitle = "Smooth"
            }
            
            UIActionSheet.showInView(self.view, withTitle: nil, cancelButtonTitle: nil, destructiveButtonTitle: nil, otherButtonTitles: ["Query Core Motion Acitivities", smoothButtonTitle, "Simulate Ride End", "Sync trip"], tapBlock: { (actionSheet, tappedIndex) -> Void in
                self.tappedButtonIndex(tappedIndex, trip: trip)
            })
        }
        return [deleteAction, toolsAction]
    #else
        return [deleteAction]
    #endif
    }
    
    func tappedButtonIndex(buttonIndex: Int, trip: Trip) {
        if (buttonIndex == 0) {
            trip.clasifyActivityType({})
        } else if (buttonIndex == 1) {
            if (trip.hasSmoothed) {
                trip.undoSmoothWithCompletionHandler({})
            } else {
                trip.smoothIfNeeded({})
            }
        } else if (buttonIndex == 2) {
            trip.sendTripCompletionNotificationLocally(forFutureDate: NSDate().secondsFrom(5))
        } else if (buttonIndex == 3) {
            APIClient.sharedClient.syncTrip(trip)
        }
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