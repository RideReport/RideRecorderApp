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
    
    // aproximates the number of seconds from referrence date to device restart time. There will be error from the time it takes to execute the statement
    static let timeIntervalFromReferenceDateToRestart = NSDate.timeIntervalSinceReferenceDate() - NSProcessInfo().systemUptime

    convenience init(deviceMotion: CMDeviceMotion, trip: Trip) {
        self.init(deviceMotion: deviceMotion)
        
        self.trip = trip
    }
    
    convenience init(deviceMotion: CMDeviceMotion, prototrip: Prototrip) {
        self.init(deviceMotion: deviceMotion)
        
        self.prototrip = prototrip
    }
    
    convenience init(deviceMotion: CMDeviceMotion) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("DeviceMotion", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.date =  NSDate(timeIntervalSinceReferenceDate: DeviceMotion.timeIntervalFromReferenceDateToRestart + deviceMotion.timestamp)
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