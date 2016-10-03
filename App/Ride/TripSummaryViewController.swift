//
//  TripSummaryViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/03/16.
//  Copyright (c) 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class TripSummaryViewController: UIViewController, RideSummaryViewDelegate, UIAlertViewDelegate {
    @IBOutlet weak var grabberBarView: UIView!
    @IBOutlet weak var editModeView: UIView!
    @IBOutlet weak var modeSelectorView: ModeSelectorView!
    @IBOutlet weak var rideEmojiLabel: UILabel!
    @IBOutlet weak var rideDescriptionLabel: UILabel!
    @IBOutlet weak var rewardEmojiLabel: UILabel!
    @IBOutlet weak var rewardDescriptionLabel: UILabel!
    
    private var blurEffect: UIBlurEffect!
    private var visualEffect: UIVisualEffectView!
    private var bluredView: UIVisualEffectView!
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    var selectedTrip : Trip! {
        didSet {
            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                guard let strongSelf = self, _ = strongSelf.rideDescriptionLabel else {
                    return
                }
                
                if (strongSelf.selectedTrip != nil) {
                    strongSelf.reloadUI()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        grabberBarView.layer.cornerRadius = 3
        grabberBarView.clipsToBounds = true
        
        self.editModeView.hidden = true
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
    }
    
    func reloadUI() {
        if (self.selectedTrip != nil) {
            let trip = self.selectedTrip
            var dateTitle = ""
            
            if (trip.locationsNotYetDownloaded) {
                self.rideDescriptionLabel.text = "Downloading Trip Data…"
                self.rideEmojiLabel.text = ""
                self.rewardEmojiLabel.text = ""
                self.rewardDescriptionLabel.text = ""
                return
            }
            
            if !self.selectedTrip.isClosed {
                rideEmojiLabel.text = "🏁"
                rideDescriptionLabel.text = String(format: "%@ starting at %@.", trip.inProgressLength.distanceString, trip.timeString())
                rewardEmojiLabel.text = ""
                rewardDescriptionLabel.text = ""
            } else {
                rideEmojiLabel.text = self.selectedTrip.climacon ?? ""
                rideDescriptionLabel.text = self.selectedTrip.displayStringWithTime()
                
                if let reward = self.selectedTrip.tripRewards.firstObject as? TripReward where reward.descriptionText.rangeOfString("day ride streak") == nil {
                    rewardEmojiLabel.text = reward.displaySafeEmoji
                    rewardDescriptionLabel.text = reward.descriptionText
                } else {
                    rewardEmojiLabel.text = ""
                    rewardDescriptionLabel.text = ""
                }
            }
        } else {
            self.rideDescriptionLabel.text = ""
            self.rideEmojiLabel.text = ""
            self.rewardEmojiLabel.text = ""
            self.rewardDescriptionLabel.text = ""
        }
    }
    
    func createBackgroundViewIfNeeded(){
        guard self.bluredView == nil else {
            return
        }
        
        blurEffect = UIBlurEffect.init(style: .Light)
        visualEffect = UIVisualEffectView.init(effect: blurEffect)
        bluredView = UIVisualEffectView.init(effect: blurEffect)
        bluredView.contentView.addSubview(visualEffect)
        
        visualEffect.frame = UIScreen.mainScreen().bounds
        bluredView.frame = UIScreen.mainScreen().bounds
        
        view.insertSubview(bluredView, atIndex: 0)
    }
    
    //
    // MARK: - UIVIewController
    //
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.enabled = false
        
        createBackgroundViewIfNeeded()
    }
    
    override func viewDidAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextObjectsDidChangeNotification, object: CoreDataManager.sharedManager.managedObjectContext, queue: nil) {[weak self] (notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.selectedTrip != nil else {
                return
            }
            
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? NSSet {
                if updatedObjects.containsObject(strongSelf.selectedTrip) {
                    let trip = strongSelf.selectedTrip
                    strongSelf.selectedTrip = trip
                }
            }
            
            if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? NSSet {
                if deletedObjects.containsObject(strongSelf.selectedTrip) {
                    strongSelf.selectedTrip = nil
                }
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    
    //
    // MARK: - UI Actions
    //
    

    @IBAction func selectedNewMode(sender: AnyObject) {
        let mode = self.modeSelectorView.selectedMode
        if mode != self.selectedTrip.activityType {
            self.selectedTrip.activityType = self.modeSelectorView.selectedMode
            APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
            
            self.reloadUI()
            
            let alert = UIAlertView(title: "Ride Report was confused 😬", message: "Would you like to report this misclassification so that Ride Report can get better in the future?", delegate: self, cancelButtonTitle: "Nah", otherButtonTitles: "Sure")
            alert.show()
        }
    }
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            let storyBoard = UIStoryboard(name: "Main", bundle: nil)
            let reportModeClassificationNavigationViewController = storyBoard.instantiateViewControllerWithIdentifier("ReportModeClassificationNavigationViewController") as! UINavigationController
            if let reportModeClassificationViewController = reportModeClassificationNavigationViewController.topViewController as? ReportModeClassificationViewController {
                reportModeClassificationViewController.trip = self.selectedTrip
            }
            self.presentViewController(reportModeClassificationNavigationViewController, animated: true, completion: nil)
        }
    }
    
    //
    // MARK: - Push Simulator View Actions
    //
    
    func didTapShareButton(view: RideSummaryView) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let rideShareNavVC = storyBoard.instantiateViewControllerWithIdentifier("RideShareNavViewController") as! UINavigationController
        if let rideShareVC = rideShareNavVC.topViewController as? RideShareViewController {
            rideShareVC.trip = self.selectedTrip
        }
        self.presentViewController(rideShareNavVC, animated: true, completion: nil)
    }
    
    func didTapDestructiveButton(view: RideSummaryView) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
    
    func didTapActionButton(view: RideSummaryView) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
}
