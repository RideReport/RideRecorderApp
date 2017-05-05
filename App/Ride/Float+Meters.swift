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
    func distanceString(suppressFractionalUnits: Bool = false)->String {
        let (distanceString, longUnits, _) = self.distanceStrings(suppressFractionalUnits: suppressFractionalUnits)
        
        return distanceString + " " + longUnits
    }
    
    func distanceStrings(suppressFractionalUnits: Bool = false)-> (distance: String, unitsLong: String, unitsShort: String) {
        let METERS_CUTOFF: Float = 400.0
        let FEET_CUTOFF: Float = 1056.0
        
        if (Locale.isMetric()) {
            if (self < METERS_CUTOFF) {
                let metersString = self.stringWithDecimals(0)

                return ("\(metersString)", metersString == "1" ? "meter" : "meters", "m")
            } else {
                if Locale.isGB() {
                    var numberOfDecimals = 1
                    if suppressFractionalUnits || self.miles > 10 {
                        numberOfDecimals = 0
                    }
                    let milesString = self.miles.stringWithDecimals(numberOfDecimals)
                    return ("\(milesString)", milesString == "1" ? "mile" : "miles", "mi")
                } else {
                    var numberOfDecimals = 1
                    if suppressFractionalUnits || self.kilometers > 10 {
                        numberOfDecimals = 0
                    }
                    return ("\(self.kilometers.stringWithDecimals(numberOfDecimals))", "km", "k")
                }
            }
        } else { // assume Imperial / U.S.
            if (feet < FEET_CUTOFF) {
                let feetString = self.feet.stringWithDecimals(0)
                return ("\(feetString)", feetString == "1" ? "foot" : "feet", "ft")
            } else {
                var numberOfDecimals = 1
                if suppressFractionalUnits || self.miles > 10 {
                    numberOfDecimals = 0
                }
                let milesString = self.miles.stringWithDecimals(numberOfDecimals)
                return ("\(milesString)", milesString == "1" ? "mile" : "miles", "mi")
            }
        }
    }
    
    var localizedMajorUnit: Float {
        get {
            if (Locale.isMetric()) {
                if Locale.isGB() {
                    return self.miles
                } else {
                    return self.kilometers
                }
            } else { // assume Imperial / U.S.
                return self.miles
            }
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
    
    private func stringWithDecimals(_ decimals:Int) -> String {
        let integerFormatter = NumberFormatter()
        integerFormatter.locale = Locale.current
        integerFormatter.numberStyle = .decimal
        integerFormatter.usesGroupingSeparator = true
        integerFormatter.maximumFractionDigits = decimals
        return integerFormatter.string(for: self) ?? "0"
    }
}
