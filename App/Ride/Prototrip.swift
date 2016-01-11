//
//  Prototrip.swift
//  Ride Report
//
//  Created by William Henderson on 1/8/16.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class Prototrip : NSManagedObject {

    @NSManaged var batteryAtStart : NSNumber!
    @NSManaged var activities : NSSet!
    @NSManaged var locations : NSOrderedSet!
    @NSManaged var creationDate : NSDate!
    
    convenience init() {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Prototrip", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = NSDate()
    }
    
    func firstNonGeofencedLocation() -> Location? {
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        
        for loc in self.locations.sortedArrayUsingDescriptors([sortDescriptor]) {
            if let location = loc as? Location where !location.isGeofencedLocation {
                return location
            }
        }
        return nil
    }
    
    func moveActivitiesAndLocationsToTrip(trip: Trip) {
        for loc in self.locations {
            let location = loc as! Location
            location.trip = trip
            location.prototrip = nil
        }
        
        for act in self.activities {
            let activity = act as! Activity
            activity.trip = trip
            activity.prototrip = nil
        }
    }
}