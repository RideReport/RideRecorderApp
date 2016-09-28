//
//  HealthKitSetupViewController.swift
//  Ride
//
//  Created by William Henderson on 4/12/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import HealthKitUI

@available(iOS 9.3, *)
class SetupWatchActivitySyncingViewController : SetupChildViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var disclaimerLabel: UILabel!
    
    @IBOutlet weak var ringsContainerView: UIView!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    
    var ringsView: HKActivityRingView!
    
    var tripsRemainingToSync: [Trip]?
    var totalTripsToSync = 0
    private var didCancel = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.cancelButton.hidden = true
        
        self.disclaimerLabel.hidden = true
        
        ringsView = HKActivityRingView()
        ringsView.translatesAutoresizingMaskIntoConstraints = false
        self.ringsContainerView.addSubview(ringsView)
        self.ringsContainerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[subview]-0-|", options: .DirectionLeadingToTrailing, metrics: nil, views: ["subview": ringsView]))
        self.ringsContainerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[subview]-0-|", options: .DirectionLeadingToTrailing, metrics: nil, views: ["subview": ringsView]))

        
        self.progressView.hidden = true
        self.doneButton.hidden = true
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBarHidden = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        let summary = HKActivitySummary()
        summary.activeEnergyBurned = HKQuantity(unit: HKUnit.kilocalorieUnit(), doubleValue: 60)
        summary.activeEnergyBurnedGoal = HKQuantity(unit: HKUnit.kilocalorieUnit(), doubleValue: 100)
        summary.appleExerciseTime = HKQuantity(unit: HKUnit.minuteUnit(), doubleValue: 80)
        summary.appleExerciseTimeGoal = HKQuantity(unit: HKUnit.minuteUnit(), doubleValue: 100)
        summary.appleStandHours = HKQuantity(unit: HKUnit.countUnit(), doubleValue: 4)
        summary.appleStandHoursGoal = HKQuantity(unit: HKUnit.countUnit(), doubleValue: 8)
        self.ringsView.setActivitySummary(summary, animated: true)
    }
    
    @IBAction override func next(_ sender: AnyObject) {
        super.next(sender)
    }
    
    @IBAction func sync(_ sender: AnyObject) {
        self.detailLabel.fadeOut()
        self.connectButton.fadeOut()
        self.skipButton.fadeOut()
        self.disclaimerLabel.fadeIn()
        
        self.disclaimerLabel.delay(2) {
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "healthKitIsSetup")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            HealthKitManager.startup() { success in
                let context = CoreDataManager.sharedManager.currentManagedObjectContext()
                let fetchedRequest = NSFetchRequest(entityName: "Trip")
                fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND healthKitUuid == nil", ActivityType.Cycling.rawValue)
                fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let results: [AnyObject]?
                do {
                    results = try context.executeFetchRequest(fetchedRequest)
                } catch let error {
                    DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
                    return
                }
                guard let theTrips = results as? [Trip] else {
                    return
                }
                
                self.tripsRemainingToSync = theTrips
                self.totalTripsToSync = theTrips.count
                if (theTrips.count > 0) {
                    self.progressView.progress = 0.0
                    self.progressView.hidden = false
                    self.detailLabel.hidden = false
                    self.disclaimerLabel.hidden = true
                    self.titleLabel.text = "Saving Existing Rides"
                    self.detailLabel.text = "We're saving all your rides to your Apple Watch. Future rides will be saved automatically."
                    
                    self.cancelButton.hidden = false

                    
                    self.syncNextUnsyncedTrip()
                } else {
                    self.next(sender)
                }
            }
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        let alertController = UIAlertController(title:nil, message: "Future rides will not be automatically saved to to your Apple Watch.", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel Saving", style: UIAlertActionStyle.Destructive, handler: { (_) in
            self.didCancel = true
            HealthKitManager.shutdown()
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "healthKitIsSetup")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            self.next(sender)
        }))
        alertController.addAction(UIAlertAction(title: "Keep Saving", style: UIAlertActionStyle.Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    private func syncNextUnsyncedTrip() {
        guard !self.didCancel else {
            return
        }
        
        guard let nextTrip = self.tripsRemainingToSync?.first else {
            self.progressView.progress = 1.0
            self.progressView.hidden = true
            self.cancelButton.hidden = true
            self.doneButton.hidden = false
            self.detailLabel.hidden = false
            self.disclaimerLabel.hidden = true
            
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.hidesBackButton = true
            
            self.titleLabel.text = "All Set!"
            self.detailLabel.text = "Your rides will be automatically saved to your Apple Watch."
            
            return
        }
        HealthKitManager.sharedManager.saveOrUpdateTrip(nextTrip) { _ in
            dispatch_async(dispatch_get_main_queue()) {
                self.tripsRemainingToSync!.removeFirst()
                let progress = Float(self.totalTripsToSync - self.tripsRemainingToSync!.count) / Float(self.totalTripsToSync)
                self.progressView.setProgress(progress, animated: true)
                
                self.syncNextUnsyncedTrip()
            }
        }
    }
}
