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
    @NSManaged var latitude : NSNumber?
    @NSManaged var longitude : NSNumber?
    @NSManaged var speed : NSNumber?
    @NSManaged var trip : Trip?
    @NSManaged var simplifiedInTrip : Trip?
    @NSManaged var incidents : NSOrderedSet!
    @NSManaged var date : NSDate?
    
    convenience init(location: CLLocation, trip: Trip) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        
        self.course = NSNumber(double: location.course)
        self.horizontalAccuracy = NSNumber(double: location.horizontalAccuracy)
        self.latitude = NSNumber(double: location.coordinate.latitude)
        self.longitude = NSNumber(double: location.coordinate.longitude)
        self.speed = NSNumber(double: location.speed)
        self.altitude = NSNumber(double: location.altitude)
        self.verticalAccuracy = NSNumber(double: location.verticalAccuracy)
        self.date = location.timestamp
    }
    
    convenience init(trip: Trip) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
    }
    
    class func locationsInCircle(circle:MKCircle) -> [AnyObject] {
        let fetchedRequest = NSFetchRequest(entityName: "Location")
        
        let searchRadius : Double = circle.radius * 1.1 // pad it a bit to allow for error
        let radiusOfEarth : Double = 6371009
        let meanLatitidue = circle.coordinate.latitude * M_PI / 180
        let radiusLatitude = radiusOfEarth / searchRadius * 180 / M_PI
        let radiusLongitude = radiusOfEarth / (searchRadius * cos(meanLatitidue)) * 180 / M_PI
        let minLatitude = circle.coordinate.latitude - radiusLatitude
        let maxLatitude = circle.coordinate.latitude + radiusLatitude
        let minLongitude = circle.coordinate.longitude - radiusLongitude
        let maxLongitude = circle.coordinate.longitude + radiusLongitude

        fetchedRequest.predicate = NSPredicate(format: "(%f <= longitude) AND (longitude <= %f) AND (%f <= latitude) AND (latitude <= %f)", minLongitude, maxLongitude, minLatitude, maxLatitude)
        
        fetchedRequest.returnsObjectsAsFaults = false
        
        let results: [AnyObject]?
        do {
            results = try CoreDataManager.sharedManager.currentManagedObjectContext().executeFetchRequest(fetchedRequest)
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
            let distanceFromCenter = centerLocation.distanceFromLocation(aLocation)
            if (distanceFromCenter <= circle.radius) {
                filteredResults.append(loc)
            }
        }

        return filteredResults
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