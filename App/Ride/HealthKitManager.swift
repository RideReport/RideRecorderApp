//
//  HealthKitManager.swift
//  Ride
//
//  Created by William Henderson on 10/2/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import HealthKit

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
        
        let readTypes : Set<HKObjectType> = [HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBiologicalSex)!,
                                             HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierDateOfBirth)!,
                                            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!,
                                            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!]
        let writeTypes : Set<HKSampleType> = [HKQuantityType.workoutType(),
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling)!]
        
        healthStore.requestAuthorizationToShareTypes(writeTypes, readTypes: readTypes) { (success, error) -> Void in
            if !success || error != nil {
                DDLogWarn("Error accesing health kit data!: \(error! as NSError), \((error! as NSError).userInfo)")
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
                    authorizationHandler(success: true)
                }
            }
        }
    }
    
    func getHeartRateSamples(startDate:NSDate, endDate: NSDate, completionHandler:([HKQuantitySample]?)->Void) {
        let heartRateType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)
        let predicate = HKQuery.predicateForSamplesWithStartDate(startDate, endDate: endDate, options: HKQueryOptions.None)
        
        let query = HKSampleQuery(sampleType: heartRateType!, predicate: predicate, limit: 0, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate , ascending: false)]) { (query, results, error) -> Void in
            completionHandler(results as! [HKQuantitySample]?)
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
        let weightType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMassIndex)
        
        let query = HKSampleQuery(sampleType: weightType!, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate , ascending: false)]) { (query, results, error) -> Void in
            if (results == nil) {
                if (error != nil) {
                    
                }
            } else {
                if (results!.count < 1) {
                    // ask for the user's weight
                } else {
                    self.currentWeightKilograms = ((results!.first! as! HKQuantitySample).quantity.doubleValueForUnit(HKUnit.gramUnit())) / 1000.0
                }
            }
        }
        
        self.healthStore.executeQuery(query)
    }
    
    func deleteWorkoutAndSamplesForWorkoutUUID(uuidString: String, handler: ()->()) {
        guard let uuid = NSUUID(UUIDString: uuidString) else {
            handler()
            return
        }
        
        let workoutPredicate = HKQuery.predicateForObjectWithUUID(uuid)
        self.healthStore.executeQuery(HKSampleQuery(sampleType: HKQuantityType.workoutType(), predicate: workoutPredicate, limit: 1, sortDescriptors: nil) { (query, results, error) in
            guard let workout = results?.first as? HKWorkout else {
                handler()
                return
            }
            
            let samplesPredicate = HKQuery.predicateForObjectsFromWorkout(workout)
            if #available(iOS 9.0, *) {
                self.healthStore.deleteObjectsOfType(HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!, predicate: samplesPredicate) { (_, _, _) in
                    // for all deletions, we make a best attempt and proceed with the handler regardless of the result
                    self.healthStore.deleteObjectsOfType(HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling)!, predicate: samplesPredicate) { (_, _, _) in
                        // delete the workout last, after all associated objects are deleted.
                        self.healthStore.deleteObject(workout, withCompletion: { (b, e) in
                            handler()
                        })
                    }
                }
            } else {
                // Fallback for iOS 8
                handler()
                self.healthStore.deleteObject(workout, withCompletion: { (_, _) in
                    handler()
                })
            }
        })
    }
    
    func saveTrip(trip:Trip, handler:(success: Bool)->Void={_ in }) {
        guard #available(iOS 9.0, *) else {
            handler(success: false)
            return
        }
        
        // delete any thing trip data that may have already been saved for this trip
        if let uuid = trip.healthKitUuid {
            self.deleteWorkoutAndSamplesForWorkoutUUID(uuid) {
                dispatch_async(dispatch_get_main_queue()) {
                    trip.healthKitUuid = nil
                    CoreDataManager.sharedManager.saveContext()
                    self.saveTrip(trip)
                }
            }
            handler(success: false)
            return
        }
        
        // first, we calculate our total burn plus burn samples
        var totalBurn :HKQuantity! = nil
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
                    let sample = HKQuantitySample(type: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!, quantity: HKQuantity(unit: HKUnit.kilocalorieUnit(),
                        doubleValue: burnDouble), startDate: sample.startDate, endDate: sample.endDate)
                    burnSamples.append(sample)
                }
                
                
            } else {
                // otherwise, calculate using speed based on:
                // http://www.acefitness.org/updateable/update_display.aspx?pageID=593

                var lastLoc : Location! = nil
                var totalBurnDouble : Double = 0
                for loc in trip.locations {
                    let location = loc as! Location
                    if location.isGeofencedLocation {
                        continue
                    }
                    
                    if (location.date != nil && location.speed!.doubleValue > 0 && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                        if (lastLoc != nil && lastLoc.date!.compare(location.date!) != NSComparisonResult.OrderedDescending) {
                            let calPerKgMin : Double = {
                                switch (location.speed!.doubleValue) {
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
                            
                            let burnDouble = calPerKgMin * self.currentWeightKilograms * ((location.date!.timeIntervalSinceReferenceDate - lastLoc.date!.timeIntervalSinceReferenceDate)/60)
                            totalBurnDouble += burnDouble
                            let sample = HKQuantitySample(type: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!, quantity: HKQuantity(unit: HKUnit.kilocalorieUnit(),
                                doubleValue: burnDouble), startDate: lastLoc.date!, endDate: location.date!)
                            
                            
                            burnSamples.append(sample)
                        }
                        
                        lastLoc = location
                    }
                }
                
                totalBurn = HKQuantity(unit: HKUnit.kilocalorieUnit(),
                    doubleValue: totalBurnDouble)
            }
            
            let distance = HKQuantity(unit: HKUnit.mileUnit(), doubleValue: Double(trip.length.miles))
            let cyclingDistanceSample = HKQuantitySample(type: HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling)!, quantity: distance, startDate: trip.startDate, endDate: trip.endDate)
            
            let ride = HKWorkout(activityType: HKWorkoutActivityType.Cycling, startDate: trip.startDate, endDate: trip.endDate, duration: trip.duration(), totalEnergyBurned: totalBurn, totalDistance: distance, device:HKDevice.localDevice(), metadata: [HKMetadataKeyIndoorWorkout: false])
            
            // Save the workout before adding detailed samples.
            self.healthStore.saveObject(ride) { (success, error) -> Void in
                if !success {
                    // log error
                    handler(success: false)
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        trip.healthKitUuid = ride.UUID.UUIDString
                        CoreDataManager.sharedManager.saveContext()
                    }
                    
                    self.healthStore.addSamples([cyclingDistanceSample], toWorkout: ride) { (success, _) in
                        
                        self.healthStore.addSamples(burnSamples, toWorkout: ride) { (_, _) -> Void in
                            if let heartRateSamples = samples where heartRateSamples.count > 0 {
                                self.healthStore.addSamples(heartRateSamples, toWorkout: ride) { (_, _) -> Void in
                                    handler(success: true)
                                }
                            } else {
                                handler(success: true)
                            }
                        }
                    }
                }
            }
        }
    }
}