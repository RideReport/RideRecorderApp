//
//  Activity.swift
//  Ride Report
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
    @NSManaged var prototrip : Prototrip?
    
    @NSManaged var automotive : Bool
    @NSManaged var cycling : Bool
    @NSManaged var running : Bool
    @NSManaged var stationary : Bool
    @NSManaged var walking : Bool
    @NSManaged var unknown : Bool

    convenience init(activity: CMMotionActivity, trip: Trip) {
        self.init(activity: activity)
        
        self.trip = trip
    }
    
    convenience init(activity: CMMotionActivity, prototrip: Prototrip) {
        self.init(activity: activity)
        
        self.prototrip = prototrip
    }
    
    convenience init(activity: CMMotionActivity) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Activity", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.confidence = NSNumber(integer: activity.confidence.rawValue + 1)
        
        self.automotive = activity.automotive
        self.walking = activity.walking
        self.cycling = activity.cycling
        self.running = activity.running
        self.stationary = activity.stationary
        self.unknown = activity.unknown
        
        self.startDate = activity.startDate
    }
}