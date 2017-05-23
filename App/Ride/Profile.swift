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

class Profile : NSManagedObject {
    @NSManaged var accessToken : String?
    @NSManaged var supportId : String?
    @NSManaged var accessTokenExpiresIn : Date?
    @NSManaged var statusText : String?
    @NSManaged var statusEmoji : String?
    @NSManaged private(set) var lastGeofencedLocation : Location?
    @NSManaged var connectedApps : NSOrderedSet!
    
    @NSManaged var dateOfBirth : Date?
    @NSManaged var weightKilograms : NSNumber?
    @NSManaged var gender : NSNumber
    
    @NSManaged var currentRatingVersion : NSNumber
    
    @NSManaged var promotions : NSSet!
    
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
            return RatingVersion(rawValue: self.currentRatingVersion.int16Value) ?? RatingVersion.v1
        }
        set {
            self.currentRatingVersion = NSNumber(value: newValue.rawValue)
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
            
            if (results!.count == 0) {
                let context = CoreDataManager.shared.currentManagedObjectContext()
                Static.profile = Profile(entity: NSEntityDescription.entity(forEntityName: "Profile", in: context)!, insertInto:context)
                CoreDataManager.shared.saveContext()
            } else {
                Static.profile = (results!.first as! Profile)
            }
        }
        
        return Static.profile
    }
    
    func eligibilePromotion()->Promotion? {
        if let promo = self.promotions.allObjects.first as? Promotion, promo.userDismissed == false {
            if let app = promo.connectedApp, app.profile != nil {
                // if the app is already connected, skip it!
                return nil
            }
            return promo
        }
        
        return nil
    }
    
    func setGeofencedLocation(_ location: CLLocation?) {
        if let loc = self.lastGeofencedLocation {
            self.lastGeofencedLocation = nil
            loc.managedObjectContext?.delete(loc)
        }
        
        if let loc = location {
            self.lastGeofencedLocation = Location(location: loc, geofencedLocationOfProfile: self)
        }
        CoreDataManager.shared.saveContext()
    }
}
