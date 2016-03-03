//
//  DeviceMotionsSample.swift
//  Ride
//
//  Created by William Henderson on 3/1/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreMotion
import MapKit

class DeviceMotionsSample : NSManagedObject {
    @NSManaged var deviceMotions : NSOrderedSet!
    @NSManaged var prototrip : Prototrip?
    @NSManaged var trip : Trip?

    private var referenceBootDate: NSDate!

    convenience init(prototrip: Prototrip) {
        self.init()
        
        self.prototrip = prototrip
    }
    
    convenience init(trip: Trip) {
        self.init()
        
        self.trip = trip
    }
    
    convenience init() {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("DeviceMotionsSample", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
    }
    
    func addDeviceMotion(deviceMotion: CMDeviceMotion) {
        if self.referenceBootDate == nil {
            self.referenceBootDate = NSDate(timeIntervalSinceNow: -deviceMotion.timestamp)
        }
        

        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let dm = DeviceMotion.init(entity: NSEntityDescription.entityForName("DeviceMotion", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        dm.date =  NSDate(timeInterval: deviceMotion.timestamp, sinceDate: self.referenceBootDate)
        dm.gravityX = deviceMotion.gravity.x
        dm.gravityY = deviceMotion.gravity.y
        dm.gravityZ = deviceMotion.gravity.z
        dm.userAccelerationX = deviceMotion.userAcceleration.x
        dm.userAccelerationY = deviceMotion.userAcceleration.y
        dm.userAccelerationZ = deviceMotion.userAcceleration.z
        dm.deviceMotionsSample = self
    }
    
    func jsonDictionary() -> [AnyObject] {
        var dmArray : [AnyObject] = []
        for dm in self.deviceMotions {
            dmArray.append((dm as! DeviceMotion).jsonDictionary())
        }
        
        return dmArray
    }
}