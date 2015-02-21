//
//  Trip.swift
//  Ride
//
//  Created by William Henderson on 10/29/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation
import CoreMotion
import MapKit

class Trip : NSManagedObject {
    enum ActivityType : Int16 {
        case Unknown = 0
        case Running
        case Cycling
        case Automotive
        case Walking
    }
    
    enum Rating : Int16 {
        case NotSet = 0
        case Good
        case Bad
    }
    
    private var currentStateNotification : UILocalNotification? = nil;
    private var startingPlacemark : CLPlacemark? = nil;
    
    @NSManaged var activityType : NSNumber
    @NSManaged var batteryAtEnd : NSNumber!
    @NSManaged var batteryAtStart : NSNumber!
    @NSManaged var activities : NSSet!
    @NSManaged var locations : NSOrderedSet!
    @NSManaged var incidents : NSOrderedSet!
    @NSManaged var hasSmoothed : Bool
    @NSManaged var isSynced : Bool
    @NSManaged var isClosed : Bool
    @NSManaged var uuid : String
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
    
    class func openTrips() -> [AnyObject]? {
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "isClosed == NO")
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results!
    }
    
    class var totalCycledMiles : Float {
        var miles : Float = 0
        for trip in Trip.allTrips()! {
            if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                miles += trip.lengthMiles
            }
        }
        
        return miles
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = NSDate()
        self.uuid = NSUUID().UUIDString
    }
    
    func activityTypeString()->String {
        var tripTypeString = ""
        if (self.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
            tripTypeString = "🚗"
        } else if (self.activityType.shortValue == Trip.ActivityType.Walking.rawValue) {
            tripTypeString = "🚶"
        } else if (self.activityType.shortValue == Trip.ActivityType.Running.rawValue) {
            tripTypeString = "🏃"
        } else if (self.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
            tripTypeString = "🚲"
        } else {
            tripTypeString = "Traveled"
        }

        return tripTypeString
    }
    
    func batteryLifeUsed() -> Int16 {
        if (self.batteryAtStart.shortValue == 0 || self.batteryAtEnd.shortValue == 0) {
            return 0
        }
        if (self.batteryAtStart.shortValue < self.batteryAtEnd.shortValue) {
            DDLogWrapper.logVerbose("Negative battery life used?")
            return 0
        }
        
        return (self.batteryAtStart.shortValue - self.batteryAtEnd.shortValue)
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
        
        handler()
    }
    
    func findStartingPlacemarkWithHandler(handler: ()->Void) {
        if (self.locations.count < 1) {
            handler()
            return
        }
        
        let geocoder = CLGeocoder()
        let startingLocation = self.locations.firstObject as Location
        geocoder.reverseGeocodeLocation(startingLocation.clLocation(), completionHandler: { (placemarks, error) -> Void in
            if (placemarks == nil || placemarks.count == 0) {
                handler()
                return
            }
            let startingPlacemark = placemarks[0] as CLPlacemark
            self.startingPlacemark = startingPlacemark
            handler()
        })

    }
    
    func findDestinationPlacemarksWithHandler(handler: (CLPlacemark!!)->Void) {
        if (self.locations.count < 2) {
            handler(nil)
            return
        }
        
        let geocoder = CLGeocoder()
        let endingLocation = self.locations.lastObject as Location
        
        geocoder.reverseGeocodeLocation(endingLocation.clLocation(), completionHandler: { (placemarks, error) -> Void in
            if (placemarks == nil || placemarks.count == 0) {
                handler(nil)
                return
            }
            let endingPlacemark = placemarks[0] as CLPlacemark
            handler(endingPlacemark)
        })
    }
    
    func close(handler: ()->Void = {}) {
        if (self.isClosed == true) {
            return
        }
        
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
        self.isClosed = true
        
        self.clasifyActivityType { () -> Void in
            handler()
        }
    }
    
    func reopen() {
        self.isClosed = false
    }
    
    var lengthMiles : Float {
        get {
            return (self.length.floatValue * 0.000621371)
        }
    }
    
    func sendTripStartedNotification() {
        if (self.startingPlacemark != nil) {
            self.doSendStartingNotification()
        }
        self.findStartingPlacemarkWithHandler { () -> Void in
            self.doSendStartingNotification()
        }
    }
    
    private func doSendStartingNotification() {
        self.cancelTripCompletionNotification()
        
        var message = ""
        
        if (self.startingPlacemark != nil) {
            message = NSString(format: "Started a Ride in %@…", self.startingPlacemark!.subLocality)
        } else {
            message = "Started a Ride in somewhere…"
        }
        
        self.currentStateNotification = UILocalNotification()
        self.currentStateNotification?.alertBody = message
        self.currentStateNotification?.category = "RIDE_STARTED_CATEGORY"
        UIApplication.sharedApplication().presentLocalNotificationNow(self.currentStateNotification!)
    }
    
    func sendTripCompletionNotification() {
        self.findDestinationPlacemarksWithHandler { (endingPlacemark) -> Void in
            if (self.isClosed == false) {
                // in case the trip was reopened while we were calculating things
                return
            }
            
            var message = ""
        
            if (self.startingPlacemark != nil && endingPlacemark != nil) {
                message = NSString(format: "%@ %.1f miles from %@ to %@", self.activityTypeString(), self.lengthMiles, self.startingPlacemark!.subLocality, endingPlacemark!.subLocality)
            } else if (self.startingPlacemark? != nil) {
                message = NSString(format: "%@ %.1f miles from %@ to somewhere", self.activityTypeString(), self.lengthMiles, self.startingPlacemark!.subLocality)
            } else {
                message = NSString(format: "%@ %.1f miles from somewhere to somewhere", self.activityTypeString(), self.lengthMiles)
            }
            
            self.cancelTripCompletionNotification()
            
            self.currentStateNotification = UILocalNotification()
            self.currentStateNotification?.alertBody = message
            if (self.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                // don't show rating stuff for anything but bike trips.
                self.currentStateNotification?.category = "RIDE_COMPLETION_CATEGORY"
            }
            UIApplication.sharedApplication().presentLocalNotificationNow(self.currentStateNotification!)
        }
    }
    
    private func cancelTripCompletionNotification() {
        if (self.currentStateNotification != nil) {
            UIApplication.sharedApplication().cancelLocalNotification(self.currentStateNotification!)
            self.currentStateNotification = nil
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
                    location.date = location0.date
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
            
            handler()
        }
    }
    
    func mostRecentLocation() -> Location? {
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        let loc = self.locations.sortedArrayUsingDescriptors([sortDescriptor]).first as Location
        return loc
    }
    
    var startDate : NSDate! {
        return self.locations.firstObject?.date
    }
    
    var endDate : NSDate! {
        return self.locations.lastObject?.date
    }
    
    var averageSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        for loc in self.locations.array {
            let location = loc as Location
            if (location.speed.doubleValue > 0 && location.horizontalAccuracy.doubleValue <= kCLLocationAccuracyNearestTenMeters) {
                count++
                sumSpeed += (location as Location).speed.doubleValue
            }
        }
        
        if (count == 0) {
            return 0
        }
        
        return sumSpeed/Double(count)
    }
    
    func clasifyActivityType(handler: ()->Void) {
        if (self.activities != nil && self.activities.count > 0) {
            self.runActivityClassification()
            handler()
        } else {
            MotionMachine.sharedMachine.queryMotionActivity(self.startDate, toDate: self.endDate) { (activities, error) in
                if (activities != nil) {
                    for activity in activities {
                        Activity(activity: activity as CMMotionActivity, trip: self)
                    }
                }
                
                self.runActivityClassification()
                handler()
            }
        }
    }
    
    func runActivityClassification() {
        if (self.activities == nil || self.activities.count == 0) {
            // if no data is available, fall back on speed alone
            if (self.averageSpeed >= 8) {
                self.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            } else if (self.averageSpeed >= 3) {
                self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            } else {
                self.activityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
            }
            
            return
        }
        
        var walkScore = 0
        var runScore = 0
        var autoScore = 0
        var cycleScore = 0
        for activity in self.activities.allObjects {
            let theActivity = (activity as Activity)
            if (theActivity.walking) {
                walkScore += theActivity.confidence.integerValue
            }
            if (theActivity.running) {
                runScore += theActivity.confidence.integerValue
            }
            if (theActivity.automotive) {
                autoScore += theActivity.confidence.integerValue
            }
            if (theActivity.cycling) {
                cycleScore += theActivity.confidence.integerValue
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
            if (self.averageSpeed >= 7) {
                // Core Motion misidentifies cycling as automotive, particularly when the phone is *not* in your pocket
                self.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            } else {
                self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            }
        } else if scores[0] == runScore {
            self.activityType = NSNumber(short: Trip.ActivityType.Running.rawValue)
        }
        
    }

}