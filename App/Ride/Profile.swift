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
    @NSManaged var uuid : String?
    @NSManaged var currentStreakStartDate : NSDate!
    @NSManaged var currentStreakLength : NSNumber!
    @NSManaged var longestStreakStartDate : NSDate!
    @NSManaged var longestStreakLength : NSNumber!

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
            
            if (results!.count == 0 || (results!.first as! Profile).uuid == nil) {
                let context = CoreDataManager.sharedManager.currentManagedObjectContext()
                Static.profile = Profile(entity: NSEntityDescription.entityForName("Profile", inManagedObjectContext: context)!, insertIntoManagedObjectContext:context)
                Static.profile.uuid = NSUUID().UUIDString
                CoreDataManager.sharedManager.saveContext()
            } else {
                Static.profile = (results!.first as! Profile)
            }
        }
        
        return Static.profile
    }
    
    var currentStreakJewel: String {
        return self.jewelForLength(self.currentStreakLength.integerValue)
    }
    
    var longestStreakJewel: String {
        return self.jewelForLength(self.longestStreakLength.integerValue)
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
                    thisStreakLength++
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
        
        if (self.currentStreakLength == nil || self.currentStreakStartDate == nil) {
            // if it isn't currently set, calculate the current streak. this should only happen
            // if the user is upgrading from a version that didnt store it
            var count = 0
            var currentDate = NSDate()
            for trip in Trip.allBikeTrips() {
                let tripDate = (trip as! Trip).creationDate
                if (tripDate.isEqualToDay(currentDate)) {
                    currentDate = currentDate.daysFrom(-1)
                    count++
                } else if (tripDate.compare(currentDate) == NSComparisonResult.OrderedDescending) {
                    // if the tripDate is after the currentDate, keep going
                } else if (currentDate.isEqualToDay(NSDate())) {
                    // if the trip wasn't today but there was a trip yesterday,
                    // they could still take a trip today so the streak is still valid
                    // even though today doesn't count
                    if (tripDate.isEqualToDay(currentDate.daysFrom(-1))) {
                        currentDate = currentDate.daysFrom(-1)
                        count++
                    }
                } else {
                    break
                }
            }
            self.currentStreakLength = NSNumber(integer: count)
        } else if (self.currentStreakStartDate.daysFrom(self.currentStreakLength.integerValue).isToday()) {
            // if the streak counts up to today, the count is current
        } else if (self.currentStreakStartDate.daysFrom(self.currentStreakLength.integerValue + 1).isToday()) {
            // if the streak counts up to yesterday, see if we have a ride today
            if (Trip.bikeTripsToday() != nil) {
                self.currentStreakLength = NSNumber(int: self.currentStreakLength.integerValue + 1)
                if (self.currentStreakLength.integerValue > self.longestStreakLength.integerValue) {
                    // if this is our new longest streak, update it
                    self.longestStreakLength = self.currentStreakLength
                    self.longestStreakStartDate = self.currentStreakStartDate
                }
            }
        } else {
            if (Trip.bikeTripsToday() != nil) {
                // the last streak expired but it is time to start a new one
                self.currentStreakLength = NSNumber(int: self.currentStreakLength.integerValue + 1)
                self.currentStreakStartDate = NSDate()
            } else {
                // no streak
                self.currentStreakLength = NSNumber(int: 0)
            }
        }
        
        CoreDataManager.sharedManager.saveContext()
    }
}
