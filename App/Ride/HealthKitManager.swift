//
//  HealthKitManager.swift
//  Ride
//
//  Created by William Henderson on 10/2/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import HealthKit

class HealthKitManager {
    let healthStore = HKHealthStore()
    
    // default values based on averages
    var currentWeightKilograms  = 62.0
    var currentGender : HKBiologicalSex = HKBiologicalSex.NotSet
    var currentAgeYears = 30.0

    
    struct Static {
        static var sharedManager : HealthKitManager?
    }

    
    class var sharedManager:HealthKitManager {
        return Static.sharedManager!
    }
    
    class func startup() {
        if (Static.sharedManager == nil) {
            Static.sharedManager = HealthKitManager()
            Static.sharedManager?.startup()
        }
    }
    
    func startup() {
        self.requestAuthorization()
    }
    
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        let readTypes : Set<HKObjectType> = [HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBiologicalSex)!,
                                            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!,
                                            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!]
        let writeTypes : Set<HKSampleType> = [HKQuantityType.workoutType(),
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!]
        
        healthStore.requestAuthorizationToShareTypes(writeTypes, readTypes: readTypes) { (success, error) -> Void in
            if !success || error != nil {
                DDLogWarn("Error accesing health kit data!: \(error! as NSError), \((error! as NSError).userInfo)")
            } else {
                self.getWeight()
                self.getGender()
                self.getAge()
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
    
    func logTrip(trip:Trip) {
        guard #available(iOS 9.0, *) else {
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
                    
                    if (location.date != nil && location.speed!.doubleValue > 0 && location.horizontalAccuracy!.doubleValue <= RouteManager.sharedManager.acceptableLocationAccuracy) {
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
            
            let distance = HKQuantity(unit: HKUnit.mileUnit(), doubleValue: Double(trip.lengthMiles))

            let ride = HKWorkout(activityType: HKWorkoutActivityType.Cycling, startDate: trip.startDate, endDate: trip.endDate, duration: trip.endDate.timeIntervalSinceDate(trip.startDate), totalEnergyBurned: totalBurn, totalDistance: distance, device:HKDevice.localDevice(), metadata: [HKMetadataKeyIndoorWorkout: false])
            
            // Save the workout before adding detailed samples.
            self.healthStore.saveObject(ride) { (success, error) -> Void in
                if !success {
                    // log error
                    // callback
                } else {
                    self.healthStore.addSamples(burnSamples, toWorkout: ride, completion: { (_, _) -> Void in
                        if let heartRateSamples = samples where heartRateSamples.count > 0 {
                            self.healthStore.addSamples(heartRateSamples, toWorkout: ride, completion: { (_, _) -> Void in
                                // callback
                            })
                        } else {
                            // callback
                        }
                    })
                }
            }
        }
    }
}