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
import CoreMotion
import MapKit

class Trip : NSManagedObject {
    enum ActivityType : Int16 {
        case Walking = 0
        case Running
        case Cycling
        case Automotive
        case Unknown
    }
    
    enum Rating : Int16 {
        case NotSet = 0
        case Good
        case Bad
    }
    
    @NSManaged var activityType : NSNumber
    @NSManaged var locations : NSOrderedSet!
    @NSManaged var hasSmoothed : Bool
    @NSManaged var creationDate : NSDate!
    @NSManaged var length : NSNumber!
    @NSManaged var rating : NSNumber!
    
    convenience init() {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Trip", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)        
    }
    
    class func allTrips() -> [AnyObject]? {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results!
    }
    
    class func mostRecentTrip() -> Trip! {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.fetchLimit = 1
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        if (results!.count == 0) {
            return nil
        }
        
        return (results!.first as Trip)
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
    
    func duration() -> NSTimeInterval {
        return fabs(self.startDate.timeIntervalSinceDate(self.endDate))
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
    
    func undoSmoothWithCompletionHandler(handler: ()->Void) {
        if (self.locations.count < 2 || !self.hasSmoothed) {
            return
        }
        
        DDLogWrapper.logVerbose("De-Smoothing route…")
        
        for element in self.locations.array {
            let location = element as Location
            if location.isSmoothedLocation {
                location.trip = nil
                location.managedObjectContext?.deleteObject(location)
            }
        }
        
        DDLogWrapper.logVerbose("Route de-smoothed!")
        
        self.hasSmoothed = false
        CoreDataController.sharedCoreDataController.saveContext()
        
        handler()
    }
    
    func findStartingAndDestinationPlacemarksWithHandler(handler: (CLPlacemark!, CLPlacemark!)->Void) {
        if (self.locations.count < 2) {
            handler(nil, nil)
            return
        }
        
        let geocoder = CLGeocoder()
        let startingLocation = self.locations.firstObject as Location
        let endingLocation = self.locations.lastObject as Location
        geocoder.reverseGeocodeLocation(startingLocation.clLocation(), completionHandler: { (placemarks, error) -> Void in
            if (placemarks == nil || placemarks.count == 0) {
                handler(nil,nil)
                return
            }
            let startingPlacemark = placemarks[0] as CLPlacemark
            geocoder.reverseGeocodeLocation(endingLocation.clLocation(), completionHandler: { (placemarks, error) -> Void in
                if (placemarks == nil || placemarks.count == 0) {
                    handler(startingPlacemark,nil)
                    return
                }
                let endingPlacemark = placemarks[0] as CLPlacemark
                handler(startingPlacemark, endingPlacemark)
            })
        })
    }
    
    func closeTrip() {
        var length : CLLocationDistance = 0
        var lastLocation : CLLocation! = nil
        for element in self.locations.array {
            let location = (element as Location).clLocation()
            if (lastLocation == nil) {
                lastLocation = location
                continue
            }
            length += lastLocation!.distanceFromLocation(location)
            lastLocation = location
        }
        
        self.length = NSNumber(double: length)
        
        CoreDataController.sharedCoreDataController.saveContext()
    }
    
    var lengthMiles : Float {
        get {
            return (self.length.floatValue * 0.000621371)
        }
    }
    
    func sendTripCompletionNotification() {
        self.findStartingAndDestinationPlacemarksWithHandler { (startingPlacemark, endingPlacemark) -> Void in
            var message = ""
            
            if (startingPlacemark != nil && endingPlacemark != nil) {
                message = NSString(format: "🚴💨 You biked %.1f miles from %@ to %@", self.lengthMiles, startingPlacemark.subLocality, endingPlacemark.subLocality)
            } else if (startingPlacemark != nil) {
                message = NSString(format: "🚴💨 You biked %.1f miles from %@ to somewhere", self.lengthMiles, startingPlacemark.subLocality)
            } else {
                message = NSString(format: "🚴💨 You biked %.1f miles from somewhere to somewhere", self.lengthMiles)
            }
            
            let notif = UILocalNotification()
            notif.alertBody = message
            notif.category = "RIDE_COMPLETION_CATEGORY"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        }
    }
    
    func smoothIfNeeded(handler: ()->Void) {
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
                let mutableLocations = self.locations.mutableCopy() as NSMutableOrderedSet
                for index in 0..<pointCount {
                    let location = self.locationWithCoordinate(coords[index])
                    location.trip = self
                    mutableLocations.insertObject(location, atIndex: 1+index)
                }
                self.locations = mutableLocations
            } else {
                self.hasSmoothed = false
            }
            
//            self.locations.removeObject(location0)
//            location0.managedObjectContext.deleteObject(location0)
//            self.locations.removeObject(location1)
//            location1.managedObjectContext.deleteObject(location1)
            
            DDLogWrapper.logVerbose("Route smoothed!")
            CoreDataController.sharedCoreDataController.saveContext()
            
            handler()
        }
    }
    
    var startDate : NSDate! {
        return self.locations.firstObject?.date
    }
    
    var endDate : NSDate!! {
        return self.locations.lastObject?.date
    }
    
    var averageSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        for location in self.locations.array {
            if (location as Location).speed.doubleValue > 0 {
                count++
                sumSpeed += (location as Location).speed.doubleValue
            }
        }
        
        return sumSpeed/Double(count)
    }
    
    func clasifyActivityType(handler: ()->Void) {
        RouteMachine.sharedMachine.queryMotionActivity(self.startDate, toDate: self.endDate) { (activities, error) in
            var walkScore = 0
            var runScore = 0
            var autoScore = 0
            var cycleScore = 0
            for activity in activities {
                let theActivity = (activity as CMMotionActivity)
                if (theActivity.walking) {
                    walkScore += theActivity.confidence.rawValue
                }
                if (theActivity.running) {
                    runScore += theActivity.confidence.rawValue
                }
                if (theActivity.automotive) {
                    autoScore += theActivity.confidence.rawValue
                }
                if (theActivity.cycling) {
                    cycleScore += theActivity.confidence.rawValue
                }
            }
            
            var scores = [walkScore, runScore, autoScore, cycleScore]
            scores.sort{$1 < $0}
            if scores[0] == 0 {
                // if no one scored, possibly because there was no activity data available, fall back on speeds.
                if (self.averageSpeed >= 3) {
                    self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
                } else {
                    self.activityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
                }
            } else if scores[0] == cycleScore {
                self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            } else if scores[0] == walkScore {
                if (self.averageSpeed >= 3) {
                    // Core Motion misidentifies cycling as walking, particularly when your phone is in your pocket during the ride
                    self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
                } else {
                    self.activityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
                }
            } else if scores[0] == autoScore {
                self.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            } else if scores[0] == runScore {
                self.activityType = NSNumber(short: Trip.ActivityType.Running.rawValue)
            }
            
            CoreDataController.sharedCoreDataController.saveContext()
            
            handler()
        }
    }

}