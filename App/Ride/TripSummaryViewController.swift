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
    @IBOutlet weak var modeSelectorView: ModeSelectorView!
    @IBOutlet weak var rideEmojiLabel: UILabel!
    @IBOutlet weak var rideDescriptionLabel: UILabel!
    @IBOutlet weak var rewardEmojiLabel: UILabel!
    @IBOutlet weak var rewardDescriptionLabel: UILabel!
    
    @IBOutlet weak var changeModeButton: UIButton!
    @IBOutlet weak var changeModeLabel: UILabel!
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet weak var statsView: UIView!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var avgSpeedLabel: UILabel!
    
    @IBOutlet weak var ratingChoiceSelector: RatingChoiceSelectorView!
    @IBOutlet var ratingChoiceHeightConstraint: NSLayoutConstraint!
    private var initialRatingChoiceHeight: CGFloat = 0

    private var blurEffect: UIBlurEffect!
    private var visualEffect: UIVisualEffectView!
    private var bluredView: UIVisualEffectView!
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    var maxY: CGFloat {
        get {
            guard buttonsView != nil else {
                return 0
            }
            
            if let trip = self.selectedTrip where trip.activityType == .Cycling {
                return statsView.frame.maxY
            }
            
            return buttonsView.frame.maxY
        }
    }

    var peakY: CGFloat {
        get {
            guard rewardDescriptionLabel != nil else {
                return 0
            }
            
            return buttonsView.frame.maxY
        }
    }
    
    var selectedTrip : Trip! {
        didSet {
            if (self.selectedTrip != nil) {
                self.ratingChoiceSelector.selectedRating = self.selectedTrip.rating.choice
                reloadUI()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        grabberBarView.layer.cornerRadius = 3
        grabberBarView.clipsToBounds = true
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
        
        self.modeSelectorView.hidden = true
        self.changeModeLabel.hidden = true
        
        self.initialRatingChoiceHeight = self.ratingChoiceHeightConstraint.constant
    }
    
    func reloadUI() {
        if (!modeSelectorView.hidden) {
            // dont reload the UI if the user is currently picking a mode
            return
        }
        
        if (self.selectedTrip != nil) {
            let trip = self.selectedTrip
            
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
                if self.selectedTrip.activityType == .Cycling {
                    durationLabel.text = self.selectedTrip.duration().intervalString
                    avgSpeedLabel.text = self.selectedTrip.averageBikingSpeed.string
                    statsView.hidden = false
                    ratingChoiceSelector.hidden = false

                    ratingChoiceHeightConstraint?.constant = initialRatingChoiceHeight
                } else {
                    statsView.hidden = true
                    ratingChoiceSelector.hidden = true

                    ratingChoiceHeightConstraint?.constant = 0
                }
                
                ratingChoiceSelector.setNeedsUpdateConstraints()
                UIView.animateWithDuration(0.25, animations: {
                    self.ratingChoiceSelector.layoutIfNeeded()
                })
                
                self.changeModeButton.setTitle("Not a " + trip.activityType.noun + "?", forState: .Normal)

                rideEmojiLabel.text = self.selectedTrip.climacon ?? ""
                rideDescriptionLabel.text = self.selectedTrip.displayStringWithTime()
                
                if let reward = self.selectedTrip.tripRewards.firstObject as? TripReward {
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
    
    override func viewDidLayoutSubviews() {
        NSNotificationCenter.defaultCenter().postNotificationName("TripSummaryViewDidChangeHeight", object: nil)
    }
    
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
    
    @IBAction func changedRating(_: AnyObject) {
        self.selectedTrip.rating = Rating.ratingWithCurrentVersion(ratingChoiceSelector.selectedRating)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        self.reloadUI()
    }
    
    @IBAction func changeMode(_: AnyObject) {
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionReveal
        transition.subtype = kCATransitionFromRight
        
        self.buttonsView.layer.addAnimation(transition, forKey: "transition")
        
        ratingChoiceHeightConstraint?.constant = initialRatingChoiceHeight
        ratingChoiceSelector.setNeedsUpdateConstraints()
        UIView.animateWithDuration(0.25, animations: {
            self.ratingChoiceSelector.layoutIfNeeded()
        })
        self.modeSelectorView.selectedSegmentIndex = UISegmentedControlNoSegment
        self.modeSelectorView.hidden = false
        self.ratingChoiceSelector.hidden = true
        self.changeModeButton.hidden = true
        self.changeModeLabel.hidden = false
        CATransaction.commit()
    
        NSNotificationCenter.defaultCenter().postNotificationName("TripSummaryViewDidChangeHeight", object: nil)
    }

    @IBAction func selectedNewMode(_: AnyObject) {
        let mode = self.modeSelectorView.selectedMode
        
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.modeSelectorView.layer.addAnimation(transition, forKey: "transition")
        self.ratingChoiceSelector.layer.addAnimation(transition, forKey: "transition")
        self.modeSelectorView.hidden = true
        self.ratingChoiceSelector.hidden = false
        self.changeModeButton.hidden = false
        self.changeModeLabel.hidden = true

        CATransaction.commit()
        
        if mode != self.selectedTrip.activityType {
            self.selectedTrip.activityType = self.modeSelectorView.selectedMode
            APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
            
            self.reloadUI()
            
            let alert = UIAlertView(title: "Ride Report was confused 😬", message: "Would you like to report this misclassification so that Ride Report can get better in the future?", delegate: self, cancelButtonTitle: "Nah", otherButtonTitles: "Sure")
            alert.show()
        } else {
            self.reloadUI()
        }
        NSNotificationCenter.defaultCenter().postNotificationName("TripSummaryViewDidChangeHeight", object: nil)
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
    
    @IBAction func tappedNotGreat(_: AnyObject) {
        self.selectedTrip.rating = Rating.ratingWithCurrentVersion(RatingChoice.Bad)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
    
    @IBAction func tappedGreat(_: AnyObject) {
        self.selectedTrip.rating = Rating.ratingWithCurrentVersion(RatingChoice.Good)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
    
    @IBAction func tappedMixed(_: AnyObject) {
        self.selectedTrip.rating = Rating.ratingWithCurrentVersion(RatingChoice.Mixed)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
}
