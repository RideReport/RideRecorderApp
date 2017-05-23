//
//  GpxLocationGenerator.swift
//  Ride
//
//  Created by William Henderson on 5/18/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import MapKit

extension CLLocationCoordinate2D {
    public func transform(using latitudinalMeters: CLLocationDistance, longitudinalMeters: CLLocationDistance) -> CLLocationCoordinate2D {
        let region = MKCoordinateRegionMakeWithDistance(self, latitudinalMeters, longitudinalMeters)
        return CLLocationCoordinate2D(latitude: latitude + region.span.latitudeDelta, longitude: longitude + region.span.longitudeDelta)
    }
}

class GpxLocationGenerator {
    class func generate(distanceInterval: Double, count: Int, startingCoordinate: CLLocationCoordinate2D, startingDate: Date)->[CLLocation] {
        var locs: [CLLocation] = []
        var coord = CLLocationCoordinate2D(latitude: startingCoordinate.latitude, longitude: startingCoordinate.longitude)
        var date = startingDate
        
        for _ in 1...count {
            locs.append(CLLocation(coordinate: coord, altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, course: 0, speed: distanceInterval, timestamp: date))
            coord = coord.transform(using: distanceInterval, longitudinalMeters: 0)
            date = date.secondsFrom(1)
        }
        
        return locs
    }
    
    class func generate(trip: Trip, fromOffsetDate startingDate: Date)->[CLLocation] {
        var locs: [CLLocation] = []
        locs.append(contentsOf: GpxLocationGenerator.generate(distanceInterval: 0.1, count: 1, startingCoordinate: trip.bestStartLocation()!.coordinate(), startingDate: startingDate)) // append a stopped locs on the end to make sure the state machine initializes properly
        
        let timeOffset = startingDate.timeIntervalSince(trip.startDate) + 1 // one second offset for the initial location
        var endDate: Date!
        
        for loc in trip.locations {
            if let location = loc as? Location, let date = location.date, !location.isGeofencedLocation {
                endDate = date.addingTimeInterval(timeOffset)
                locs.append(CLLocation(coordinate: location.coordinate(), altitude: location.altitude?.doubleValue ?? 0, horizontalAccuracy: location.horizontalAccuracy?.doubleValue ?? 0, verticalAccuracy: location.verticalAccuracy?.doubleValue ?? 0, course: location.course?.doubleValue ?? 0, speed: location.speed?.doubleValue ?? 0, timestamp: endDate))
            }
        }
        
        locs.append(contentsOf: GpxLocationGenerator.generate(distanceInterval: 0.1, count: 80, startingCoordinate: trip.bestEndLocation()!.coordinate(), startingDate: endDate)) // append a minute of stopped locs on the end to make sure the state machine isn't starved before it stops the trip
        
        return locs
    }
}
