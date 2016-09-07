//
//  Meters.swift
//  Ride
//
//  Created by William Henderson on 4/19/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

typealias Meters = Float

extension Float {
    var distanceString: String {
        get {
            let METERS_CUTOFF: Float = 400.0
            let FEET_CUTOFF: Float = 1056.0
            
            let format:String
            if (NSLocale.isMetric()) {
                if (self < METERS_CUTOFF) {
                    format = "\(self.stringWithDecimals(0)) meters"
                } else {
                    if NSLocale.isGB() {
                        format = "\(self.miles.stringWithDecimals(1)) miles";
                    } else {
                        format = "\(self.kilometers.stringWithDecimals(1)) km";
                    }
                }
            } else { // assume Imperial / U.S.
                if (feet < FEET_CUTOFF) {
                    format = "\(self.feet.stringWithDecimals(0)) feet";
                } else {
                    format = "\(self.miles.stringWithDecimals(1)) miles";
                }
            }
            return format
        }
    }
    
    var feet: Float {
        get {
            let METERS_TO_FEET: Float = 3.2808399
            return self * METERS_TO_FEET
        }
    }
    
    var miles: Float {
        get {
            let MILES_IN_METERS: Float =  0.000621371
            return self * MILES_IN_METERS
        }
    }

    var kilometers: Float {
        get {
            return self / 1000
        }
    }
    
    private func stringWithDecimals(decimals:Int) -> String {
        return String(format: "%.\(decimals)f", self)
    }
}

extension NSLocale {
    class func isMetric() -> Bool {
        let locale = NSLocale.currentLocale()
        return locale.objectForKey(NSLocaleUsesMetricSystem) as! Bool
    }
    
    class func isGB()-> Bool {
        if let countryString = NSLocale.currentLocale().objectForKey(NSLocaleCountryCode) as? String {
            return countryString == "GB"
        }
        
        return false
    }
}
