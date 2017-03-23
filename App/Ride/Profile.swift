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

    struct Static {
        static var onceToken : Int = 0
        static var profile : Profile!
    }
    
    class func resetProfile() {
        Static.profile = nil
    }
    
    class func profile() -> Profile! {
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
