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
        let region = MKCoordinateRegion(center: self, latitudinalMeters: latitudinalMeters, longitudinalMeters: longitudinalMeters)
        return CLLocationCoordinate2D(latitude: latitude + region.span.latitudeDelta, longitude: longitude + region.span.longitudeDelta)
    }
}

public class GpxLocationGenerator {
    public class func generate(distanceInterval: Double, count: Int, startingCoordinate: CLLocationCoordinate2D, startingDate: Date)->[CLLocation] {
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
    
    public class func generate(locations: [CLLocation], fromOffsetDate startingDate: Date)->[CLLocation] {
        var locs: [CLLocation] = []
        let startLoc = locations.first!
        locs.append(contentsOf: GpxLocationGenerator.generate(distanceInterval: 0.1, count: 1, startingCoordinate: startLoc.coordinate, startingDate: startingDate)) // append a few stopped locs on the end to make sure the state machine initializes properly
        
        let timeOffset = startingDate.timeIntervalSince(startLoc.timestamp) + 1 // one second offset for the initial location
        var endDate: Date!
        
        for location in locations {
            endDate = location.timestamp.addingTimeInterval(timeOffset)
            locs.append(CLLocation(coordinate: location.coordinate, altitude: location.altitude, horizontalAccuracy: location.horizontalAccuracy, verticalAccuracy: location.verticalAccuracy, course: location.course, speed: location.speed, timestamp: endDate))
        }
        
        return locs
    }
}
