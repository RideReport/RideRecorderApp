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
    var workoutStartDate : Date?
    var workoutEndDate : Date?
    var totalEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 0)
    var totalDistance = HKQuantity(unit: HKUnit.meter(), doubleValue: 0)
    var workoutEvents = [HKWorkoutEvent]()
    var metadata = [String: AnyObject]()
    var timer : Timer?
    var isPaused = false
    
    @IBOutlet var durationLabel: WKInterfaceLabel!
    @IBOutlet var caloriesLabel: WKInterfaceLabel!
    @IBOutlet var distanceLabel: WKInterfaceLabel!
    @IBOutlet var markerLabel: WKInterfaceLabel!
    
    // MARK: Interface Controller Overrides
    
    override func awake(withContext context: AnyObject?) {
        super.awake(withContext: context)
        
        // Start a workout session with the configuration
        if let workoutConfiguration = context as? HKWorkoutConfiguration {
            do {
                workoutSession = try HKWorkoutSession(configuration: workoutConfiguration)
                workoutSession?.delegate = self
                
                workoutStartDate = Date()
                
                healthStore.start(workoutSession!)
                iPhoneManager.startup()
                iPhoneManager.sharedManager.addDelegate(delegate: self)
                iPhoneManager.sharedManager.tripState = .InProgress
            } catch {
                // ...
            }
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    
    // MARK: Totals
    
    private func totalCalories() -> Double {
        return totalEnergyBurned.doubleValue(for: HKUnit.kilocalorie())
    }
    
    private func totalMeters() -> Double {
        return totalDistance.doubleValue(for: HKUnit.meter())
    }
    
    private func setTotalCalories(calories: Double) {
        totalEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
    }
    
    private func setTotalMeters(meters: Double) {
        totalDistance = HKQuantity(unit: HKUnit.meter(), doubleValue: meters)
    }
    
    // MARK: IB Actions
    
    @IBAction func didTapMarkerButton() {
        let markerEvent = HKWorkoutEvent(type: .marker, date: Date())
        workoutEvents.append(markerEvent)
        notifyEvent(markerEvent)
    }
    
    // MARK: Convenience
    
    private func computeDurationOfWorkout(withEvents workoutEvents: [HKWorkoutEvent]?, startDate: Date?, endDate: Date?) -> TimeInterval {
        var duration = 0.0
        
        if var lastDate = startDate {
            var paused = false
            
            if let events = workoutEvents {
                for event in events {
                    switch event.type {
                    case .pause:
                        duration += event.date.timeIntervalSince(lastDate)
                        paused = true
                        
                    case .resume:
                        lastDate = event.date
                        paused = false
                        
                    default:
                        continue
                    }
                }
            }
            
            if !paused {
                if let end = endDate {
                    duration += end.timeIntervalSince(lastDate)
                } else {
                    duration += NSDate().timeIntervalSince(lastDate)
                }
            }
        }
        
        print("\(duration)")
        return duration
    }
    
    private func timeFormat(duration: TimeInterval) -> String {
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.unitsStyle = .positional
        durationFormatter.allowedUnits = [.second, .minute, .hour]
        durationFormatter.zeroFormattingBehavior = .pad
        
        if let string = durationFormatter.string(from: duration) {
            return string
        } else {
            return ""
        }
    }
    
    func updateLabels() {
        caloriesLabel.setText(String(format: "%.1f Calories", totalEnergyBurned.doubleValue(for: HKUnit.kilocalorie())))
        distanceLabel.setText( String(format: "%.1f Meters", totalDistance.doubleValue(for: HKUnit.meter())))
        
        let duration = computeDurationOfWorkout(withEvents: workoutEvents, startDate: workoutStartDate, endDate: workoutEndDate)
        durationLabel.setText(timeFormat(duration: duration))
    }
    
    func updateState() {
        if let session = workoutSession {
            switch session.state {
            case .running:
                setTitle("Active Workout")
            case .paused:
                setTitle("Paused Workout")
            case .notStarted, .ended:
                setTitle("Workout")
            }
        }
    }
    
    func notifyEvent(_: HKWorkoutEvent) {
        weak var weakSelf = self
        
        DispatchQueue.main.async {
            weakSelf?.markerLabel.setAlpha(1)
            WKInterfaceDevice.current().play(.notification)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1) {
                weakSelf?.markerLabel.setAlpha(0)
            }
        }
    }
    
    // MARK: Data Queries
    
    func startAccumulatingData(startDate: Date) {
        startQuery(quantityTypeIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)
        startQuery(quantityTypeIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)
        
        startTimer()
    }
    
    func startQuery(quantityTypeIdentifier: HKQuantityTypeIdentifier) {
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictStartDate)
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, devicePredicate])
        
        let updateHandler: ((HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void) = { query, samples, deletedObjects, queryAnchor, error in
            self.process(samples: samples, quantityTypeIdentifier: quantityTypeIdentifier)
        }
        
        let query = HKAnchoredObjectQuery(type: HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)!,
                                          predicate: queryPredicate,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit,
                                          resultsHandler: updateHandler)
        query.updateHandler = updateHandler
        healthStore.execute(query)
        
        activeDataQueries.append(query)
    }
    
    func process(samples: [HKSample]?, quantityTypeIdentifier: HKQuantityTypeIdentifier) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, !strongSelf.isPaused else { return }
            
            if let quantitySamples = samples as? [HKQuantitySample] {
                for sample in quantitySamples {
                    if quantityTypeIdentifier == HKQuantityTypeIdentifier.distanceWalkingRunning {
                        let newMeters = sample.quantity.doubleValue(for: HKUnit.meter())
                        strongSelf.setTotalMeters(meters: strongSelf.totalMeters() + newMeters)
                    } else if quantityTypeIdentifier == HKQuantityTypeIdentifier.activeEnergyBurned {
                        let newKCal = sample.quantity.doubleValue(for: HKUnit.kilocalorie())
                        strongSelf.setTotalCalories(calories: strongSelf.totalCalories() + newKCal)
                    }
                }
                
                strongSelf.updateLabels()
            }
        }
    }
    
    func stopAccumulatingData() {
        for query in activeDataQueries {
            healthStore.stop(query)
        }
        
        activeDataQueries.removeAll()
        stopTimer()
    }
    
    func pauseAccumulatingData() {
        DispatchQueue.main.sync {
            isPaused = true
        }
    }
    
    func resumeAccumulatingData() {
        DispatchQueue.main.sync {
            isPaused = false
        }
    }
    
    // MARK: Timer code
    
    func startTimer() {
        print("start timer")
        timer = Timer.scheduledTimer(timeInterval: 1,
                                     target: self,
                                     selector: #selector(timerDidFire),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    func timerDidFire(timer: Timer) {
        print("timer")
        updateLabels()
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
    
    // MARK: iPhoneStateChangedDelegate
    
    func stateDidChange() {
        if iPhoneManager.sharedManager.tripState == .Stopped {
            healthStore.end(workoutSession!)
        } else {
            updateLabels()
        }
    }

    
    // MARK: HKWorkoutSessionDelegate
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("workout session did fail with error: \(error)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didGenerate event: HKWorkoutEvent) {
        workoutEvents.append(event)
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            if fromState == .notStarted {
                startAccumulatingData(startDate: workoutStartDate!)
            } else {
                resumeAccumulatingData()
            }
            
        case .paused:
            pauseAccumulatingData()
            
        case .ended:
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
        let isIndoor = (configuration.locationType == .indoor) as NSNumber
        print("locationType: \(configuration)")
        
        let workout = HKWorkout(activityType: configuration.activityType,
                                start: workoutStartDate!,
                                end: workoutEndDate!,
                                workoutEvents: workoutEvents,
                                totalEnergyBurned: totalEnergyBurned,
                                totalDistance: totalDistance,
                                metadata: [HKMetadataKeyIndoorWorkout:isIndoor]);
        
        healthStore.save(workout) { success, _ in
            if success {
                self.addSamples(toWorkout: workout)
            }
        }
        
        // Pass the workout to Summary Interface Controller
        WKInterfaceController.reloadRootControllers(withNames: ["SummaryInterfaceController"], contexts: [workout])
    }
    
    private func addSamples(toWorkout workout: HKWorkout) {
        // Create energy and distance samples
        let totalEnergyBurnedSample = HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
                                                       quantity: totalEnergyBurned,
                                                       start: workoutStartDate!,
                                                       end: workoutEndDate!)
        
        let totalDistanceSample = HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling)!,
                                                   quantity: totalDistance,
                                                   start: workoutStartDate!,
                                                   end: workoutEndDate!)
        
        // Add samples to workout
        healthStore.add([totalEnergyBurnedSample, totalDistanceSample], to: workout) { (success: Bool, error: Error?) in
            if success {
                // Samples have been added
            }
        }
    }

}
