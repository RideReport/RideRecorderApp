//
//  ActivityType.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

/**
 Location Source
 
 - unknown: Default value.
 - activeGPS: Location received when active, (possibly) high-accuracy tracking is enabled.
 - passive: Location received when passive, (possibly) low-accuracy tracking is enabled.
 - geofence: Center location of a geofence created when the geofence event fires.
 - visitArrival: Location created from a Core Location Visit Arrival event. Possibly used as a means of establishing route's end location. Timestamp is estimated but could be used for determining a route's end time.
 - visitDeparture: Location created from a Core Location Visit Departure event. Used as a means of establishing a route's start location. Timestamp is estimated but could be used for determining a route's start time.
 - lastRouteArrival: Location copied from the end of the last route. Used as an alternative means of establishing start location. Timestamp should always be ignored.
 */

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
