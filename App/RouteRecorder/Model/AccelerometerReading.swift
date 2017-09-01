//
//  AccelerometerReading
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreMotion

public class AccelerometerReading : NSManagedObject {    
    public func jsonDictionary() -> [String: Any] {
        return [
            "date": self.date.MillisecondJSONString(),
            "x": self.x,
            "y": self.y,
            "z": self.z,
        ]
    }
    
    convenience init(accelerometerData: CMAccelerometerData) {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "AccelerometerReading", in: context)!, insertInto: context)
        
        self.x = accelerometerData.acceleration.x
        self.y = accelerometerData.acceleration.y
        self.z = accelerometerData.acceleration.z
    }
}
