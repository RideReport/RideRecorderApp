//
//  Location.swift
//  HoneyBee
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation
import CoreMotion

class Location : NSManagedObject {
    enum ActivityType : Int16 {
        case Walking = 0
        case Running
        case Cycling
        case Automotive
        case Unknown
    }
    
    @NSManaged var activityType : NSNumber
    @NSManaged var confidence : NSNumber
    @NSManaged var course : NSNumber
    @NSManaged var horizontalAccuracy : NSNumber
    @NSManaged var latitude : NSNumber
    @NSManaged var longitude : NSNumber
    @NSManaged var speed : NSNumber
    @NSManaged var trip : Trip
    
    convenience init(location: CLLocation, motionActivity: CMMotionActivity, trip: Trip) {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        
        self.course = NSNumber(double: location.course)
        self.horizontalAccuracy = NSNumber(double: location.horizontalAccuracy)
        self.latitude = NSNumber(double: location.coordinate.latitude)
        self.longitude = NSNumber(double: location.coordinate.longitude)
        self.speed = NSNumber(double: location.speed)
        
        if (motionActivity.walking) {
            self.activityType = NSNumber(short: Location.ActivityType.Walking.rawValue)
        } else if (motionActivity.running) {
            self.activityType = NSNumber(short: Location.ActivityType.Running.rawValue)
        } else if (motionActivity.cycling) {
            self.activityType = NSNumber(short: Location.ActivityType.Cycling.rawValue)
        } else if (motionActivity.automotive) {
            self.activityType = NSNumber(short: Location.ActivityType.Running.rawValue)
        } else {
            self.activityType = NSNumber(short: Location.ActivityType.Unknown.rawValue)
        }
        
        self.confidence = NSNumber(integer: motionActivity.confidence.rawValue)
    }
    
    func coordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(self.latitude.doubleValue, self.longitude.doubleValue)
    }
}