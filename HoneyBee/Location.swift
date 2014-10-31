//
//  Location.swift
//  HoneyBee
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

    @NSManaged var course : NSNumber
    @NSManaged var horizontalAccuracy : NSNumber
    @NSManaged var isSmoothedLocation : Bool
    @NSManaged var latitude : NSNumber
    @NSManaged var longitude : NSNumber
    @NSManaged var speed : NSNumber
    @NSManaged var trip : Trip
    
    convenience init(location: CLLocation, trip: Trip) {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        
        self.course = NSNumber(double: location.course)
        self.horizontalAccuracy = NSNumber(double: location.horizontalAccuracy)
        self.latitude = NSNumber(double: location.coordinate.latitude)
        self.longitude = NSNumber(double: location.coordinate.longitude)
        self.speed = NSNumber(double: location.speed)
    }
    
    func coordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(self.latitude.doubleValue, self.longitude.doubleValue)
    }
    
    func mapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: self.coordinate(), addressDictionary: nil)
        return MKMapItem(placemark: placemark)
    }
}