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
    
    var featureFlags : [String] = [] {
        didSet {
            if featureFlags.contains("rating_version_2") {
                DispatchQueue.main.async {
                    self.ratingVersion = RatingVersion.v2beta
                    CoreDataManager.shared.saveContext()
                }
            } else {
                self.ratingVersion = RatingVersion.v1
            }
        }
    }

    struct Static {
        static var onceToken : Int = 0
        static var profile : Profile!
    }
    
    fileprivate(set) var ratingVersion: RatingVersion {
        get {
            return RatingVersion(rawValue: self.currentRatingVersion) ?? RatingVersion.v1
        }
        set {
            self.currentRatingVersion = newValue.rawValue
            // reregister for notifications
            NotificationManager.shared.registerNotifications()
        }
    }
    
    class func resetProfile() {
        Static.profile = nil
    }
    
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
    
    func eligibilePromotion()->Promotion? {
        if let promo = self.promotions.array.first as? Promotion, promo.isUserDismissed == false {
            if let app = promo.connectedApp, app.profile != nil {
                // if the app is already connected, skip it!
                return nil
            }
            return promo
        }
        
        return nil
    }
}
