//
//  Location.swift
//  Ride
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
    @NSManaged var course : NSNumber?
    @NSManaged var horizontalAccuracy : NSNumber?
    @NSManaged var isPrivate : Bool
    @NSManaged var isSmoothedLocation : Bool
    @NSManaged var latitude : NSNumber?
    @NSManaged var longitude : NSNumber?
    @NSManaged var speed : NSNumber?
    @NSManaged var trip : Trip?
    @NSManaged var simplifiedInTrip : Trip?
    @NSManaged var incidents : NSOrderedSet!
    @NSManaged var date : NSDate?
    
    convenience init(location: CLLocation, trip: Trip) {
        let context = CoreDataManager.sharedCoreDataManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        
        self.course = NSNumber(double: location.course)
        self.horizontalAccuracy = NSNumber(double: location.horizontalAccuracy)
        self.latitude = NSNumber(double: location.coordinate.latitude)
        self.longitude = NSNumber(double: location.coordinate.longitude)
        self.speed = NSNumber(double: location.speed)
        self.date = location.timestamp

        if (PrivacyCircle.privacyCircle() != nil) {
            let circleCenterLocation = CLLocation(latitude: PrivacyCircle.privacyCircle().latitude.doubleValue, longitude: PrivacyCircle.privacyCircle().longitude.doubleValue)

            let distanceFromCenter = circleCenterLocation.distanceFromLocation(location)
            if (distanceFromCenter <= PrivacyCircle.privacyCircle().radius.doubleValue) {
                self.isPrivate = true
            }
        }
    }
    
    class func privateLocations() -> [AnyObject] {
        let fetchedRequest = NSFetchRequest(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "isPrivate = true")

        var error : NSError?
        let results = CoreDataManager.sharedCoreDataManager.currentManagedObjectContext().executeFetchRequest(fetchedRequest, error: &error)
        
        
        if (results == nil) {
            return []
        }
        
        
        return results!
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
        
        var error : NSError?
        let results = CoreDataManager.sharedCoreDataManager.currentManagedObjectContext().executeFetchRequest(fetchedRequest, error: &error)
        
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
        return CLLocation(coordinate: CLLocationCoordinate2D(latitude: self.latitude!.doubleValue, longitude: self.longitude!.doubleValue), altitude: 0.0, horizontalAccuracy: self.horizontalAccuracy!.doubleValue, verticalAccuracy: 0.0, course: self.course!.doubleValue, speed: self.speed!.doubleValue, timestamp: self.date)
    }
}