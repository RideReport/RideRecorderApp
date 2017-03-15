//
//  InterfaceController.swift
//  Ride Report Watch App Extension
//
//  Created by William Henderson on 8/1/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit

class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate, iPhoneStateChangedDelegate {
    let healthStore = HKHealthStore()
    var workoutSession : HKWorkoutSession?
    var activeDataQueries = [HKQuery]()
    var workoutStartDate : NSDate?
    var workoutEndDate : NSDate?
    var totalEnergyBurned = HKQuantity(unit: HKUnit.kilocalorieUnit(), doubleValue: 0)
    var totalDistance = HKQuantity(unit: HKUnit.meterUnit(), doubleValue: 0)
    var workoutEvents = [HKWorkoutEvent]()
    var metadata = [String: AnyObject]()
    var timer : NSTimer?
    var isPaused = false
    
    @IBOutlet var durationLabel: WKInterfaceLabel!
    @IBOutlet var caloriesLabel: WKInterfaceLabel!
    @IBOutlet var distanceLabel: WKInterfaceLabel!
    @IBOutlet var markerLabel: WKInterfaceLabel!
    
    // MARK: Interface Controller Overrides
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        iPhoneManager.startup()
        iPhoneManager.sharedManager.addDelegate(self)
        
        // Start a workout session with the configuration
        if let workoutConfiguration = context as? HKWorkoutConfiguration {
            do {
                workoutSession = try HKWorkoutSession(configuration: workoutConfiguration)
                workoutSession?.delegate = self
                
                workoutStartDate = NSDate()
                
                healthStore.startWorkoutSession(workoutSession!)
                iPhoneManager.sharedManager.tripState = .InProgress
            } catch {
                // ...
            }
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        iPhoneManager.sharedManager.activate()
        
        updateLabels()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    
    // MARK: Totals
    
    private func totalCalories() -> Double {
        return totalEnergyBurned.doubleValueForUnit(HKUnit.kilocalorieUnit())
    }
    
    private func totalMeters() -> Double {
        return totalDistance.doubleValueForUnit(HKUnit.meterUnit())
    }
    
    private func setTotalCalories(calories: Double) {
        totalEnergyBurned = HKQuantity(unit: HKUnit.kilocalorieUnit(), doubleValue: calories)
    }
    
    private func setTotalMeters(meters: Double) {
        totalDistance = HKQuantity(unit: HKUnit.meterUnit(), doubleValue: meters)
    }
    
    // MARK: Convenience
    
    private func computeDurationOfWorkout(withEvents workoutEvents: [HKWorkoutEvent]?, startDate: NSDate?, endDate: NSDate?) -> NSTimeInterval {
        var duration = 0.0
        
        if var lastDate = startDate {
            var paused = false
            
            if let events = workoutEvents {
                for event in events {
                    switch event.type {
                    case .Pause:
                        duration += event.date.timeIntervalSinceDate(lastDate)
                        paused = true
                        
                    case .Resume:
                        lastDate = event.date
                        paused = false
                        
                    default:
                        continue
                    }
                }
            }
            
            if !paused {
                if let end = endDate {
                    duration += end.timeIntervalSinceDate(lastDate)
                } else {
                    duration += NSDate().timeIntervalSinceDate(lastDate)
                }
            }
        }
        
        print("\(duration)")
        return duration
    }
    
    private func timeFormat(duration: NSTimeInterval) -> String {
        let durationFormatter = NSDateComponentsFormatter()
        durationFormatter.unitsStyle = .Positional
        durationFormatter.allowedUnits = [.Second, .Minute, .Hour]
        durationFormatter.zeroFormattingBehavior = .Pad
        
        if let string = durationFormatter.stringFromTimeInterval(duration) {
            return string
        } else {
            return ""
        }
    }
    
    func updateLabels() {
       if iPhoneManager.sharedManager.tripState == .InProgress {
            markerLabel.setText("Ride In Progress")
            caloriesLabel.setText(String(format: "%.1f Calories", totalEnergyBurned.doubleValueForUnit(HKUnit.kilocalorieUnit())))
            distanceLabel.setText(iPhoneManager.sharedManager.tripDistance.distanceString)
            
            let duration = computeDurationOfWorkout(withEvents: workoutEvents, startDate: workoutStartDate, endDate: workoutEndDate)
            durationLabel.setText(timeFormat(duration))
        } else {
            caloriesLabel.setText("--")
            distanceLabel.setText("--")
            durationLabel.setText("--")

            if iPhoneManager.sharedManager.tripState == .Stopped {
                markerLabel.setText("Ride Stopped")
            } else {
                markerLabel.setText("--")
            }
        }
        
    }
    
    func updateState() {
        if let session = workoutSession {
            switch session.state {
            case .Running:
                setTitle("Active Workout")
            case .Paused:
                setTitle("Paused Workout")
            case .NotStarted, .Ended:
                setTitle("Workout")
            }
        }
    }
    
    func notifyEvent(_: HKWorkoutEvent) {
        weak var weakSelf = self
        
        dispatch_async(dispatch_get_main_queue()) {
            weakSelf?.markerLabel.setAlpha(1)
            WKInterfaceDevice.currentDevice().playHaptic(.Notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { () -> Void in
                weakSelf?.markerLabel.setAlpha(0)
            }
        }
    }
    
    // MARK: Data Queries
    
    func startAccumulatingData(startDate: NSDate) {
        startQuery(HKQuantityTypeIdentifierActiveEnergyBurned)
        
        startTimer()
    }
    
    func startQuery(quantityTypeIdentifier: String) {
        let datePredicate = HKQuery.predicateForSamplesWithStartDate(workoutStartDate, endDate: nil, options: .StrictStartDate)
        let devicePredicate = HKQuery.predicateForObjectsFromDevices([HKDevice.localDevice()])
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, devicePredicate])
        
        let updateHandler: ((HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, NSError?) -> Void) = { query, samples, deletedObjects, queryAnchor, error in
            self.process(samples, quantityTypeIdentifier: quantityTypeIdentifier)
        }
        
        let query = HKAnchoredObjectQuery(type: HKObjectType.quantityTypeForIdentifier(quantityTypeIdentifier)!,
                                          predicate: queryPredicate,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit,
                                          resultsHandler: updateHandler)
        query.updateHandler = updateHandler
        healthStore.executeQuery(query)
        
        activeDataQueries.append(query)
    }
    
    func process(samples: [HKSample]?, quantityTypeIdentifier: String) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard let strongSelf = self where !strongSelf.isPaused else { return }
            if let quantitySamples = samples as? [HKQuantitySample] {
                for sample in quantitySamples {
                    if quantityTypeIdentifier == HKQuantityTypeIdentifierActiveEnergyBurned {
                        let newKCal = sample.quantity.doubleValueForUnit(HKUnit.kilocalorieUnit())
                        strongSelf.setTotalCalories(strongSelf.totalCalories() + newKCal)
                    }
                }
                
                strongSelf.updateLabels()
            }
        }
    }
    
    func stopAccumulatingData() {
        for query in activeDataQueries {
            healthStore.stopQuery(query)
        }
        
        activeDataQueries.removeAll()
        stopTimer()
    }
    
    func pauseAccumulatingData() {
        dispatch_sync(dispatch_get_main_queue()) { 
            isPaused = true
        }
    }
    
    func resumeAccumulatingData() {
        dispatch_sync(dispatch_get_main_queue()) {
            isPaused = false
        }
    }
    
    // MARK: Timer code
    
    func startTimer() {
        print("start timer")
        timer = NSTimer.scheduledTimerWithTimeInterval(1,
                                     target: self,
                                     selector: #selector(timerDidFire),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    func timerDidFire(timer: NSTimer) {
        print("timer")
        updateLabels()
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
    
    // MARK: iPhoneStateChangedDelegate
    
    func stateDidChange() {
        if iPhoneManager.sharedManager.tripState == .Stopped {
            healthStore.endWorkoutSession(workoutSession!)
        } else {
            
        }
        
        updateLabels()
    }

    
    // MARK: HKWorkoutSessionDelegate
    
    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        print("workout session did fail with error: \(error)")
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didGenerate event: HKWorkoutEvent) {
        workoutEvents.append(event)
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        switch toState {
        case .Running:
            if fromState == .NotStarted {
                startAccumulatingData(workoutStartDate!)
            } else {
                resumeAccumulatingData()
            }
            
        case .Paused:
            pauseAccumulatingData()
            
        case .Ended:
            iPhoneManager.sharedManager.tripState = .Stopped
            workoutEndDate = NSDate()
            stopAccumulatingData()
            saveWorkout()
            
        default:
            break
        }
        
        updateLabels()
        updateState()
    }
    
    private func saveWorkout() {
        // Create and save a workout sample
        let configuration = workoutSession!.workoutConfiguration
        let isIndoor = (configuration.locationType == .Indoor) as NSNumber
        print("locationType: \(configuration)")
        
        let workout = HKWorkout(activityType: configuration.activityType,
                                startDate: workoutStartDate!,
                                endDate: workoutEndDate!,
                                workoutEvents: workoutEvents,
                                totalEnergyBurned: totalEnergyBurned,
                                totalDistance: totalDistance,
                                metadata: [HKMetadataKeyIndoorWorkout:isIndoor]);
        
        healthStore.saveObject(workout) { success, _ in
            if success {
                self.addSamples(toWorkout: workout)
            }
        }
        
        // Pass the workout to Summary Interface Controller
        WKInterfaceController.reloadRootControllersWithNames(["SummaryInterfaceController"], contexts: [workout])
    }
    
    private func addSamples(toWorkout workout: HKWorkout) {
        // Create energy and distance samples
        let totalEnergyBurnedSample = HKQuantitySample(type: HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!,
                                                       quantity: totalEnergyBurned,
                                                       startDate: workoutStartDate!,
                                                       endDate: workoutEndDate!)
        
        let totalDistanceSample = HKQuantitySample(type: HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling)!,
                                                   quantity: totalDistance,
                                                   startDate: workoutStartDate!,
                                                   endDate: workoutEndDate!)
        
        // Add samples to workout
        healthStore.addSamples([totalEnergyBurnedSample, totalDistanceSample], toWorkout: workout) { (success: Bool, error: NSError?) in
            if success {
                // Samples have been added
            }
        }
    }

}
