//
//  Incident.swift
//  Ride
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class Incident : NSManagedObject {
    enum IncidentType : Int {
        case Unknown = 0
        case RoadHazard
        case UnsafeIntersection
        case BikeLaneEnds
        case UnsafeSpeeds
        case AggressiveMotorist
        case InsufficientParking
        case SuspectedBikeTheif
        
        static var count: Int { return IncidentType.SuspectedBikeTheif.rawValue + 1}
        
        var text: String {
            switch(self) {
            case Unknown:
                return "Other"
            case RoadHazard:
                return "Road Hazard"
            case UnsafeIntersection:
                return "Unsafe Intersection"
            case BikeLaneEnds:
                return "Bike Lane Ends"
            case UnsafeSpeeds:
                return "Unsafe Speeds"
            case AggressiveMotorist:
                return "Aggressive Motorist"
            case InsufficientParking:
                return "Insufficient Parking"
            case SuspectedBikeTheif:
                return "Suspected Stolen Bikes"
            }
        }
    }
    
    @NSManaged var uuid : String
    @NSManaged var body : String!
    @NSManaged var creationDate : NSDate!
    @NSManaged var type : NSNumber!
    
    @NSManaged var trip : Trip?
    @NSManaged var location : Location
    
    convenience init(location: Location, trip: Trip) {
        let context = CoreDataManager.sharedCoreDataManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Incident", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        self.location = location
        self.creationDate = NSDate()
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = NSDate()
        self.uuid = NSUUID().UUIDString
    }
}
