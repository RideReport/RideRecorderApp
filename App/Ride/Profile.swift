//
//  Profile.swift
//  Ride Report
//
//  Created by William Henderson on 4/30/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class Profile : NSManagedObject {
    @NSManaged var accessToken : String?
    @NSManaged var accessTokenExpiresIn : NSDate?
    @NSManaged var currentStreakStartDate : NSDate?
    @NSManaged var currentStreakLength : NSNumber?
    @NSManaged var longestStreakStartDate : NSDate?
    @NSManaged var longestStreakLength : NSNumber?
    @NSManaged private(set) var lastGeofencedLocation : Location?

    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var profile : Profile!
    }
    
    class func profile() -> Profile! {
        if (Static.profile == nil) {
            let context = CoreDataManager.sharedManager.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest(entityName: "Profile")
            fetchedRequest.fetchLimit = 1
            
            let results: [AnyObject]?
            do {
                results = try context.executeFetchRequest(fetchedRequest)
            } catch let error {
                DDLogWarn(String(format: "Error finding profile: %@", error as NSError))
                results = nil
            }
            
            if (results!.count == 0) {
                let context = CoreDataManager.sharedManager.currentManagedObjectContext()
                Static.profile = Profile(entity: NSEntityDescription.entityForName("Profile", inManagedObjectContext: context)!, insertIntoManagedObjectContext:context)
                CoreDataManager.sharedManager.saveContext()
            } else {
                Static.profile = (results!.first as! Profile)
            }
        }
        
        return Static.profile
    }
    
    func setGeofencedLocation(location: CLLocation?) {
        if let loc = self.lastGeofencedLocation {
            self.lastGeofencedLocation = nil
            loc.managedObjectContext?.deleteObject(loc)
        }
        
        if let loc = location {
            self.lastGeofencedLocation = Location(location: loc, geofencedLocationOfProfile: self)
        }
        CoreDataManager.sharedManager.saveContext()
    }
    
    var firstTripDate: NSDate? {
        if let trip = Trip.leastRecentBikeTrip() {
            return trip.creationDate
        }
        
        return nil
    }
    
    var milesBiked : Float {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.DictionaryResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", Trip.ActivityType.Cycling.rawValue)
        
        let sumDescription = NSExpressionDescription()
        sumDescription.name = "sumOfLengths"
        sumDescription.expression = NSExpression(forKeyPath: "@sum.length")
        sumDescription.expressionResultType = NSAttributeType.FloatAttributeType
        fetchedRequest.propertiesToFetch = [sumDescription]
        
        var error : NSError?
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error1 as NSError {
            error = error1
            results = nil
        }
        if (results == nil || error != nil) {
            return 0.0
        }
        let totalLength = (results![0] as! NSDictionary).objectForKey("sumOfLengths") as! NSNumber
        return (totalLength.floatValue * 0.000621371)
    }
    
    var milesBikedJewel: String {
        let totalMiles = self.milesBiked
        if totalMiles > 5000 {
            return "🌈  "
        } else if totalMiles > 2000 {
            return "🌌  "
        } else if totalMiles > 1000 {
            return "🌠  "
        } else if totalMiles > 500 {
            return "🌋  "
        } else if totalMiles > 100 {
            return "🗻  "
        } else if totalMiles > 50 {
            return "🏔  "
        } else if totalMiles > 25 {
            return "⛰  "
        } else if totalMiles > 10 {
            return "🌅  "
        } else {
            return "🌄  "
        }
    }
    
    var currentStreakJewel: String {
        guard let streakLength = self.currentStreakLength else {
            return ""
        }
        
        return self.jewelForLength(streakLength.integerValue)
    }
    
    var longestStreakJewel: String {
        guard let streakLength = self.longestStreakLength else {
            return ""
        }
        
        return self.jewelForLength(streakLength.integerValue)
    }
    
    private func jewelForLength(length: Int)->String {
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
    
    func updateCurrentRideStreakLength() {
        if (self.longestStreakStartDate == nil || self.longestStreakLength == nil) {
            var longestStreakFoundYetLength = 0
            var longestStreakFoundYetStartDate = NSDate()
            
            var thisStreakLength = 0
            var thisStreakStartDate = NSDate()
            for trip in Trip.allBikeTrips() {
                let tripDate = (trip as! Trip).creationDate
                if (tripDate.isEqualToDay(thisStreakStartDate)) {
                    thisStreakStartDate = thisStreakStartDate.daysFrom(-1)
                    thisStreakLength += 1
                } else if (tripDate.compare(thisStreakStartDate) == NSComparisonResult.OrderedDescending) {
                    // if the tripDate is after the thisStreakStartDate, keep going
                } else {
                    // there was no trip on thisStreakStartDate. thisStreak is over,
                    // so update longestStreak and then go back to the prior day
                    // to keep looking for a longer streak
                    if (thisStreakLength > longestStreakFoundYetLength) {
                        longestStreakFoundYetLength = thisStreakLength
                        longestStreakFoundYetStartDate = thisStreakStartDate
                    }
                    
                    thisStreakLength = 0
                    thisStreakStartDate = thisStreakStartDate.daysFrom(-1)
                }
            }
            
            self.longestStreakLength = NSNumber(integer: longestStreakFoundYetLength)
            self.longestStreakStartDate = longestStreakFoundYetStartDate
            
            CoreDataManager.sharedManager.saveContext()
        }
        
        guard let currentStreakLength = self.currentStreakLength, currentStreakDate = self.currentStreakStartDate else {
            // if it isn't currently set, calculate the current streak. this should only happen
            // if the user is upgrading from a version that didnt store it
            var count = 0
            var currentDate = NSDate()
            for trip in Trip.allBikeTrips() {
                let tripDate = (trip as! Trip).creationDate
                if (tripDate.isEqualToDay(currentDate)) {
                    currentDate = currentDate.daysFrom(-1)
                    count += 1
                } else if (tripDate.compare(currentDate) == NSComparisonResult.OrderedDescending) {
                    // if the tripDate is after the currentDate, keep going
                } else if (currentDate.isEqualToDay(NSDate())) {
                    // if the trip wasn't today but there was a trip yesterday,
                    // they could still take a trip today so the streak is still valid
                    // even though today doesn't count
                    if (tripDate.isEqualToDay(currentDate.daysFrom(-1))) {
                        currentDate = currentDate.daysFrom(-1)
                        count += 1
                    }
                } else {
                    break
                }
            }
            self.currentStreakLength = NSNumber(integer: count)
            CoreDataManager.sharedManager.saveContext()
            return
        }
        
        if (currentStreakDate.daysFrom(currentStreakLength.integerValue).isToday()) {
            // if the streak counts up to today, the count is current
        } else if (currentStreakDate.daysFrom(currentStreakLength.integerValue + 1).isToday()) {
            // if the streak counts up to yesterday, see if we have a ride today
            if (Trip.bikeTripsToday() != nil) {
                self.currentStreakLength = NSNumber(int: currentStreakLength.integerValue + 1)
                if (self.longestStreakLength == nil || currentStreakLength.integerValue > self.longestStreakLength!.integerValue) {
                    // if this is our new longest streak, update it
                    self.longestStreakLength = self.currentStreakLength
                    self.longestStreakStartDate = self.currentStreakStartDate
                }
            }
        } else {
            if (Trip.bikeTripsToday() != nil) {
                // the last streak expired but it is time to start a new one
                self.currentStreakLength = NSNumber(int: currentStreakLength.integerValue + 1)
                self.currentStreakStartDate = NSDate()
            } else {
                // no streak
                self.currentStreakLength = NSNumber(int: 0)
            }
        }
        
        CoreDataManager.sharedManager.saveContext()
    }
}
