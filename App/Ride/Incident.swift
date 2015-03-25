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
    enum Type : Int16 {
        case Unknown = 0
    }
    
    @NSManaged var uuid : String
    @NSManaged var body : String!
    @NSManaged var creationDate : NSDate!
    @NSManaged var type : NSNumber!
    
    @NSManaged var trip : Trip?
    @NSManaged var location : Location?
    
    convenience init(location: Location, trip: Trip) {
        let context = CoreDataManager.sharedCoreDataManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Incident", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        self.location = location
        self.creationDate = NSDate()
    }
    
    var typeString : String {
        get {
            if self.type.shortValue == Type.Unknown.rawValue {
                return "Unknown"
            } else {
                return ""
            }
        }
    }
}
