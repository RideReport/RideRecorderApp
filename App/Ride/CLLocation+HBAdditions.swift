//
//  CLLocation+HBAdditions.swift
//  Ride
//
//  Created by William Henderson on 3/2/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import CoreLocation

extension CLLocation {
    func calculatedSpeedFromLocation(location: CLLocation) -> CLLocationSpeed {
        let distance = self.distanceFromLocation(location)
        let time = abs(location.timestamp.timeIntervalSinceDate(self.timestamp))
        if (time == 0) {
            return -1.0
        }
        
        return distance/time
    }
}