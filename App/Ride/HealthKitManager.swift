//
//  HealthKitManager.swift
//  Ride
//
//  Created by William Henderson on 10/2/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import HealthKit
import CoreData

enum HealthKitManagerAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}


class HealthKitManager {
    static private(set) var shared: HealthKitManager!
    static private var authorizationStatus : HealthKitManagerAuthorizationStatus = .notDetermined
    
    let healthStore = HKHealthStore()
    
    // default values based on averages
    var currentWeightKilograms  = 62.0
    var currentGender : HKBiologicalSex = HKBiologicalSex.notSet
    var currentAgeYears = 30.0
    
    private var tripsRemainingToSave: [Trip]?
    
    class func startup(_ authorizationHandler:@escaping (_ success: Bool)->() = {_ in}) {
        if (HealthKitManager.shared == nil) {
            HealthKitManager.shared = HealthKitManager()
            DispatchQueue.main.async {
                HealthKitManager.startup(authorizationHandler)
            }
        }
    }
    
    class var hasStarted: Bool {
        get {
            return (HealthKitManager.shared != nil)
        }
    }
    
    class func shutdown() {
        HealthKitManager.shared = nil
        HealthKitManager.authorizationStatus = .notDetermined
    }
    
    func startup(_ authorizationHandler:@escaping (_ success: Bool)->()={_ in }) {
        self.requestAuthorization(authorizationHandler)
    }
    
    private func requestAuthorization(_ authorizationHandler:@escaping (_ success: Bool)->()={_ in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        guard let sexCharacteristic = HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.biologicalSex),
            let dobCharacteristc = HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.dateOfBirth),
            let bodyMassCharacteristic = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass),
            let heartRateCharactertistic = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate),
            let energyBurnedType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned),
            let cyclingType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling) else {
                DDLogWarn("Couldn't find charactertisitcs and/or types!")
                return
        }
        
        let readTypes : Set<HKObjectType> = [sexCharacteristic, dobCharacteristc, bodyMassCharacteristic, heartRateCharactertistic]
        let writeTypes : Set<HKSampleType> = [HKQuantityType.workoutType(), energyBurnedType, cyclingType]
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { (success, err) -> Void in
            if let error = err {
                DDLogWarn("Error accesing health kit data!: \(error), \(error._userInfo)")
                HealthKitManager.authorizationStatus = .denied
                DispatchQueue.main.async {
                    authorizationHandler(false)
                }
            } else {
                HealthKitManager.authorizationStatus = .authorized
                self.getWeight()
                self.getGender()
                self.getAge()
                DispatchQueue.main.async {
                    NotificationCenter.default.addObserver(self, selector: #selector(HealthKitManager.saveUnsavedTrips), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
                    self.saveUnsavedTrips()
                    authorizationHandler(true)
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func saveUnsavedTrips() {
        if (UIApplication.shared.applicationState == UIApplicationState.active) {
            DispatchQueue.main.async {
                let context = CoreDataManager.shared.currentManagedObjectContext()
                let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
                fetchedRequest.predicate = NSPredicate(format: "isSavedToHealthKit == false")
                fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let results: [AnyObject]?
                do {
                    results = try context.fetch(fetchedRequest)
                } catch let error {
                    DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
                    return
                }
                guard let theTrips = results as? [Trip], theTrips.count > 0 else {
                    return
                }
                
                self.tripsRemainingToSave = theTrips
                self.saveNextUnsavedTrip()
            }
        }
    }
    
    private func saveNextUnsavedTrip() {
        guard let nextTrip = self.tripsRemainingToSave?.first else {
            self.tripsRemainingToSave = nil
            return
        }
        
        self.saveOrUpdateTrip(nextTrip) { _ in
            self.tripsRemainingToSave?.removeFirst()
            
            self.saveNextUnsavedTrip()
        }
    }
    
    func getHeartRateSamples(_ startDate:Date, endDate: Date, completionHandler:@escaping ([HKQuantitySample]?)->Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            DDLogWarn("Couldn't find heart rate type!")
            completionHandler(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions())
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 0, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate , ascending: false)]) { (query, results, error) -> Void in
            completionHandler(results as? [HKQuantitySample])
        }
        
        self.healthStore.execute(query)
    }
    
    func getAge() {
        do {
            let dob = try self.healthStore.dateOfBirth()

            DispatchQueue.main.async {
                Profile.profile().dateOfBirth = dob
                CoreDataManager.shared.saveContext()
            }
            self.currentAgeYears = Double((Calendar.current as NSCalendar).components(NSCalendar.Unit.year, from: dob, to: Date(), options: NSCalendar.Options.wrapComponents).year!)
        } catch _ {
        }
    }
    
    func getGender() {
        do {
            self.currentGender = try self.healthStore.biologicalSex().biologicalSex
            if self.currentGender != .notSet {
                DispatchQueue.main.async {
                    Profile.profile().gender = NSNumber(value: self.currentGender.rawValue as Int)
                    CoreDataManager.shared.saveContext()
                }
            }
        } catch _ {
            self.currentGender = HKBiologicalSex.notSet
        }
    }
    
    func getWeight() {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass) else {
            DDLogWarn("Couldn't find body mass type!")
            return
        }
        
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate , ascending: false)]) { (query, res, error) -> Void in
            if let results = res {
                if let result = results.first as? HKQuantitySample {
                    self.currentWeightKilograms = (result.quantity.doubleValue(for: HKUnit.gram())) / 1000.0
                    if self.currentWeightKilograms > 0 {
                        DispatchQueue.main.async {
                            Profile.profile().weightKilograms = NSNumber(value: self.currentWeightKilograms as Double)
                            CoreDataManager.shared.saveContext()
                        }
                    }
                } else {
                    // ask for the user's weight?
                }
            } else {
                if (error != nil) {
                    
                }
            }
        }
        
        self.healthStore.execute(query)
    }
    
    func deleteWorkoutAndSamplesForTrip(_ trip:Trip, handler: @escaping (_ success: Bool)->()) {
        guard let activeEnergyBurnedType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned),
                let cyclingDistanceType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling) else {
                DDLogWarn("Couldn't find types!")
                handler(false)
                return
        }
        
        guard let uuidString = trip.healthKitUuid, let uuid = UUID(uuidString: uuidString) else {
            handler(false)
            return
        }
        
        let deleteBlock = { (workout: HKWorkout) in
            let samplesPredicate = HKQuery.predicateForObjects(from: workout)
            if #available(iOS 9.0, *) {
                self.healthStore.deleteObjects(of: activeEnergyBurnedType, predicate: samplesPredicate) { (_, _, _) in
                    // for all deletions, we make a best attempt and proceed with the handler regardless of the result
                    self.healthStore.deleteObjects(of: cyclingDistanceType, predicate: samplesPredicate) { (_, _, _) in
                        // delete the workout last, after all associated objects are deleted.
                        self.healthStore.delete(workout, withCompletion: { (b, e) in
                            handler(true)
                        })
                    }
                }
            } else {
                // Fallback for iOS 8
                handler(false)
            }
        }
        
        if let workout = trip.workoutObject {
            deleteBlock(workout)
        } else {
            let workoutPredicate = HKQuery.predicateForObject(with: uuid)
            self.healthStore.execute(HKSampleQuery(sampleType: HKQuantityType.workoutType(), predicate: workoutPredicate, limit: 1, sortDescriptors: nil) { (query, results, error) in
                guard let workout = results?.first as? HKWorkout else {
                    handler(false)
                    return
                }
                
                deleteBlock(workout)
            })
        }
    }
    
    func saveOrUpdateTrip(_ trip:Trip, handler:@escaping (_ success: Bool)->Void={_ in }) {
        guard #available(iOS 9.0, *) else {
            handler(false)
            return
        }
        
        guard let activeEnergyBurnedType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned),
            let cyclingDistanceType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling) else {
                DDLogWarn("Couldn't find types!")
                handler(false)
                return
        }
        
        guard trip.startDate.compare(trip.endDate as Date) != .orderedDescending else {
            // https://github.com/KnockSoftware/Ride/issues/206
            DDLogInfo(String(format: "Workout start date is not before end date!"))
            handler(false)
            return
        }
        
        guard !trip.isBeingSavedToHealthKit else {
            DDLogWarn("Tried to save trip when it is already being saved!")
            handler(false)
            return
        }
        
        trip.isBeingSavedToHealthKit = true
        
        // delete any thing trip data that may have already been saved for this trip
        if trip.healthKitUuid != nil {
            DDLogWarn("Deleting existing workout with matching UUID.")
            self.deleteWorkoutAndSamplesForTrip(trip) { (success) in
                if success {
                    DispatchQueue.main.async {
                        trip.isBeingSavedToHealthKit = false
                        trip.healthKitUuid = nil
                        CoreDataManager.shared.saveContext()
                        self.saveOrUpdateTrip(trip, handler: handler)
                    }
                } else {
                    DDLogWarn("Failed to delete existing workout with matching UUID. Will try later.")
                    trip.isBeingSavedToHealthKit = false
                    handler(false)
                }
            }
            return
        }
        
        // an open or non-cycling trip should not be saved but it may need to be deleted (if it was a cycling trip at some point, or if it was resumed)
        guard trip.activityType == .cycling && trip.isClosed else {
            DDLogInfo(String(format: "Trip not closed or not a cycling trip. Skipping workout save…"))
            trip.isBeingSavedToHealthKit = false
            trip.isSavedToHealthKit = true
            handler(false)
            return
        }
        
        DDLogInfo(String(format: "Workout saving…"))
        
        // first, we calculate our total burn plus burn samples
        var totalBurn :HKQuantity? = nil
        var burnSamples :[HKSample] = []
        self.getHeartRateSamples(trip.startDate as Date, endDate: trip.endDate as Date) { (samples) -> Void in
            if let heartRateSamples = samples, heartRateSamples.count > 0 {
                // if we have heart rate samples, calculate using those based on:
                // http://www.shapesense.com/fitness-exercise/calculators/heart-rate-based-calorie-burn-calculator.aspx
                
                var totalBurnDouble : Double = 0
                
                for sample in heartRateSamples {
                    let heartRate = sample.quantity.doubleValue(for: HKUnit(from:"count/min"))
                    let minutes = ((sample.endDate.timeIntervalSinceReferenceDate - sample.startDate.timeIntervalSinceReferenceDate)/60)
                    let burnDouble : Double = {
                        switch self.currentGender {
                        case .male:
                            return ((-55.0969 + (0.6309 * heartRate) + (0.1988 * self.currentWeightKilograms) + (0.2017 * self.currentAgeYears))/4.184) * minutes
                        case .female, .other, .notSet:
                            return ((-20.4022 + (0.4472 * heartRate) - (0.1263 * self.currentWeightKilograms) + (0.074 * self.currentAgeYears))/4.184) * minutes
                        }
                    }()
                    
                    totalBurnDouble += burnDouble
                    let sample = HKQuantitySample(type: activeEnergyBurnedType, quantity: HKQuantity(unit: HKUnit.kilocalorie(),
                        doubleValue: burnDouble), start: sample.startDate, end: sample.endDate)
                    burnSamples.append(sample)
                }
                
                
            } else {
                // otherwise, calculate using speed based on:
                // http://www.acefitness.org/updateable/update_display.aspx?pageID=593

                var lastLoc : Location? = nil
                var totalBurnDouble : Double = 0
                for loc in trip.locations {
                    guard let location = loc as? Location, let speed = location.speed, let date = location.date else {
                        continue
                    }
                    if location.isGeofencedLocation {
                        continue
                    }
                    
                    if (location.date != nil && speed.doubleValue > 0 && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                        if let lastLocation = lastLoc, let lastDate = lastLocation.date, lastDate.compare(date as Date) != ComparisonResult.orderedDescending {
                            let calPerKgMin : Double = {
                                switch (speed.doubleValue) {
                                case 0...1:
                                    // standing
                                    return 0.4
                                case 1...4.47:
                                    //
                                    return 0.10
                                case 4.47...5.37:
                                    //
                                    return 0.12
                                case 5.37...6.26:
                                    return 0.14
                                case 6.26...7.15:
                                    return 0.18
                                default:
                                    return 0.21
                                }
                            }()
                            
                            let burnDouble = calPerKgMin * self.currentWeightKilograms * ((date.timeIntervalSinceReferenceDate - lastDate.timeIntervalSinceReferenceDate)/60)
                            totalBurnDouble += burnDouble
                            let sample = HKQuantitySample(type: activeEnergyBurnedType, quantity: HKQuantity(unit: HKUnit.kilocalorie(),
                                doubleValue: burnDouble), start: lastDate as Date, end: date as Date)
                            
                            
                            burnSamples.append(sample)
                        }
                        
                        lastLoc = location
                    }
                }
                
                totalBurn = HKQuantity(unit: HKUnit.kilocalorie(),
                    doubleValue: totalBurnDouble)
            }
            
            let distance = HKQuantity(unit: HKUnit.mile(), doubleValue: Double(trip.length.miles))
            let cyclingDistanceSample = HKQuantitySample(type: cyclingDistanceType, quantity: distance, start: trip.startDate as Date, end: trip.endDate as Date)
            
            let ride = HKWorkout(activityType: HKWorkoutActivityType.cycling, start: trip.startDate as Date, end: trip.endDate as Date, duration: trip.duration(), totalEnergyBurned: totalBurn, totalDistance: distance, device:HKDevice.local(), metadata: [HKMetadataKeyIndoorWorkout: false])
            
            // Save the workout before adding detailed samples.
            self.healthStore.save(ride, withCompletion: { (success, error) -> Void in
                if !success {
                    // log error
                    DDLogInfo(String(format: "Workout save failed! error: %@", error as CVarArg? ?? "No error"))
                    trip.isBeingSavedToHealthKit = false
                    handler(false)
                } else {
                    DDLogInfo(String(format: "Workout saved."))
                    DispatchQueue.main.async {
                        trip.healthKitUuid = ride.uuid.uuidString
                        trip.isSavedToHealthKit = true
                        CoreDataManager.shared.saveContext()
                    }
                    
                    self.healthStore.add([cyclingDistanceSample], to: ride) { (success, _) in
                        
                        self.healthStore.add(burnSamples, to: ride) { (_, _) -> Void in
                            if let heartRateSamples = samples, heartRateSamples.count > 0 {
                                self.healthStore.add(heartRateSamples, to: ride) { (_, _) -> Void in
                                    trip.isBeingSavedToHealthKit = false
                                    handler(true)
                                }
                            } else {
                                trip.isBeingSavedToHealthKit = false
                                handler(true)
                            }
                        }
                    }
                }
            }) 
        }
    }
}
