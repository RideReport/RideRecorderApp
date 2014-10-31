//
//  Trip.swift
//  HoneyBee
//
//  Created by William Henderson on 10/29/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation

import Foundation
import CoreData
import CoreLocation
import MapKit

class Trip : NSManagedObject {
    enum ActivityType : Int16 {
        case Walking = 0
        case Running
        case Cycling
        case Automotive
        case Unknown
    }
    
    @NSManaged var activityType : NSNumber
    @NSManaged var creationDate : NSDate!
    @NSManaged var locations : NSMutableOrderedSet!
    @NSManaged var hasSmoothed : Bool
    
    convenience init(activityType: Trip.ActivityType) {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Trip", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.activityType = NSNumber(short: activityType.rawValue)
    }
    
    class func allTrips() -> [AnyObject]? {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results!
    }
    
    class func emptyTrips() -> [AnyObject]? {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "locations.@count == 0")
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results!
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = NSDate()
    }
    
    func locationWithCoordinate(coordinate: CLLocationCoordinate2D) -> Location {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let location = Location.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        location.course = self.locations.firstObject!.course
        location.horizontalAccuracy = NSNumber(double: 0.0)
        location.latitude = NSNumber(double: coordinate.latitude)
        location.longitude = NSNumber(double: coordinate.longitude)
        location.speed = self.locations.objectAtIndex(1).speed
        location.isSmoothedLocation = true
        
        return location
    }
    
    func smoothIfNeeded() {
        if (self.locations.count < 2 || self.hasSmoothed) {
            return
        }
        
        DDLogWrapper.logVerbose("Smoothing route…")
        
        self.hasSmoothed = true
        
        let location0 = self.locations.firstObject as Location
        let location1 = self.locations.objectAtIndex(1) as Location
        
        let request = MKDirectionsRequest()
        request.setSource((location0 as Location).mapItem())
        request.setDestination((location1 as Location).mapItem())
        request.transportType = MKDirectionsTransportType.Walking
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        directions.calculateDirectionsWithCompletionHandler { (directionsResponse, error) -> Void in
            if (error == nil) {
                let route : MKRoute = directionsResponse.routes.first! as MKRoute
                let pointCount = route.polyline!.pointCount
                var coords = [CLLocationCoordinate2D](count: pointCount, repeatedValue: kCLLocationCoordinate2DInvalid)
                route.polyline.getCoordinates(&coords, range: NSMakeRange(0, pointCount))
                for index in 0..<pointCount {
                    let location = self.locationWithCoordinate(coords[index])
                    location.trip = self
                    self.locations.insertObject(location, atIndex: 1+index)
                }                
            } else {
                self.hasSmoothed = false
            }
            
//            self.locations.removeObject(location0)
//            CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(location0)
//            self.locations.removeObject(location1)
//            CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(location1)
            
            DDLogWrapper.logVerbose("Route smoothed!")
            CoreDataController.sharedCoreDataController.saveContext()
        }
    }

}