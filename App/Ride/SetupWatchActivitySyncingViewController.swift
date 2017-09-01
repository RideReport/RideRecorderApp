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
import RouteRecorder

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
        
        self.cancelButton.isHidden = true
        
        self.disclaimerLabel.isHidden = true
        
        ringsView = HKActivityRingView()
        ringsView.translatesAutoresizingMaskIntoConstraints = false
        self.ringsContainerView.addSubview(ringsView)
        self.ringsContainerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[subview]-0-|", options: NSLayoutFormatOptions(), metrics: nil, views: ["subview": ringsView]))
        self.ringsContainerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[subview]-0-|", options: NSLayoutFormatOptions(), metrics: nil, views: ["subview": ringsView]))

        
        self.progressView.isHidden = true
        self.doneButton.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.isNavigationBarHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let summary = HKActivitySummary()
        summary.activeEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 60)
        summary.activeEnergyBurnedGoal = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 100)
        summary.appleExerciseTime = HKQuantity(unit: HKUnit.minute(), doubleValue: 80)
        summary.appleExerciseTimeGoal = HKQuantity(unit: HKUnit.minute(), doubleValue: 100)
        summary.appleStandHours = HKQuantity(unit: HKUnit.count(), doubleValue: 4)
        summary.appleStandHoursGoal = HKQuantity(unit: HKUnit.count(), doubleValue: 8)
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
            UserDefaults.standard.set(true, forKey: "healthKitIsSetup")
            UserDefaults.standard.synchronize()
            
            HealthKitManager.startup() { success in
                let context = CoreDataManager.shared.currentManagedObjectContext()
                let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
                fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i AND healthKitUuid == nil", ActivityType.cycling.rawValue)
                fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                
                let results: [AnyObject]?
                do {
                    results = try context.fetch(fetchedRequest)
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
                    self.progressView.isHidden = false
                    self.detailLabel.isHidden = false
                    self.disclaimerLabel.isHidden = true
                    self.titleLabel.text = "Saving Existing Rides"
                    self.detailLabel.text = "We're saving all your rides to your Apple Watch. Future rides will be saved automatically."
                    
                    self.cancelButton.isHidden = false

                    
                    self.syncNextUnsyncedTrip()
                } else {
                    self.next(sender)
                }
            }
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        let alertController = UIAlertController(title:nil, message: "Future rides will not be automatically saved to to your Apple Watch.", preferredStyle: UIAlertControllerStyle.actionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel Saving", style: UIAlertActionStyle.destructive, handler: { (_) in
            self.didCancel = true
            HealthKitManager.shutdown()
            UserDefaults.standard.set(false, forKey: "healthKitIsSetup")
            UserDefaults.standard.synchronize()
            
            self.next(sender)
        }))
        alertController.addAction(UIAlertAction(title: "Keep Saving", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func syncNextUnsyncedTrip() {
        guard !self.didCancel else {
            return
        }
        
        guard let nextTrip = self.tripsRemainingToSync?.first else {
            self.progressView.progress = 1.0
            self.progressView.isHidden = true
            self.cancelButton.isHidden = true
            self.doneButton.isHidden = false
            self.detailLabel.isHidden = false
            self.disclaimerLabel.isHidden = true
            
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.hidesBackButton = true
            
            self.titleLabel.text = "All Set!"
            self.detailLabel.text = "Your rides will be automatically saved to your Apple Watch."
            
            return
        }
        HealthKitManager.shared.saveOrUpdateTrip(nextTrip) { _ in
            DispatchQueue.main.async {
                self.tripsRemainingToSync!.removeFirst()
                let progress = Float(self.totalTripsToSync - self.tripsRemainingToSync!.count) / Float(self.totalTripsToSync)
                self.progressView.setProgress(progress, animated: true)
                
                self.syncNextUnsyncedTrip()
            }
        }
    }
}
