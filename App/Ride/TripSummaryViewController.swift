//
//  TripSummaryViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/03/16.
//  Copyright (c) 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import RouteRecorder
import CocoaLumberjack
import Alamofire
import CoreLocation

class TripSummaryViewController: UIViewController, RideSummaryViewDelegate {
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
            
            if let trip = self.selectedTrip, trip.activityType.isMicroMobilityVehicleMode {
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
            
            if let trip = self.selectedTrip, trip.isInProgress {
                return rideSummaryView.frame.maxY
            }
            return buttonsView.frame.maxY
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
    }
    
    func reloadUI() {
        if (!modeSelectorView.isHidden) {
            // dont reload the UI if the user is currently picking a mode
            return
        }
        
        if self.selectedTrip.isInProgress {
            if (rideSummaryView.tripLength != self.selectedTrip.length) {
                rideSummaryView.setTripSummary(tripLength: self.selectedTrip.length, description: String(format: "Trip started at %@.", self.selectedTrip.timeString()))
                rideSummaryView.setRewards([])
            }
        } else {
            var rewardDicts: [[String: Any]] = []
            for element in self.selectedTrip.tripRewards {
                if let reward = element as? TripReward {
                    var rewardDict: [String: Any] = [:]
                    rewardDict["object"] = reward
                    rewardDict["reward_uuid"] = reward.rewardUUID
                    rewardDict["icon_url_string"] = reward.iconURLString
                    rewardDict["emoji"] = reward.displaySafeEmoji
                    rewardDict["description"] = reward.descriptionText
                    rewardDicts.append(rewardDict)
                }
            }
            rideSummaryView.setTripSummary(tripLength: self.selectedTrip.length, description: self.selectedTrip.displayStringWithTime())
            rideSummaryView.setRewards(rewardDicts, animated: false)
        }
        
        if (self.selectedTrip != nil) {
            let trip = self.selectedTrip
            
            self.changeModeButton.isHidden = false
            
            if self.selectedTrip.activityType.isMicroMobilityVehicleMode {
                durationLabel.text = self.selectedTrip.duration().intervalString
                weatherLabel.text = self.selectedTrip.weatherString()
                
                if let movingSpeed = self.selectedTrip.movingSpeed {
                    avgSpeedLabel.text = CLLocationSpeed(movingSpeed.doubleValue).string
                } else {
                    avgSpeedLabel.text = "--"
                }
                
                if let calories = self.selectedTrip.calories {
                    calorieLabel.text = String(format: "%0.fcal", calories)
                } else {
                    calorieLabel.text = "--"
                }
                
                statsView.isHidden = false
                statsView2.isHidden = false
            } else {
                statsView.isHidden = true
                statsView2.isHidden = true
            }
            
            
            let noun = (trip?.activityType.noun)! + "?"
            let vowels: [Character] = ["a", "e", "i", "o", "u"]
            let prefixString = vowels.contains(noun.lowercased().first ?? Character("")) ? "Not an " : "Not a "
            
            self.changeModeButton.setTitle(prefixString + noun, for: UIControl.State())
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
        
        if let tabBarController = self.parent?.tabBarController as? RideReportTabBarController {
            if !tabBarController.popupView.isHidden {
                tabBarController.popupView.fadeOut()
            }
        }
        
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
    
    @IBAction func changeMode(_: AnyObject) {
        CATransaction.begin()
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.reveal
        transition.subtype = CATransitionSubtype.fromRight
        
        self.buttonsView.layer.add(transition, forKey: "transition")
        
        self.modeSelectorView.selectedSegmentIndex = UISegmentedControl.noSegment
        self.modeSelectorView.isHidden = false
        self.changeModeButton.isHidden = true
        self.changeModeLabel.isHidden = false
        CATransaction.commit()
    
        NotificationCenter.default.post(name: Notification.Name(rawValue: "TripSummaryViewDidChangeHeight"), object: nil)
    }

    @IBAction func selectedNewMode(_: AnyObject) {
        let mode = self.modeSelectorView.selectedMode
        if mode == .unknown {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
            for type in ActivityType.userSelectableValues {
                if !self.modeSelectorView.shownModes.contains(type) {
                    alertController.addAction(UIAlertAction(title: type.emoji + " " + type.noun, style: UIAlertAction.Style.default) { (_) in
                        self.modeSelectorView.selectedMode = type
                        self.didSelectMode()
                    })
                }
            }
            alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) { (_) in
                self.modeSelectorView.selectedMode = self.selectedTrip.activityType
                self.didSelectMode()
            })
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        didSelectMode()
    }
    
    private func didSelectMode() {
        if !self.modeSelectorView.isHidden {
            let timingDuration = 0.5
            CATransaction.begin()
            let transition = CATransition()
            transition.duration = timingDuration
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromLeft
            self.modeSelectorView.layer.add(transition, forKey: "transition")
            self.modeSelectorView.isHidden = true
            self.changeModeButton.isHidden = false
            self.changeModeLabel.isHidden = true
            
            CATransaction.commit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + timingDuration) {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "TripSummaryViewDidChangeHeight"), object: nil)
            }
            
        }
        
        let mode = self.modeSelectorView.selectedMode
        if let selectedTrip = self.selectedTrip {
            if mode != selectedTrip.activityType {
                selectedTrip.activityType = self.modeSelectorView.selectedMode
                
                self.reloadUI()
                
                let alertController = UIAlertController(title: "Ride was confused 😬", message: "Would you like to report this misclassification so that Ride can get better in the future?", preferredStyle: UIAlertController.Style.actionSheet)
                alertController.addAction(UIAlertAction(title: "Sure", style: UIAlertAction.Style.default) { (_) in
                    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                    let reportModeClassificationNavigationViewController = storyBoard.instantiateViewController(withIdentifier: "ReportModeClassificationNavigationViewController") as! UINavigationController
                    if let reportModeClassificationViewController = reportModeClassificationNavigationViewController.topViewController as? ReportModeClassificationViewController {
                        reportModeClassificationViewController.trip = selectedTrip
                    }
                    self.present(reportModeClassificationNavigationViewController, animated: true, completion: nil)
                })
                alertController.addAction(UIAlertAction(title: "Nah", style: UIAlertAction.Style.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            } else {
                self.reloadUI()
                self.view.layoutIfNeeded()
            }
            NotificationCenter.default.post(name: Notification.Name(rawValue: "TripSummaryViewDidChangeHeight"), object: nil)
        }
    }
    
    func didTapReward(withAssociatedObject object: Any) {
        self.presentFailureAlert()
    }
    
    func presentFailureAlert(message: String = "Your reward could not be loaded. Please check that you are connected to the internet and try again.") {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "Darn", style: UIAlertAction.Style.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

}
