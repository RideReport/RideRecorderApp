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
        if self.currentStreakLength >= 100 {
            return "🏆"
        } else if self.currentStreakLength >= 50 {
            return "🏅"
        } else if self.currentStreakLength >= 25 {
            return "🚀"
        } else if self.currentStreakLength >= 14 {
            return "🔥"
        } else if self.currentStreakLength >= 10 {
            return "💙"
        } else if self.currentStreakLength >= 7 {
            return "💚"
        } else if self.currentStreakLength >= 5 {
            return "💛"
        } else if self.currentStreakLength >= 3 {
            return "💜"
        } else {
            return "❤️"
        }
    }
    
    func updateCurrentRideStreakLength() {
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
