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

class Location : NSManagedObject {
    
    @NSManaged var altitude : NSNumber?
    @NSManaged var verticalAccuracy : NSNumber?
    @NSManaged var course : NSNumber?
    @NSManaged var horizontalAccuracy : NSNumber?
    @NSManaged var isSmoothedLocation : Bool
    @NSManaged var isGeofencedLocation : Bool
    @NSManaged var latitude : NSNumber?
    @NSManaged var longitude : NSNumber?
    @NSManaged var speed : NSNumber?
    @NSManaged var trip : Trip?
    @NSManaged var prototrip : Prototrip?
    @NSManaged var lastGeofencedLocationOfProfile : Profile?
    @NSManaged var simplifiedInTrip : Trip?
    @NSManaged var sensorDataCollection : SensorDataCollection?
    @NSManaged var incidents : NSOrderedSet!
    @NSManaged var date : Date?
    
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
    
    convenience init(location: CLLocation, prototrip: Prototrip) {
        self.init(location: location)
        
        self.prototrip = prototrip
    }
    
    convenience init(byCopyingLocation location: Location, prototrip: Prototrip) {
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
        self.isGeofencedLocation = location.isGeofencedLocation
        self.isSmoothedLocation = location.isSmoothedLocation
        
        self.prototrip = prototrip
    }
    
    convenience init(location: CLLocation, geofencedLocationOfProfile profile: Profile) {
        self.init(location: location)
        
        self.isGeofencedLocation = true
        self.lastGeofencedLocationOfProfile = profile
    }
    
    convenience init(location: CLLocation) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        self.course = NSNumber(value: location.course as Double)
        self.horizontalAccuracy = NSNumber(value: location.horizontalAccuracy as Double)
        self.latitude = NSNumber(value: location.coordinate.latitude as Double)
        self.longitude = NSNumber(value: location.coordinate.longitude as Double)
        self.speed = NSNumber(value: location.speed as Double)
        self.altitude = NSNumber(value: location.altitude as Double)
        self.verticalAccuracy = NSNumber(value: location.verticalAccuracy as Double)
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
            let aLocation = CLLocation(latitude: (loc as! Location).latitude!.doubleValue, longitude: (loc as! Location).longitude!.doubleValue)
            let distanceFromCenter = centerLocation.distance(from: aLocation)
            if (distanceFromCenter <= circle.radius) {
                filteredResults.append(loc)
            }
        }

        return filteredResults
    }
    
    func jsonDictionary() -> [String: Any] {
        var locDict: [String: Any] = [
            "date": self.date!.JSONString(),
            "horizontalAccuracy": self.horizontalAccuracy!,
            "speed": self.speed!,
            "longitude": self.longitude!,
            "latitude": self.latitude!,
            "isGeofencedLocation": self.isGeofencedLocation
        ]
        if let course = self.course {
            locDict["course"] = course
        }
        if let altitude = self.altitude, let verticalAccuracy = self.verticalAccuracy {
            locDict["altitude"] = altitude
            locDict["verticalAccuracy"] = verticalAccuracy
        }
        
        return locDict
    }
    
    func coordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(self.latitude!.doubleValue, self.longitude!.doubleValue)
    }
    
    func mapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: self.coordinate(), addressDictionary: nil)
        return MKMapItem(placemark: placemark)
    }
    
    func clLocation() -> CLLocation {
        return CLLocation(coordinate: CLLocationCoordinate2D(latitude: self.latitude!.doubleValue, longitude: self.longitude!.doubleValue), altitude: (self.altitude != nil) ? self.altitude!.doubleValue : 0.0, horizontalAccuracy: self.horizontalAccuracy!.doubleValue, verticalAccuracy: (self.verticalAccuracy != nil) ? self.verticalAccuracy!.doubleValue : 0.0, course: self.course!.doubleValue, speed: self.speed!.doubleValue, timestamp: self.date!)
    }
}
