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
    @IBOutlet weak var headerLabel2: UILabel!
    @IBOutlet weak var headerLabel3: UILabel!
    
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
            self.title = "No Trips"
            self.headerView.hidden = false
        } else {
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = NSLocale.currentLocale()
            dateFormatter.dateStyle = .ShortStyle
            
            let numCharts = 4
            let margin: CGFloat = 16
            let chartWidth = (self.view.frame.size.width - (CGFloat(numCharts + 1)) * margin)/CGFloat(numCharts)
            
            var headerFrame = self.headerView.frame;
            headerFrame.size.height = chartWidth + margin + self.headerLabel1.frame.size.height + self.headerLabel2.frame.size.height + 86
            self.headerView.frame = headerFrame
            self.tableView.tableHeaderView = self.headerView
            
            self.title = String(format: "%i Trips ", Trip.numberOfCycledTrips)
            
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
            
            self.headerLabel2.text = String(format: "%@  Longest streak: %i days on %@", Profile.profile().longestStreakJewel, Profile.profile().longestStreakLength.integerValue, dateFormatter.stringFromDate(Profile.profile().longestStreakStartDate))

            
            if let sections = self.fetchedResultsController.sections {
                let bikedDays = sections.count
                let firstTrip = (self.fetchedResultsController.fetchedObjects?.last as! Trip)
                let unbikedDays = firstTrip.creationDate.countOfDaysSinceNow() - sections.count
                
                let formatter = NSNumberFormatter()
                formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
                formatter.maximumFractionDigits = 0
                
                let totalMiles = Trip.totalCycledMiles
                let jewel = { ()->String in
                    if totalMiles > 5000 {
                        return "🌈  "
                    } else if totalMiles > 2000 {
                        return "🌌  "
                    } else if totalMiles > 1000 {
                        return "🌠  "
                    } else if totalMiles > 500 {
                        return "🌋  "
                    } else if totalMiles > 100 {
                        return "🗻  "
                    } else if totalMiles > 50 {
                        return "🏔  "
                    } else if totalMiles > 25 {
                        return "⛰  "
                    } else if totalMiles > 10 {
                        return "🌅  "
                    } else {
                        return "🌄  "
                    }
                }()
                self.headerLabel3.text = String(format: "%@%@ miles biked since %@", jewel, formatter.stringFromNumber(NSNumber(float: totalMiles))!, dateFormatter.stringFromDate(firstTrip.creationDate))
                
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

            
            let ratingsData = [PNPieChartDataItem(value: CGFloat(Trip.numberOfGoodTrips), color: ColorPallete.sharedPallete.goodGreen, description: "👍"),
                PNPieChartDataItem(value: CGFloat(Trip.numberOfBadTrips), color: ColorPallete.sharedPallete.badRed, description: "👎"),
                PNPieChartDataItem(value: CGFloat(Trip.numberOfUnratedTrips), color: ColorPallete.sharedPallete.unknownGrey)]
            
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
            
            let weatherData = [PNPieChartDataItem(value: CGFloat(Trip.numberOfWarmSunnyTrips), color: ColorPallete.sharedPallete.goodGreen, description: "☀️"),
                PNPieChartDataItem(value: CGFloat(Trip.numberOfRainyTrips), color: ColorPallete.sharedPallete.unknownGrey, description: "☔️"),
                PNPieChartDataItem(value: CGFloat(Trip.numberOfColdTrips), color: ColorPallete.sharedPallete.transitBlue, description: "❄️")]
            
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
            self.tableView!.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: UITableViewRowAnimation.Fade)
        case .Move, .Update:
            // do nothing
            DDLogVerbose("Move/update section. Shouldn't happen?")
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch(type) {
            
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
            
        case .Update:
            let trip = self.fetchedResultsController.objectAtIndexPath(indexPath!) as! Trip
            let cell = self.tableView!.cellForRowAtIndexPath(indexPath!)
            if (cell != nil) {
                configureCell(cell!, trip:trip)
            }
            
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([indexPath!],
                withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([newIndexPath!],
                withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections!.count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let theSection = self.fetchedResultsController.sections![section] 
        
        return "  ".stringByAppendingString(theSection.name)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] 
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
        let reuseID = "RoutesViewTableCell"
        
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID, forIndexPath: indexPath) 
        tableCell.layoutMargins = UIEdgeInsetsZero

        configureCell(tableCell, trip: trip)
        
        return tableCell
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.tintColor = UIColor(white: 0.2, alpha: 1.0)
        headerView.opaque = false
        headerView.textLabel!.font = UIFont.boldSystemFontOfSize(14.0)
        headerView.textLabel!.textColor = UIColor(white: 0.9, alpha: 1.0)
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
        tableCell.textLabel!.text = String(format: "%@ %@ %@ for %.1f miles", trip.climoticon,  trip.isSynced ? "" : "🔹", dateTitle, trip.lengthMiles)
        
        tableCell.detailTextLabel!.text = String(format: "%@", ratingString)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.mainViewController.selectedTrip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
        
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
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete") { (action, indexPath) -> Void in
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
            APIClient.sharedClient.deleteTrip(trip)
        }
        
    #if DEBUG
        let toolsAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "🐞 Tools") { (action, indexPath) -> Void in
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
            self.tableView.setEditing(false, animated: true)
            
            var smoothButtonTitle = ""
            if (trip.hasSmoothed) {
                smoothButtonTitle = "Unsmooth"
            } else {
                smoothButtonTitle = "Smooth"
            }
            
            UIActionSheet.showInView(self.view, withTitle: nil, cancelButtonTitle: nil, destructiveButtonTitle: nil, otherButtonTitles: ["Query Core Motion Acitivities", smoothButtonTitle, "Simulate Ride End", "Sync to Server"], tapBlock: { (actionSheet, tappedIndex) -> Void in
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
                trip.sendTripCompletionNotification() {
                    if (backgroundTaskID != UIBackgroundTaskInvalid) {
                        UIApplication.sharedApplication().endBackgroundTask(backgroundTaskID)
                    }
                }
            })
        } else if (buttonIndex == 3) {
            APIClient.sharedClient.saveAndSyncTripIfNeeded(trip)
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            let trip : Trip = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Trip
            APIClient.sharedClient.deleteTrip(trip)
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
}