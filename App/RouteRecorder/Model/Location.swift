//
//  Location.swift
//  Ride Report
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation
import CoreMotion
import MapKit
import SwiftyJSON
import CocoaLumberjack

public class  Location: NSManagedObject {
    var source : LocationSource {
        get {
            return LocationSource(rawValue: self.sourceInteger) ?? LocationSource.unknown
        }
        set {
            self.sourceInteger = newValue.rawValue
        }
    }
    
    class var minimumMovingSpeed: CLLocationSpeed {
        return 0.2
    }
    
    
    class var acceptableLocationAccuracy:CLLocationAccuracy {
        return kCLLocationAccuracyNearestTenMeters * 3
    }
    
    public convenience init?(JSON locationJson: JSON) {
        if let dateString = locationJson["date"].string, let date = Date.dateFromJSONString(dateString),
            let latitude = locationJson["latitude"].double,
            let longitude = locationJson["longitude"].double,
            let course = locationJson["course"].double,
            let speed = locationJson["speed"].double,
            let horizontalAccuracy = locationJson["horizontalAccuracy"].double {
                let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
                self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
                self.date = date
                self.latitude = latitude
                self.longitude = longitude
                self.course = course
                self.speed = speed
                self.horizontalAccuracy = horizontalAccuracy
                if let sourceInt = locationJson["source"].int16 {
                    self.source = LocationSource(rawValue: sourceInt) ?? LocationSource.unknown
                } else if let isGeofencedLocation = locationJson["isGeofencedLocation"].bool {
                    // support for legacy location data
                    if isGeofencedLocation {
                        self.source = .geofence
                    } else {
                        self.source = .activeGPS
                    }
                }
        } else {
            DDLogWarn("Error parsing location dictionary when fetched route data!")
            
            return nil
        }
    }
    
    
    convenience init(visit:CLVisit, isArriving: Bool) {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        self.course = -1.0
        self.horizontalAccuracy = visit.horizontalAccuracy
        self.latitude = visit.coordinate.latitude
        self.longitude = visit.coordinate.longitude
        self.speed = -1.0
        
        if isArriving {
            self.source = .visitArrival
            self.date = visit.arrivalDate
        } else {
            self.source = .visitDeparture
            self.date = visit.departureDate
        }
    }

    convenience init(lastArrivalLocation location: Location) {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        self.course = location.course
        self.horizontalAccuracy = location.horizontalAccuracy
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.speed = location.speed
        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy
        self.date = location.date
        self.source = .lastRouteArrival
    }
    
    convenience init(recordedLocation location: CLLocation, isActiveGPS: Bool, route: Route) {
        self.init(recordedLocation: location, isActiveGPS: isActiveGPS)
        
        self.route = route
    }
    
    convenience init(recordedLocation location: CLLocation, isActiveGPS: Bool) {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        self.course = location.course
        self.horizontalAccuracy = location.horizontalAccuracy
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.speed = location.speed
        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy
        self.date = location.timestamp
        self.source = isActiveGPS ? .activeGPS : .passive
    }
    
    class func locationsInCircle(_ circle:MKCircle) -> [AnyObject] {
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        
        let searchRadius : Double = circle.radius * 1.1 // pad it a bit to allow for error
        let radiusOfEarth : Double = 6371009
        let meanLatitidue = circle.coordinate.latitude * Double.pi / 180
        let radiusLatitude = radiusOfEarth / searchRadius * 180 / Double.pi
        let radiusLongitude = radiusOfEarth / (searchRadius * cos(meanLatitidue)) * 180 / Double.pi
        let minLatitude = circle.coordinate.latitude - radiusLatitude
        let maxLatitude = circle.coordinate.latitude + radiusLatitude
        let minLongitude = circle.coordinate.longitude - radiusLongitude
        let maxLongitude = circle.coordinate.longitude + radiusLongitude

        fetchedRequest.predicate = NSPredicate(format: "(%f <= longitude) AND (longitude <= %f) AND (%f <= latitude) AND (latitude <= %f)", minLongitude, maxLongitude, minLatitude, maxLatitude)
        
        fetchedRequest.returnsObjectsAsFaults = false
        
        let results: [AnyObject]?
        do {
            results = try RouteRecorderDatabaseManager.shared.currentManagedObjectContext().fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error finding locations for circle: %@", error as NSError))
            results = nil
        }
        
        if (results!.count == 0) {
            return []
        }
        
        var filteredResults : [AnyObject] = []
        let centerLocation = CLLocation(latitude: circle.coordinate.latitude, longitude: circle.coordinate.longitude)
        for loc in results! {
            let aLocation = CLLocation(latitude: (loc as! Location).latitude, longitude: (loc as! Location).longitude)
            let distanceFromCenter = centerLocation.distance(from: aLocation)
            if (distanceFromCenter <= circle.radius) {
                filteredResults.append(loc)
            }
        }

        return filteredResults
    }
    
    func jsonDictionary() -> [String: Any] {
        var locDict: [String: Any] = [
            "date": self.date.JSONString(includingMilliseconds: true),
            "horizontalAccuracy": self.horizontalAccuracy,
            "speed": self.speed,
            "longitude": self.longitude,
            "latitude": self.latitude,
            "source": self.source.numberValue
        ]
        locDict["course"] = course
        locDict["altitude"] = altitude
        locDict["verticalAccuracy"] = verticalAccuracy
        
        return locDict
    }
    
    public func timeIntervalSinceLocation(location: Location)->TimeInterval {
        return self.date.timeIntervalSinceReferenceDate - location.date.timeIntervalSinceReferenceDate
    }
    
    override public var debugDescription: String {
        return String(format:"%@ %0.5f, %0.5f %0.2f m/s", self.date.debugDescription, self.longitude, self.latitude, self.speed)
    }
    
    public func coordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(self.latitude, self.longitude)
    }
    
    func mapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: self.coordinate(), addressDictionary: nil)
        return MKMapItem(placemark: placemark)
    }
    
    public func clLocation() -> CLLocation {
        return CLLocation(coordinate: CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude), altitude: self.altitude, horizontalAccuracy: self.horizontalAccuracy, verticalAccuracy: self.verticalAccuracy, course: self.course, speed: self.speed, timestamp: self.date)
    }
}
