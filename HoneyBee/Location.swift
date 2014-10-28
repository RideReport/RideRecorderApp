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
    
    @NSManaged var activityType : Int16
    @NSManaged var confidence : Int16
    @NSManaged var course : Double
    @NSManaged var horizontalAccuracy : Double
    @NSManaged var latitude : Double
    @NSManaged var longitude : Double
    @NSManaged var speed : Double
    
    init(location: CLLocation, motionActivity: CMMotionActivity) {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        super.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.course = location.course
        self.horizontalAccuracy = location.horizontalAccuracy
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.speed = location.speed
        
        if (motionActivity.walking) {
            self.activityType = Location.ActivityType.Walking.rawValue
        } else if (motionActivity.running) {
            self.activityType = Location.ActivityType.Running.rawValue
        } else if (motionActivity.cycling) {
            self.activityType = Location.ActivityType.Cycling.rawValue
        } else if (motionActivity.automotive) {
            self.activityType = Location.ActivityType.Running.rawValue
        } else {
            self.activityType = Location.ActivityType.Unknown.rawValue
        }
        
        self.confidence = (Int16)(motionActivity.confidence.rawValue)
    }
    
    class func allLocations() -> [AnyObject]? {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Location")
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results
    }
    
    func coordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(self.latitude, self.longitude)
    }
}