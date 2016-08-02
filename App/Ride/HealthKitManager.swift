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
    case NotDetermined
    case Denied
    case Authorized
}


class HealthKitManager {
    let healthStore = HKHealthStore()
    
    // default values based on averages
    var currentWeightKilograms  = 62.0
    var currentGender : HKBiologicalSex = HKBiologicalSex.NotSet
    var currentAgeYears = 30.0
    
    private var tripsRemainingToSave: [Trip]?

    
    struct Static {
        static var sharedManager : HealthKitManager?
        static var authorizationStatus : HealthKitManagerAuthorizationStatus = .NotDetermined
    }
    
    class var authorizationStatus: HealthKitManagerAuthorizationStatus {
        get {
            return Static.authorizationStatus
        }
        
        set {
            Static.authorizationStatus = newValue
        }
    }

    
    class var sharedManager:HealthKitManager {
        return Static.sharedManager!
    }
    
    class func startup(authorizationHandler:(success: Bool)->() = {_ in}) {
        if (Static.sharedManager == nil) {
            Static.sharedManager = HealthKitManager()
            dispatch_async(dispatch_get_main_queue()) {
                // startup async
                Static.sharedManager!.startup(authorizationHandler)
            }
        }
    }
    
    class func shutdown() {
        Static.sharedManager = nil
        Static.authorizationStatus = .NotDetermined
    }
    
    func startup(authorizationHandler:(success: Bool)->()={_ in }) {
        self.requestAuthorization(authorizationHandler)
    }
    
    private func requestAuthorization(authorizationHandler:(success: Bool)->()={_ in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        guard let sexCharacteristic = HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBiologicalSex),
            dobCharacteristc = HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierDateOfBirth),
            bodyMassCharacteristic = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass),
            heartRateCharactertistic = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate),
            energyBurnedType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned),
            cyclingType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling) else {
                DDLogWarn("Couldn't find charactertisitcs and/or types!")
                return
        }
        
        let readTypes : Set<HKObjectType> = [sexCharacteristic, dobCharacteristc, bodyMassCharacteristic, heartRateCharactertistic]
        let writeTypes : Set<HKSampleType> = [HKQuantityType.workoutType(), energyBurnedType, cyclingType]
        
        healthStore.requestAuthorizationToShareTypes(writeTypes, readTypes: readTypes) { (success, err) -> Void in
            if let error = err {
                DDLogWarn("Error accesing health kit data!: \(error), \(error.userInfo)")
                HealthKitManager.authorizationStatus = .Denied
                dispatch_async(dispatch_get_main_queue()) {
                    authorizationHandler(success: false)
                }
            } else {
                HealthKitManager.authorizationStatus = .Authorized
                self.getWeight()
                self.getGender()
                self.getAge()
                dispatch_async(dispatch_get_main_queue()) {
                    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HealthKitManager.saveUnsavedTrips), name: UIApplicationDidBecomeActiveNotification, object: nil)
                    self.saveUnsavedTrips()
                    authorizationHandler(success: true)
                }
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc private func saveUnsavedTrips() {
        if (UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
            dispatch_async(dispatch_get_main_queue()) {
                let context = CoreDataManager.sharedManager.currentManagedObjectContext()
                let fetchedRequest = NSFetchRequest(entityName: "Trip")
                fetchedRequest.predicate = NSPredicate(format: "isSavedToHealthKit == false")
                fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let results: [AnyObject]?
                do {
                    results = try context.executeFetchRequest(fetchedRequest)
                } catch let error {
                    DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
                    return
                }
                guard let theTrips = results as? [Trip] where theTrips.count > 0 else {
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
    
    func getHeartRateSamples(startDate:NSDate, endDate: NSDate, completionHandler:([HKQuantitySample]?)->Void) {
        guard let heartRateType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else {
            DDLogWarn("Couldn't find heart rate type!")
            completionHandler(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamplesWithStartDate(startDate, endDate: endDate, options: HKQueryOptions.None)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 0, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate , ascending: false)]) { (query, results, error) -> Void in
            completionHandler(results as? [HKQuantitySample])
        }
        
        self.healthStore.executeQuery(query)
    }
    
    func getAge() {
        do {
            let dob = try self.healthStore.dateOfBirth()
            self.currentAgeYears = Double(NSCalendar.currentCalendar().components(NSCalendarUnit.Year, fromDate: dob, toDate: NSDate(), options: NSCalendarOptions.WrapComponents).year)
        } catch _ {
        }
    }
    
    func getGender() {
        do {
            self.currentGender = try self.healthStore.biologicalSex().biologicalSex
        } catch _ {
            self.currentGender = HKBiologicalSex.NotSet
        }
    }
    
    func getWeight() {
        guard let weightType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMassIndex) else {
            DDLogWarn("Couldn't find body mass type!")
            return
        }
        
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate , ascending: false)]) { (query, res, error) -> Void in
            if let results = res {
                if let result = results.first as? HKQuantitySample {
                    self.currentWeightKilograms = (result.quantity.doubleValueForUnit(HKUnit.gramUnit())) / 1000.0
                } else {
                    // ask for the user's weight?
                }
            } else {
                if (error != nil) {
                    
                }
            }
        }
        
        self.healthStore.executeQuery(query)
    }
    
    func deleteWorkoutAndSamplesForTrip(trip:Trip, handler: (success: Bool)->()) {
        guard let activeEnergyBurnedType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned),
                cyclingDistanceType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling) else {
                DDLogWarn("Couldn't find types!")
                handler(success: false)
                return
        }
        
        guard let uuidString = trip.healthKitUuid, uuid = NSUUID(UUIDString: uuidString) else {
            handler(success: false)
            return
        }
        
        let deleteBlock = { (workout: HKWorkout) in
            let samplesPredicate = HKQuery.predicateForObjectsFromWorkout(workout)
            if #available(iOS 9.0, *) {
                self.healthStore.deleteObjectsOfType(activeEnergyBurnedType, predicate: samplesPredicate) { (_, _, _) in
                    // for all deletions, we make a best attempt and proceed with the handler regardless of the result
                    self.healthStore.deleteObjectsOfType(cyclingDistanceType, predicate: samplesPredicate) { (_, _, _) in
                        // delete the workout last, after all associated objects are deleted.
                        self.healthStore.deleteObject(workout, withCompletion: { (b, e) in
                            handler(success: true)
                        })
                    }
                }
            } else {
                // Fallback for iOS 8
                handler(success: false)
            }
        }
        
        if let workout = trip.workoutObject {
            deleteBlock(workout)
        } else {
            let workoutPredicate = HKQuery.predicateForObjectWithUUID(uuid)
            self.healthStore.executeQuery(HKSampleQuery(sampleType: HKQuantityType.workoutType(), predicate: workoutPredicate, limit: 1, sortDescriptors: nil) { (query, results, error) in
                guard let workout = results?.first as? HKWorkout else {
                    handler(success: false)
                    return
                }
                
                deleteBlock(workout)
            })
        }
    }
    
    func saveOrUpdateTrip(trip:Trip, handler:(success: Bool)->Void={_ in }) {
        guard #available(iOS 9.0, *) else {
            handler(success: false)
            return
        }
        
        guard let activeEnergyBurnedType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned),
            cyclingDistanceType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling) else {
                DDLogWarn("Couldn't find types!")
                handler(success: false)
                return
        }
        
        guard trip.startDate.compare(trip.endDate) != .OrderedDescending else {
            // https://github.com/KnockSoftware/Ride/issues/206
            handler(success: false)
            return
        }
        
        guard !trip.isBeingSavedToHealthKit else {
            DDLogWarn("Tried to save trip when it is already being saved!")
            handler(success: false)
            return
        }
        
        trip.isBeingSavedToHealthKit = true
        
        // delete any thing trip data that may have already been saved for this trip
        if trip.healthKitUuid != nil {
            DDLogWarn("Deleting existing workout with matching UUID.")
            self.deleteWorkoutAndSamplesForTrip(trip) { (success) in
                if success {
                    dispatch_async(dispatch_get_main_queue()) {
                        trip.isBeingSavedToHealthKit = false
                        trip.healthKitUuid = nil
                        CoreDataManager.sharedManager.saveContext()
                        self.saveOrUpdateTrip(trip, handler: handler)
                    }
                } else {
                    DDLogWarn("Failed to delete existing workout with matching UUID. Will try later.")
                    trip.isBeingSavedToHealthKit = false
                    handler(success: false)
                }
            }
            return
        }
        
        // an open or non-cycling trip should not be saved but it may need to be deleted (if it was a cycling trip at some point, or if it was resumed)
        guard trip.activityType == .Cycling && trip.isClosed else {
            trip.isBeingSavedToHealthKit = false
            trip.isSavedToHealthKit = true
            handler(success: false)
            return
        }
        
        // first, we calculate our total burn plus burn samples
        var totalBurn :HKQuantity? = nil
        var burnSamples :[HKSample] = []
        self.getHeartRateSamples(trip.startDate, endDate: trip.endDate) { (samples) -> Void in
            if let heartRateSamples = samples where heartRateSamples.count > 0 {
                // if we have heart rate samples, calculate using those based on:
                // http://www.shapesense.com/fitness-exercise/calculators/heart-rate-based-calorie-burn-calculator.aspx
                
                var totalBurnDouble : Double = 0
                
                for sample in heartRateSamples {
                    let heartRate = sample.quantity.doubleValueForUnit(HKUnit(fromString:"count/min"))
                    let minutes = ((sample.endDate.timeIntervalSinceReferenceDate - sample.startDate.timeIntervalSinceReferenceDate)/60)
                    let burnDouble : Double = {
                        switch self.currentGender {
                        case .Male:
                            return ((-55.0969 + (0.6309 * heartRate) + (0.1988 * self.currentWeightKilograms) + (0.2017 * self.currentAgeYears))/4.184) * minutes
                        case .Female, .Other, .NotSet:
                            return ((-20.4022 + (0.4472 * heartRate) - (0.1263 * self.currentWeightKilograms) + (0.074 * self.currentAgeYears))/4.184) * minutes
                        }
                    }()
                    
                    totalBurnDouble += burnDouble
                    let sample = HKQuantitySample(type: activeEnergyBurnedType, quantity: HKQuantity(unit: HKUnit.kilocalorieUnit(),
                        doubleValue: burnDouble), startDate: sample.startDate, endDate: sample.endDate)
                    burnSamples.append(sample)
                }
                
                
            } else {
                // otherwise, calculate using speed based on:
                // http://www.acefitness.org/updateable/update_display.aspx?pageID=593

                var lastLoc : Location? = nil
                var totalBurnDouble : Double = 0
                for loc in trip.locations {
                    guard let location = loc as? Location, speed = location.speed, date = location.date else {
                        continue
                    }
                    if location.isGeofencedLocation {
                        continue
                    }
                    
                    if (location.date != nil && speed.doubleValue > 0 && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                        if let lastLocation = lastLoc, let lastDate = lastLocation.date where lastDate.compare(date) != NSComparisonResult.OrderedDescending {
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
                            let sample = HKQuantitySample(type: activeEnergyBurnedType, quantity: HKQuantity(unit: HKUnit.kilocalorieUnit(),
                                doubleValue: burnDouble), startDate: lastDate, endDate: date)
                            
                            
                            burnSamples.append(sample)
                        }
                        
                        lastLoc = location
                    }
                }
                
                totalBurn = HKQuantity(unit: HKUnit.kilocalorieUnit(),
                    doubleValue: totalBurnDouble)
            }
            
            let distance = HKQuantity(unit: HKUnit.mileUnit(), doubleValue: Double(trip.length.miles))
            let cyclingDistanceSample = HKQuantitySample(type: cyclingDistanceType, quantity: distance, startDate: trip.startDate, endDate: trip.endDate)
            
            let ride = HKWorkout(activityType: HKWorkoutActivityType.Cycling, startDate: trip.startDate, endDate: trip.endDate, duration: trip.duration(), totalEnergyBurned: totalBurn, totalDistance: distance, device:HKDevice.localDevice(), metadata: [HKMetadataKeyIndoorWorkout: false])
            
            // Save the workout before adding detailed samples.
            self.healthStore.saveObject(ride) { (success, error) -> Void in
                if !success {
                    // log error
                    DDLogInfo(String(format: "Workout save failed! error: %@", error ?? "No error"))
                    trip.isBeingSavedToHealthKit = false
                    handler(success: false)
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        trip.healthKitUuid = ride.UUID.UUIDString
                        trip.isSavedToHealthKit = true
                        CoreDataManager.sharedManager.saveContext()
                    }
                    
                    self.healthStore.addSamples([cyclingDistanceSample], toWorkout: ride) { (success, _) in
                        
                        self.healthStore.addSamples(burnSamples, toWorkout: ride) { (_, _) -> Void in
                            if let heartRateSamples = samples where heartRateSamples.count > 0 {
                                self.healthStore.addSamples(heartRateSamples, toWorkout: ride) { (_, _) -> Void in
                                    trip.isBeingSavedToHealthKit = false
                                    handler(success: true)
                                }
                            } else {
                                trip.isBeingSavedToHealthKit = false
                                handler(success: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
