//
//  RoutesViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import PNChart

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerLabel1: UILabel!
    
    var pieChartModeShare: PNPieChart!
    var pieChartRatings: PNPieChart!
    var pieChartDaysBiked: PNPieChart!
    var pieChartWeather: PNPieChart!
    
    var mainViewController: MainViewController! = nil
    
    
    private var fetchedResultsController : NSFetchedResultsController! = nil

    private var timeFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        
        self.headerView.backgroundColor = UIColor.clearColor()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: UIBarButtonItemStyle.Plain, target: self, action: "pop")
        
        let blur = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let effectView = UIVisualEffectView(effect: blur)
        effectView.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
        self.view.insertSubview(effectView, belowSubview: self.tableView)
        
        self.tableView.layoutMargins = UIEdgeInsetsZero
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mma"
        
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
        self.refreshCharts()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.mainViewController.selectedTrip = nil
        self.refreshEmptyTableView()
        
        if (self.tableView.indexPathForSelectedRow != nil) {
            self.tableView.deselectRowAtIndexPath(self.tableView.indexPathForSelectedRow!, animated: animated)
        }
    }
    
    private func refreshEmptyTableView() {
        if (self.fetchedResultsController != nil) {
            let shouldHideEmptyTableView = (self.fetchedResultsController.fetchedObjects!.count > 0)
            self.emptyTableView.hidden = shouldHideEmptyTableView
            self.tableView.hidden = !shouldHideEmptyTableView
        } else {
            self.emptyTableView.hidden = true
            self.tableView.hidden = true
        }
    }
    
    private func refreshCharts() {
        let count = Trip.numberOfCycledTrips
        if (count == 0) {
            self.title = "No Rides"
            self.headerView.hidden = false
        } else {
            let numCharts = 4
            let margin: CGFloat = 16
            let chartWidth = (self.view.frame.size.width - (CGFloat(numCharts + 1)) * margin)/CGFloat(numCharts)
            
            var headerFrame = self.headerView.frame;
            headerFrame.size.height = chartWidth + margin + self.headerLabel1.frame.size.height + 50
            self.headerView.frame = headerFrame
            self.tableView.tableHeaderView = self.headerView
            
            self.title = String(format: "%i Rides ", Trip.numberOfCycledTrips)
            
            Profile.profile().updateCurrentRideStreakLength()

            if Profile.profile().currentStreakLength.integerValue == 0 {
                self.headerLabel1.text = "🐣  No rides today"
            } else {
                if (Trip.bikeTripsToday() == nil) {
                    if (NSDate().isBeforeNoon()) {
                        self.headerLabel1.text = String(format: "💗  Keep your %i day streak rolling", Profile.profile().currentStreakLength.integerValue)
                    } else {
                        self.headerLabel1.text = String(format: "💔  Don't end your %i day streak!", Profile.profile().currentStreakLength.integerValue)
                    }
                } else {
                    self.headerLabel1.text = String(format: "%@  %i day ride streak", Profile.profile().currentStreakJewel, Profile.profile().currentStreakLength.integerValue)
                }
            }
            
            if let sections = self.fetchedResultsController.sections {
                let bikedDays = sections.count
                let firstTrip = (self.fetchedResultsController.fetchedObjects?.last as! Trip)
                let unbikedDays = firstTrip.creationDate.countOfDaysSinceNow() - sections.count
                
                let daysBikedData = [PNPieChartDataItem(value: CGFloat((bikedDays)), color: ColorPallete.sharedPallete.goodGreen),
                    PNPieChartDataItem(value: CGFloat(unbikedDays), color: ColorPallete.sharedPallete.unknownGrey)]
                
                self.pieChartDaysBiked = PNPieChart(frame: CGRectMake(margin, margin, chartWidth, chartWidth), items: daysBikedData)
                self.pieChartDaysBiked.showOnlyDescriptions = true
                self.pieChartDaysBiked.strokeChart()
                self.pieChartDaysBiked.descriptionTextFont = UIFont.boldSystemFontOfSize(14)
                self.headerView.addSubview(self.pieChartDaysBiked)
                
                let daysBikedLabel = UILabel()
                daysBikedLabel.textColor = UIColor.whiteColor()
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
            modeShareLabel.textColor = UIColor.whiteColor()
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
            for countData in Trip.bikeTripCountsGroupedByProperty("rating") {
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
            ratingsLabel.textColor = UIColor.whiteColor()
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
            for countData in Trip.bikeTripCountsGroupedByProperty("climacon") {
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
            weatherLabel.textColor = UIColor.whiteColor()
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
            return 1
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
        headerView.tintColor = UIColor(white: 0.2, alpha: 1.0)
        headerView.opaque = false
        headerView.textLabel!.font = UIFont.boldSystemFontOfSize(14.0)
        headerView.textLabel!.textColor = UIColor(white: 0.9, alpha: 1.0)
    }
    
    func configureRewardsCell(tableCell: UITableViewCell) {
        var rewardString = ""

        for countData in Trip.bikeTripCountsGroupedByProperty("rewardEmoji") {
            if let rewardEmoji = countData["rewardEmoji"] as? String,
                count = countData["count"]  as? NSNumber {
                  rewardString += count.stringValue + "x" + rewardEmoji + " "
            }
        }
        
        if let text1 = tableCell.viewWithTag(1) as? UILabel {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1.2
            
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
        
        tableCell.textLabel!.text = String(format: "%@ %@ %@ for %.1f miles%@", trip.climacon ?? "",  trip.isSynced ? "" : "🔹", dateTitle, trip.lengthMiles, rewardString)
        
        tableCell.detailTextLabel!.text = String(format: "%@", ratingString)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.section == 0) {
            // handled via interface builder
            return
        }
        
        self.mainViewController.selectedTrip = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: indexPath.section - 1)) as! Trip
        
        self.pop()
    }
    
    func pop() {
        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionReveal
        transition.subtype = kCATransitionFromTop
        
        self.mainViewController.navigationController?.view.layer.addAnimation(transition, forKey: kCATransition)
        self.mainViewController.navigationController?.popToRootViewControllerAnimated(false)
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
            let backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            })
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                trip.sendTripCompletionNotificationLocally()
                if (backgroundTaskID != UIBackgroundTaskInvalid) {
                    UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
                }
            })
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