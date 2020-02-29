//
//  Profile.swift
//  Ride Report
//
//  Created by William Henderson on 4/30/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation
import HealthKit
import CocoaLumberjack

public class Profile: NSManagedObject {
    
    public var weightKilograms: Double? {
        get {
            willAccessValue(forKey: "weightKilograms")
            defer { didAccessValue(forKey: "weightKilograms") }
            return (self.primitiveValue(forKey: "weightKilograms") as? NSNumber)?.doubleValue
        }
        set {
            willChangeValue(forKey: "weightKilograms")
            defer { didChangeValue(forKey: "weightKilograms") }
            self.setPrimitiveValue(newValue.map({NSNumber(value: $0)}), forKey: "weightKilograms")
        }
    }
    
    public var gender: HKBiologicalSex {
        get {
            willAccessValue(forKey: "gender")
            defer { didAccessValue(forKey: "gender") }
            guard let genderRawValue = self.primitiveValue(forKey: "gender") as? Int else {
                return HKBiologicalSex.notSet
            }
            return HKBiologicalSex(rawValue: genderRawValue) ?? HKBiologicalSex.notSet
        }
        set {
            willChangeValue(forKey: "gender")
            defer { didChangeValue(forKey: "gender") }
            self.setPrimitiveValue(newValue.rawValue, forKey: "gender")
        }
    }

    struct Static {
        static var onceToken : Int = 0
        static var profile : Profile!
    }

    class func resetPagitionState() {
        if let _ = Static.profile {
            CoreDataManager.shared.saveContext()
        }
    }
    
    class func resetProfile() {
        Static.profile = nil
    }
    
    
    private var featureFlagObservation: NSKeyValueObservation?
    
    class func profile() -> Profile {
        if (Static.profile == nil) {
            let context = CoreDataManager.shared.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Profile")
            fetchedRequest.fetchLimit = 1
            
            let results: [AnyObject]?
            do {
                results = try context.fetch(fetchedRequest)
            } catch let error {
                DDLogWarn(String(format: "Error finding profile: %@", error as NSError))
                results = nil
            }
            
            if let results = results, let profileResult = results.first as? Profile {
                Static.profile = profileResult
            } else {
                let context = CoreDataManager.shared.currentManagedObjectContext()
                Static.profile = Profile(entity: NSEntityDescription.entity(forEntityName: "Profile", in: context)!, insertInto:context)
                CoreDataManager.shared.saveContext()
            }
        }
        
        return Static.profile
    }
    
}
