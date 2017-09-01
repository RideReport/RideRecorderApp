//
//  ActivityType.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@objc enum LocationSource : Int16, CustomStringConvertible {
    case unknown = 0
    case activeGPS
    case passive
    case geofence
    case visitArrival
    case visitDeparture
    case lastRouteArrival
    
    static var inferredSources: [LocationSource] {
        return [.unknown, .geofence, .visitArrival, .visitDeparture, .lastRouteArrival]
    }
    
    var isInferred: Bool {
        return LocationSource.inferredSources.contains(self)
    }
    
    var description: String {
        get {
            var sourceString = ""
            switch self {
            case .activeGPS:
                sourceString = "Active GPS"
            case .passive:
                sourceString = "Passive"
            case .geofence:
                sourceString = "Geofence"
            case .visitArrival:
                sourceString = "Visit Arrival"
            case .visitDeparture:
                sourceString = "Visit Departure"
            case .lastRouteArrival:
                sourceString = "Last Route Arrival"
            case .unknown:
                sourceString = "Unknown"
            }
            
            return sourceString
        }
    }
    
    var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
}
