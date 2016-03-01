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

class DeviceMotion : NSManagedObject {
    @NSManaged var trip : Trip?
    @NSManaged var prototrip : Prototrip?
    
    @NSManaged var date : NSDate
    @NSManaged var gravityX : NSNumber
    @NSManaged var gravityY : NSNumber
    @NSManaged var gravityZ : NSNumber
    @NSManaged var userAccelerationX : NSNumber
    @NSManaged var userAccelerationY : NSNumber
    @NSManaged var userAccelerationZ : NSNumber
    
    convenience init(deviceMotion: CMDeviceMotion, referenceBootDate: NSDate) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("DeviceMotion", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.date =  NSDate(timeInterval: deviceMotion.timestamp, sinceDate: referenceBootDate)
        self.gravityX = deviceMotion.gravity.x
        self.gravityY = deviceMotion.gravity.y
        self.gravityZ = deviceMotion.gravity.z
        self.userAccelerationX = deviceMotion.userAcceleration.x
        self.userAccelerationY = deviceMotion.userAcceleration.y
        self.userAccelerationZ = deviceMotion.userAcceleration.z
    }
    
    func jsonDictionary() -> [String: AnyObject] {
        return [
            "date": self.date.MillisecondJSONString(),
            "gravityX": self.gravityX,
            "gravityY": self.gravityY,
            "gravityZ": self.gravityZ,
            "userAccelerationX": self.userAccelerationX,
            "userAccelerationY": self.userAccelerationY,
            "userAccelerationZ": self.userAccelerationZ
        ]
    }
}