//
//  TripSummaryViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/03/16.
//  Copyright (c) 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class TripSummaryViewController: UIViewController, UIAlertViewDelegate, RideSummaryViewDelegate {
    @IBOutlet weak var grabberBarView: UIView!
    @IBOutlet weak var modeSelectorView: ModeSelectorView!
    @IBOutlet weak var rideSummaryView: RideSummaryView!
    
    @IBOutlet weak var changeModeButton: UIButton!
    @IBOutlet weak var changeModeLabel: UILabel!
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet weak var statsView: UIView!
    @IBOutlet weak var statsView2: UIView!
    
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var calorieLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var avgSpeedLabel: UILabel!
    
    @IBOutlet weak var ratingChoiceSelector: RatingChoiceSelectorView!
    @IBOutlet var ratingChoiceHeightConstraint: NSLayoutConstraint!
    private var initialRatingChoiceHeight: CGFloat = 0

    private var blurEffect: UIBlurEffect!
    private var visualEffect: UIVisualEffectView!
    private var bluredView: UIVisualEffectView!
    
    private var timeFormatter : DateFormatter!
    private var dateFormatter : DateFormatter!
    
    var maxY: CGFloat {
        get {
            guard buttonsView != nil else {
                return 0
            }
            
            if let trip = self.selectedTrip, trip.activityType == .cycling {
                return statsView2.frame.maxY
            }
            
            return buttonsView.frame.maxY
        }
    }
    
    var minY: CGFloat {
        get {
            guard rideSummaryView != nil else {
                return 0
            }
            
            return buttonsView.frame.minY
        }
    }

    var peakY: CGFloat {
        get {
            guard rideSummaryView != nil else {
                return 0
            }
            
            return buttonsView.frame.maxY
        }
    }
    
    var selectedTrip : Trip! {
        didSet {
            if (self.selectedTrip != nil) {
                self.ratingChoiceSelector.selectedRating = self.selectedTrip.rating
                reloadUI()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.rideSummaryView.delegate = self
        
        grabberBarView.layer.cornerRadius = 3
        grabberBarView.clipsToBounds = true
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = DateFormatter()
        self.timeFormatter.locale = Locale.current
        self.timeFormatter.dateFormat = "h:mm a"
        
        self.modeSelectorView.isHidden = true
        self.changeModeLabel.isHidden = true
        
        self.initialRatingChoiceHeight = self.ratingChoiceHeightConstraint.constant
    }
    
    func reloadUI() {
        if (!modeSelectorView.isHidden) {
            // dont reload the UI if the user is currently picking a mode
            return
        }
        
        if !self.selectedTrip.isClosed {
            if (rideSummaryView.tripLength != self.selectedTrip.inProgressLength) {
                rideSummaryView.setTripSummary(tripLength: self.selectedTrip.inProgressLength, description: String(format: "Trip started at %@.", self.selectedTrip.timeString()))
                rideSummaryView.setRewards([])
            }
        } else {
            var rewardDicts: [[String: Any]] = []
            for element in self.selectedTrip.tripRewards {
                if let reward = element as? TripReward {
                    var rewardDict: [String: Any] = [:]
                    rewardDict["object"] = reward
                    rewardDict["rewardUUID"] = reward.rewardUUID
                    rewardDict["displaySafeEmoji"] = reward.displaySafeEmoji
                    rewardDict["descriptionText"] = reward.descriptionText
                    rewardDicts.append(rewardDict)
                }
            }
            rideSummaryView.setTripSummary(tripLength: self.selectedTrip.length, description: self.selectedTrip.displayStringWithTime())
            rideSummaryView.setRewards(rewardDicts, animated: false)
        }
        
        if (self.selectedTrip != nil) {
            let trip = self.selectedTrip
            
            if self.selectedTrip.isClosed {
                if self.selectedTrip.activityType == .cycling {
                    durationLabel.text = self.selectedTrip.duration().intervalString
                    avgSpeedLabel.text = self.selectedTrip.aproximateAverageBikingSpeed.string
                    weatherLabel.text = self.selectedTrip.weatherString()
                    calorieLabel.text = self.selectedTrip.calorieString()
                    
                    statsView.isHidden = false
                    statsView2.isHidden = false
                    ratingChoiceSelector.isHidden = false

                    ratingChoiceHeightConstraint?.constant = initialRatingChoiceHeight
                } else {
                    statsView.isHidden = true
                    statsView2.isHidden = true
                    ratingChoiceSelector.isHidden = true

                    ratingChoiceHeightConstraint?.constant = 0
                }
                
                ratingChoiceSelector.setNeedsUpdateConstraints()
                UIView.animate(withDuration: 0.25, animations: {
                    self.ratingChoiceSelector.layoutIfNeeded()
                })
                
                self.changeModeButton.setTitle("Not a " + (trip?.activityType.noun)! + "?", for: UIControlState())
            }
        }
    }
    
    func createBackgroundViewIfNeeded(){
        guard self.bluredView == nil else {
            return
        }
        
        blurEffect = UIBlurEffect.init(style: .light)
        visualEffect = UIVisualEffectView.init(effect: blurEffect)
        bluredView = UIVisualEffectView.init(effect: blurEffect)
        bluredView.contentView.addSubview(visualEffect)
        
        visualEffect.frame = UIScreen.main.bounds
        bluredView.frame = UIScreen.main.bounds
        
        view.insertSubview(bluredView, at: 0)
    }
    
    //
    // MARK: - UIVIewController
    //
    
    override func viewDidLayoutSubviews() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "TripSummaryViewDidChangeHeight"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        createBackgroundViewIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: CoreDataManager.shared.managedObjectContext, queue: nil) {[weak self] (notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.selectedTrip != nil else {
                return
            }
            
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? NSSet {
                if updatedObjects.contains(strongSelf.selectedTrip) {
                    let trip = strongSelf.selectedTrip
                    strongSelf.selectedTrip = trip
                }
            }
            
            if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? NSSet {
                if deletedObjects.contains(strongSelf.selectedTrip) {
                    strongSelf.selectedTrip = nil
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    
    //
    // MARK: - UI Actions
    //
    
    @IBAction func changedRating(_: AnyObject) {
        self.selectedTrip.rating = ratingChoiceSelector.selectedRating
        APIClient.shared.saveAndSyncTripIfNeeded(self.selectedTrip)
        self.reloadUI()
    }
    
    @IBAction func changeMode(_: AnyObject) {
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionReveal
        transition.subtype = kCATransitionFromRight
        
        self.buttonsView.layer.add(transition, forKey: "transition")
        
        ratingChoiceHeightConstraint?.constant = initialRatingChoiceHeight
        ratingChoiceSelector.setNeedsUpdateConstraints()
        UIView.animate(withDuration: 0.25, animations: {
            self.ratingChoiceSelector.layoutIfNeeded()
        })
        self.modeSelectorView.selectedSegmentIndex = UISegmentedControlNoSegment
        self.modeSelectorView.isHidden = false
        self.ratingChoiceSelector.isHidden = true
        self.changeModeButton.isHidden = true
        self.changeModeLabel.isHidden = false
        CATransaction.commit()
    
        NotificationCenter.default.post(name: Notification.Name(rawValue: "TripSummaryViewDidChangeHeight"), object: nil)
    }

    @IBAction func selectedNewMode(_: AnyObject) {
        let mode = self.modeSelectorView.selectedMode
        
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.modeSelectorView.layer.add(transition, forKey: "transition")
        self.ratingChoiceSelector.layer.add(transition, forKey: "transition")
        self.modeSelectorView.isHidden = true
        self.ratingChoiceSelector.isHidden = false
        self.changeModeButton.isHidden = false
        self.changeModeLabel.isHidden = true

        CATransaction.commit()
        
        if mode != self.selectedTrip.activityType {
            self.selectedTrip.activityType = self.modeSelectorView.selectedMode
            APIClient.shared.saveAndSyncTripIfNeeded(self.selectedTrip)
            
            self.reloadUI()
            
            let alert = UIAlertView(title: "Ride Report was confused 😬", message: "Would you like to report this misclassification so that Ride Report can get better in the future?", delegate: self, cancelButtonTitle: "Nah", otherButtonTitles: "Sure")
            alert.show()
        } else {
            self.reloadUI()
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: "TripSummaryViewDidChangeHeight"), object: nil)
    }
    
    func alertView(_ alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            let storyBoard = UIStoryboard(name: "Main", bundle: nil)
            let reportModeClassificationNavigationViewController = storyBoard.instantiateViewController(withIdentifier: "ReportModeClassificationNavigationViewController") as! UINavigationController
            if let reportModeClassificationViewController = reportModeClassificationNavigationViewController.topViewController as? ReportModeClassificationViewController {
                reportModeClassificationViewController.trip = self.selectedTrip
            }
            self.present(reportModeClassificationNavigationViewController, animated: true, completion: nil)
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
    
    //
    // MARK: - Push Simulator View Actions
    //
    
    @IBAction func tappedNotGreat(_: AnyObject) {
        self.selectedTrip.rating = Rating.ratingWithCurrentVersion(RatingChoice.bad)
        APIClient.shared.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
    
    @IBAction func tappedGreat(_: AnyObject) {
        self.selectedTrip.rating = Rating.ratingWithCurrentVersion(RatingChoice.good)
        APIClient.shared.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
    
    @IBAction func tappedMixed(_: AnyObject) {
        self.selectedTrip.rating = Rating.ratingWithCurrentVersion(RatingChoice.mixed)
        APIClient.shared.saveAndSyncTripIfNeeded(self.selectedTrip)
        
        self.reloadUI()
    }
}
