//
//  ActivityType.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@objc enum ActivityType : Int16, CustomStringConvertible {
    case unknown = 0
    case running
    case cycling
    case automotive
    case walking
    case bus
    case rail
    case stationary
    case aviation
    
    static var count: Int { return Int(ActivityType.stationary.rawValue) + 1}
    
    var isMotorizedMode: Bool {
        get {
            return (self == .automotive || self == .bus || self == .rail)
        }
    }
    
    var description: String {
        return emoji
    }
    
    var emoji: String {
        get {
            var tripTypeString = ""
            switch self {
            case .unknown:
                tripTypeString = "❓"
            case .running:
                tripTypeString = "🏃"
            case .cycling:
                tripTypeString = "🚲"
            case .automotive:
                tripTypeString = "🚗"
            case .walking:
                tripTypeString = "🚶"
            case .bus:
                tripTypeString = "🚌"
            case .rail:
                tripTypeString = "🚈"
            case .stationary:
                tripTypeString = "💤"
            case .aviation:
                tripTypeString = "✈️"
            }
            
            return tripTypeString
        }
    }
    
    var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
    
    var noun: String {
        get {
            var tripTypeString = ""
            switch self {
            case .unknown:
                tripTypeString = "Unknown"
            case .running:
                tripTypeString = "Run"
            case .cycling:
                tripTypeString = "Bike Ride"
            case .automotive:
                tripTypeString = "Drive"
            case .walking:
                tripTypeString = "Walk"
            case .bus:
                tripTypeString = "Bus Ride"
            case .rail:
                tripTypeString = "Train Ride"
            case .stationary:
                tripTypeString = "Sitting"
            case .aviation:
                tripTypeString = "Flight"
            }
            
            return tripTypeString
        }
    }
}
