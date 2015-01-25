//
//  Activity.swift
//  Ride
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreMotion
import MapKit

class Activity : NSManagedObject {    
    @NSManaged var confidence : NSNumber
    @NSManaged var startDate : NSDate
    @NSManaged var trip : Trip?    
    
    @NSManaged var automotive : Bool
    @NSManaged var cycling : Bool
    @NSManaged var running : Bool
    @NSManaged var stationary : Bool
    @NSManaged var walking : Bool
    @NSManaged var unknown : Bool

    convenience init(activity: CMMotionActivity, trip: Trip) {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Activity", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        
        self.confidence = NSNumber(integer: activity.confidence.rawValue)
        
        self.automotive = activity.automotive
        self.cycling = activity.cycling
        self.running = activity.running
        self.stationary = activity.stationary
        self.unknown = activity.unknown
        
        self.startDate = activity.startDate
    }
    
    override func willSave() {
        if (self.trip != nil) {
            self.trip!.self.syncEventually()
        }
        
        super.willSave()
    }
    
}