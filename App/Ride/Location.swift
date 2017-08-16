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

public class  Location: NSManagedObject {
    convenience init(location: CLLocation, trip: Trip) {
        self.init(location: location)
        
        self.trip = trip
    }
    
    class var minimumMovingSpeed: CLLocationSpeed {
        return 0.5
    }
    
    
    class var acceptableLocationAccuracy:CLLocationAccuracy {
        return kCLLocationAccuracyNearestTenMeters * 3
    }

    convenience init(copyingLocation location: Location) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        self.course = location.course
        self.horizontalAccuracy = location.horizontalAccuracy
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.speed = location.speed
        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy
        self.date = location.date
    }
    
    convenience init(location: CLLocation) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        self.course = location.course
        self.horizontalAccuracy = location.horizontalAccuracy
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.speed = location.speed
        self.altitude = location.altitude
        self.verticalAccuracy = location.verticalAccuracy
        self.date = location.timestamp
    }
    
    convenience init(trip: Trip) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        self.trip = trip
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
            results = try CoreDataManager.shared.currentManagedObjectContext().fetch(fetchedRequest)
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
            "date": self.date.JSONString(),
            "horizontalAccuracy": self.horizontalAccuracy,
            "speed": self.speed,
            "longitude": self.longitude,
            "latitude": self.latitude,
            "isGeofencedLocation": self.isInferredLocation
        ]
        locDict["course"] = course
        locDict["altitude"] = altitude
        locDict["verticalAccuracy"] = verticalAccuracy
        
        return locDict
    }
    
    func coordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(self.latitude, self.longitude)
    }
    
    func mapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: self.coordinate(), addressDictionary: nil)
        return MKMapItem(placemark: placemark)
    }
    
    func clLocation() -> CLLocation {
        return CLLocation(coordinate: CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude), altitude: self.altitude, horizontalAccuracy: self.horizontalAccuracy, verticalAccuracy: self.verticalAccuracy, course: self.course, speed: self.speed, timestamp: self.date)
    }
}
