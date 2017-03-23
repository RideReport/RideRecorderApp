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
    
    var firstTripDate: Date? {
        if let trip = Trip.leastRecentBikeTrip() {
            return trip.creationDate as Date?
        }
        
        return nil
    }
    
    var metersBiked : Meters {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.cycling.rawValue)
        
        let sumDescription = NSExpressionDescription()
        sumDescription.name = "sumOfLengths"
        sumDescription.expression = NSExpression(forKeyPath: "@sum.length")
        sumDescription.expressionResultType = NSAttributeType.floatAttributeType
        fetchedRequest.propertiesToFetch = [sumDescription]
        
        var error : NSError?
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error1 as NSError {
            error = error1
            results = nil
        }
        if (results == nil || error != nil) {
            return 0.0
        }
        let totalLength = (results![0] as! NSDictionary).object(forKey: "sumOfLengths") as! NSNumber
        return totalLength.floatValue
    }
    
    var tripsBikedJewel: String {
        let totalTrips = Trip.numberOfCycledTrips
        if totalTrips > 5000 {
            return "🌈"
        } else if totalTrips > 2000 {
            return "🌌"
        } else if totalTrips > 1000 {
            return "🌠"
        } else if totalTrips > 500 {
            return "🌋"
        } else if totalTrips > 100 {
            return "🗻"
        } else if totalTrips > 50 {
            return "🏔"
        } else if totalTrips > 25 {
            return "⛰"
        } else if totalTrips > 10 {
            return "🌅"
        } else {
            return "🌄"
        }
    }
    
    var distanceBikedImpressiveStat: (emoji: String, description: String) {
        let totalMiles = self.metersBiked.miles
        if totalMiles > 20000 {
            return ("🌍", String(format: "%@ (around the world %.1f times)!", self.metersBiked.distanceString(), totalMiles/24901))
        } else if totalMiles > 6000 {
            return ("🌘", String(format: "%@ (around the moon %.1f times)!", self.metersBiked.distanceString(), totalMiles/6786))
        } else if totalMiles > 1700 {
            return ("🇺🇸", String(format: "%@ (across the US %.1f times)!", self.metersBiked.distanceString(), totalMiles/2680))
        } else if totalMiles > 810 {
            return ("🏔", String(format: "%@ (across Alaska %.1f times)!", self.metersBiked.distanceString(), totalMiles/770))
        } else if totalMiles > 400 {
            return ("🌲", String(format: "%@ (across Oregon %.1f times)!", self.metersBiked.distanceString(), totalMiles/400))
        } else if totalMiles > 250 {
            return ("🌅", String(format: "%@ (across California %.1f times)!", self.metersBiked.distanceString(), totalMiles/250))
        } else if totalMiles > 37 {
            return ("🐄", String(format: "%@ (across Vermont %.1f times)!", self.metersBiked.distanceString(), totalMiles/37))
        } else {
            return ("🐣", String(format: "%.1f", totalMiles))
        }
    }
    
    private func jewelForLength(_ length: Int)->String {
        if length >= 100 {
            return "🏆"
        } else if length >= 50 {
            return "🏅"
        } else if length >= 25 {
            return "🚀"
        } else if length >= 14 {
            return "🔥"
        } else if length >= 10 {
            return "💙"
        } else if length >= 7 {
            return "💚"
        } else if length >= 5 {
            return "💛"
        } else if length >= 3 {
            return "💜"
        } else {
            return "❤️"
        }
    }
}
