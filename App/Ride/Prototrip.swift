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
    @NSManaged var activityType : NSNumber
    @NSManaged var batteryAtStart : NSNumber?
    @NSManaged var sensorDataCollections : NSOrderedSet!
    @NSManaged var locations : NSOrderedSet!
    @NSManaged var creationDate : Date?
    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Prototrip", in: context)!, insertInto: context)
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = Date()
    }
    
    func firstNonGeofencedLocation() -> Location? {
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        
        for loc in self.locations.sortedArray(using: [sortDescriptor]) {
            if let location = loc as? Location, !location.isGeofencedLocation {
                return location
            }
        }
        return nil
    }
    
    func moveSensorDataAndLocationsToTrip(_ trip: Trip) {
        for loc in self.locations {
            let location = loc as! Location
            location.trip = trip
            location.prototrip = nil
        }
        
        for c in self.sensorDataCollections {
            let collection = c as! SensorDataCollection
            collection.trip = trip
            collection.prototrip = nil
        }
    }
}
