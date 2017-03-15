//
//  SensorData
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreMotion
import MapKit

class SensorData : NSManagedObject {
    @NSManaged var date : Date
    @NSManaged var x : NSNumber
    @NSManaged var y : NSNumber
    @NSManaged var z : NSNumber
    
    func jsonDictionary() -> [String: Any] {
        return [
            "date": self.date.MillisecondJSONString(),
            "x": self.x,
            "y": self.y,
            "z": self.z,
        ]
    }
}

class AccelerometerAcceleration : SensorData {
    @NSManaged var sensorDataCollection : SensorDataCollection?
}

class DeviceMotionAcceleration : SensorData {
    @NSManaged var sensorDataCollection : SensorDataCollection?
}

class DeviceMotionRotationRate : SensorData {
    @NSManaged var sensorDataCollection : SensorDataCollection?
}

class GyroscopeRotationRate : SensorData {
    @NSManaged var sensorDataCollection : SensorDataCollection?
}
