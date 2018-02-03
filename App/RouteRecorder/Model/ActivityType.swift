//
//  ActivityType.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@objc public enum ActivityType : Int16, CustomStringConvertible {
    case unknown = 0
    case running
    case cycling
    case automotive
    case walking
    case bus
    case rail
    case stationary
    case aviation
    case maritime
    case motorcycle
    case tram
    case helicopter
    case skateboarding
    case skiing
    case wheelchair
    case snowboarding // be sure to update userSelectableValues if changing this
    case other = 999
    
    public static func ~= (left: ActivityType, right: ActivityType) -> Bool {
        if left.isMotorizedMode && right.isMotorizedMode {
            return true
        }
        if left.isPedestrianMode && right.isPedestrianMode {
            return true
        }
        
        return (left == right)
    }
    
    // userVisibleValues does not include stationary or unknown
    public static var userSelectableValues: [ActivityType] = [.running, .cycling, .automotive, .walking, .bus, .rail, .aviation, .maritime, .motorcycle, .tram, .helicopter, .skateboarding, .skiing, .snowboarding, .wheelchair, .other]
    
    public var isMotorizedMode: Bool {
        get {
            return (self == .automotive || self == .bus || self == .rail)
        }
    }
    
    public var isPedestrianMode: Bool {
        get {
            return (self == .walking || self == .running)
        }
    }
    
    public var description: String {
        return emoji
    }
    
    public var emoji: String {
        get {
            var tripTypeString = ""
            switch self {
            case .unknown:
                tripTypeString = "❗️"
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
            case .maritime:
                tripTypeString = "🛳"
            case .motorcycle:
                tripTypeString = "🏍"
            case .tram:
                tripTypeString = "🚡"
            case .helicopter:
                tripTypeString = "🚁"
            case .skateboarding:
                tripTypeString = "👟"
            case .skiing:
                tripTypeString = "⛷"
            case .snowboarding:
                tripTypeString = "🏂"
            case .wheelchair:
                tripTypeString = "♿️"
            case .other:
                tripTypeString = "❓"
            }
            
            return tripTypeString
        }
    }
    
    public var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
    
    public var noun: String {
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
            case .maritime:
                tripTypeString = "Boating"
            case .motorcycle:
                tripTypeString = "Motorcycling"
            case .tram:
                tripTypeString = "Tram Ride"
            case .helicopter:
                tripTypeString = "Helicopter Ride"
            case .skateboarding:
                tripTypeString = "Skateboarding"
            case .skiing:
                tripTypeString = "Skiing"
            case .snowboarding:
                tripTypeString = "Snowboarding"
            case .wheelchair:
                tripTypeString = "By Wheelchair"
            case .other:
                tripTypeString = "Other"
            }
            
            return tripTypeString
        }
    }
}
