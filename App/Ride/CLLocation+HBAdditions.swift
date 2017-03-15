//
//  CLLocation+HBAdditions.swift
//  Ride Report
//
//  Created by William Henderson on 3/2/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import CoreLocation

extension CLLocation {
    func calculatedSpeedFromLocation(_ location: CLLocation) -> CLLocationSpeed {
        let distance = self.distance(from: location)
        let time = abs(location.timestamp.timeIntervalSince(self.timestamp))
        if (time == 0) {
            return -1.0
        }
        
        return distance/time
    }
}

extension CLLocationSpeed {
    var string: String {
        get {            
            let format:String
            if (Locale.isMetric()) {
                if (self.kilometersPerHour < 1) {
                    format = "\(self.stringWithDecimals(0)) mps"
                } else {
                    if Locale.isGB() {
                        format = "\(self.milesPerHour.stringWithDecimals(1)) mph";
                    } else {
                        format = "\(self.kilometersPerHour.stringWithDecimals(1)) kph";
                    }
                }
            } else {
                if (self.milesPerHour < 1) {
                    format = "\(self.feetPerSecond.stringWithDecimals(0)) fps";
                } else {
                    format = "\(self.milesPerHour.stringWithDecimals(1)) mph";
                }
            }
            return format
        }
    }
    
    var milesPerHour: Double {
        get {
            return self * 2.23693629
        }
    }
    
    var feetPerSecond: Double {
        get {
            return self * 3.2808399
        }
    }
    
    var kilometersPerHour: Double {
        get {
            return self * 3.6
        }
    }
    
    private func stringWithDecimals(_ decimals:Int) -> String {
        return String(format: "%.\(decimals)f", self)
    }
}
