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
    @IBOutlet weak var greatButton: UIButton!
    @IBOutlet weak var notGreatButton: UIButton!
    @IBOutlet weak var changeModeButton: UIButton!
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet var buttonsViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var statsView: UIView!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var avgSpeedLabel: UILabel!
    
    private var feedbackGenerator: NSObject!
    
    private var blurEffect: UIBlurEffect!
    private var visualEffect: UIVisualEffectView!
    private var bluredView: UIVisualEffectView!
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    
    private var initialButtonsViewHeight: CGFloat = 0
    
    var maxY: CGFloat {
        get {
            guard buttonsView != nil else {
                return 0
            }
            
            if let trip = self.selectedTrip where trip.activityType == .Cycling {
                return statsView.frame.maxY
            }
            
            return buttonsView.frame.maxY + 10
        }
    }
    
    var peakUnratedY: CGFloat {
        get {
            guard buttonsView != nil else {
                return self.peakY
            }
            
            if self.selectedTrip.activityType == .Cycling {
                return buttonsView.frame.maxY + 10
            }
            
            return self.peakY
        }
    }
    
    var peakY: CGFloat {
        get {
            guard rewardDescriptionLabel != nil else {
                return 0
            }
            
            if let _ = self.selectedTrip.tripRewards.firstObject as? TripReward {
                return max(rewardDescriptionLabel.frame.maxY, rewardEmojiLabel.frame.maxY) + 10
            }
            return max(rideDescriptionLabel.frame.maxY, rideEmojiLabel.frame.maxY) + 10
        }
    }
    
    var selectedTrip : Trip! {
        didSet {
            if (self.selectedTrip != nil) {
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
        
        for button in [self.greatButton, self.notGreatButton] {
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.6
        }
        
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.Medium)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
    }
    
    func reloadUI() {
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
                    greatButton.hidden = false
                    notGreatButton.hidden = false
                    let buttonsViewHeight = self.changeModeButton.frame.height + 8 + 14.0 + self.greatButton.frame.size.height
                    buttonsView.frame.size.height = buttonsViewHeight
                    buttonsViewHeightConstraint?.constant = buttonsViewHeight
                } else {
                    statsView.hidden = true
                    greatButton.hidden = true
                    notGreatButton.hidden = true
                    let buttonsViewHeight = self.changeModeButton.frame.height + 16
                    buttonsView.frame.size.height = buttonsViewHeight
                    buttonsViewHeightConstraint?.constant = buttonsViewHeight
                }
                
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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.enabled = false
        
        initialButtonsViewHeight = self.buttonsView.frame.height
        
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
    
    @IBAction func changeMode(_: AnyObject) {
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionReveal
        transition.subtype = kCATransitionFromRight
        self.buttonsView.layer.addAnimation(transition, forKey: "transition")
        self.modeSelectorView.hidden = false
        self.buttonsView.hidden = true
        CATransaction.commit()
    }
    

    @IBAction func selectedNewMode(_: AnyObject) {
        if #available(iOS 10.0, *) {
            if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                feedbackGenerator.impactOccurred()
            }
        }
        
        let mode = self.modeSelectorView.selectedMode
        
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.modeSelectorView.layer.addAnimation(transition, forKey: "transition")
        self.modeSelectorView.hidden = true
        self.buttonsView.hidden = false
        CATransaction.commit()
        
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
    
    @IBAction func tappedNotGreat(_: AnyObject) {
        if #available(iOS 10.0, *) {
            if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                feedbackGenerator.impactOccurred()
            }
        }
        
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
    
    @IBAction func tappedGreat(_: AnyObject) {
        if #available(iOS 10.0, *) {
            if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                feedbackGenerator.impactOccurred()
            }
        }
        
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
}
