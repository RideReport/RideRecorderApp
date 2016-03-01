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
    @NSManaged var deviceMotionsSample : DeviceMotionsSample?
    
    @NSManaged var date : NSDate
    @NSManaged var gravityX : NSNumber
    @NSManaged var gravityY : NSNumber
    @NSManaged var gravityZ : NSNumber
    @NSManaged var userAccelerationX : NSNumber
    @NSManaged var userAccelerationY : NSNumber
    @NSManaged var userAccelerationZ : NSNumber
    
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