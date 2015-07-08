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
import CZWeatherKit

class Trip : NSManagedObject {
    let simplificationEpisilon: CLLocationDistance = 0.00005
    
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
    
    private struct Static {
        static var dateFormatter : NSDateFormatter!
    }
    
    private var currentStateNotification : UILocalNotification? = nil
    
    @NSManaged var startingPlacemarkName : String!
    @NSManaged var endingPlacemarkName : String!
    @NSManaged var activityType : NSNumber
    @NSManaged var batteryAtEnd : NSNumber!
    @NSManaged var batteryAtStart : NSNumber!
    @NSManaged var activities : NSSet!
    @NSManaged var locations : NSOrderedSet!
    @NSManaged var incidents : NSOrderedSet!
    @NSManaged var hasSmoothed : Bool
    @NSManaged var isSynced : Bool
    var isClosed : Bool {
        get {
            if let num = (self.primitiveValueForKey("isClosed") as! NSNumber?) {
                return num.boolValue
            }
            return false
        }
        set {
            self.willChangeValueForKey("isClosed")
            self.setPrimitiveValue(nil, forKey: "sectionIdentifier")
            self.setPrimitiveValue(NSNumber(bool: newValue), forKey: "isClosed")
            self.didChangeValueForKey("isClosed")
        }
    }
    @NSManaged var uuid : String
    @NSManaged var creationDate : NSDate!
    @NSManaged var length : NSNumber!
    @NSManaged var rating : NSNumber!
    @NSManaged var climacon : String!
    @NSManaged var temperature : NSNumber!

    @NSManaged var simplifiedLocations : NSOrderedSet!
    var sectionIdentifier : String? {
        get {
            self.willAccessValueForKey("sectionIdentifier")
            var sectionString = self.primitiveValueForKey("sectionIdentifier") as! String?
            self.didAccessValueForKey("sectionIdentifier")
            if (sectionString == nil) {
                // do the thing
                if (self.startDate == nil || (self.startDate.isToday() && !self.isClosed)) {
                    sectionString = "In Progress"
                } else if (self.startDate.isToday()) {
                    sectionString = "Today"
                } else if (self.startDate.isYesterday()) {
                    sectionString = "Yesterday"
                } else if (self.startDate.isInLastWeek()) {
                    sectionString = self.startDate.weekDay()
                } else {
                    sectionString = Trip.dateFormatter.stringFromDate(self.startDate)
                }
                self.setPrimitiveValue(sectionString, forKey: "sectionIdentifier")
            }
            
            return sectionString!
        }
    }
    
    class var dateFormatter : NSDateFormatter {
        get {
            if (Static.dateFormatter == nil) {
                Static.dateFormatter = NSDateFormatter()
                Static.dateFormatter.locale = NSLocale.currentLocale()
                Static.dateFormatter.dateFormat = "MMM d"
            }
            
            return Static.dateFormatter
        }
    }
    
    convenience init() {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Trip", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
    }
    
    class func allTrips(limit: Int = 0) -> [AnyObject] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        if (results == nil) {
            return []
        }
        
        return results!
    }
    
    class func weekTrips() -> [AnyObject]? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.predicate = NSPredicate(format: "creationDate > %@", NSDate().daysFrom(-7))
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results!
    }
    
    class func tripWithUUID(uuid: String) -> Trip! {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        fetchedRequest.fetchLimit = 1
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        if (results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func mostRecentTrip() -> Trip! {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.fetchLimit = 1
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        if (results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func emptyTrips() -> [AnyObject]? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "locations.@count == 0")
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results!
    }
    
    class func openTrips() -> [AnyObject]? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "isClosed == NO")
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        return results!
    }
    
    class var numberOfCycledTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.DictionaryResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Cycling.rawValue)
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var totalCycledMiles : Float {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()

        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.DictionaryResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Cycling.rawValue)
        
        let sumDescription = NSExpressionDescription()
        sumDescription.name = "sumOfLengths"
        sumDescription.expression = NSExpression(forKeyPath: "@sum.length")
        sumDescription.expressionResultType = NSAttributeType.FloatAttributeType
        fetchedRequest.propertiesToFetch = [sumDescription]
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        if (results == nil || error != nil) {
            return 0.0
        }
        let totalLength = (results![0] as! NSDictionary).objectForKey("sumOfLengths") as! NSNumber
        return (totalLength.floatValue * 0.000621371)
    }
    
    class var totalCycledMilesThisWeek : Float {
        var miles : Float = 0
        for trip in Trip.weekTrips()! {
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
    
    var isShittyWeather : Bool {
        get {
            if (self.climacon == nil || count(self.climacon!) == 0) {
                return false
            }
            
            if (self.temperature != nil && self.temperature.integerValue < 40) {
                // BRrrrr
                return true
            }
            
            var climaconChar : Int8 = 0 // fml
            for c in self.climacon!.unicodeScalars {
                climaconChar = Int8(c.value)
                break
            }
            
            switch climaconChar {
            case Climacon.Rain.rawValue, Climacon.RainSun.rawValue, Climacon.RainMoon.rawValue,
            Climacon.Downpour.rawValue, Climacon.DownpourSun.rawValue, Climacon.DownpourMoon.rawValue,
            Climacon.Umbrella.rawValue:
                return true
            case Climacon.Sleet.rawValue, Climacon.SleetSun.rawValue, Climacon.SleetMoon.rawValue,
            Climacon.Hail.rawValue, Climacon.HailSun.rawValue, Climacon.HailMoon.rawValue,
            Climacon.Flurries.rawValue, Climacon.FlurriesSun.rawValue, Climacon.FlurriesMoon.rawValue,
            Climacon.Snow.rawValue, Climacon.SnowSun.rawValue, Climacon.SnowMoon.rawValue,
            Climacon.Snowflake.rawValue:
                return true
            case Climacon.Lightning.rawValue, Climacon.LightningSun.rawValue, Climacon.LightningMoon.rawValue:
                return true
            default:
                return false
            }
        }
    }
    
    var climoticon : String {
        get {
            if (self.climacon == nil || count(self.climacon!) == 0) {
                return ""
            }
            
            if (self.activityType != NSNumber(short: Trip.ActivityType.Cycling.rawValue)) {
                // no climacon for car trips!
                return ""
            }
            
            var climaconChar : Int8 = 0 // fml
            for c in self.climacon!.unicodeScalars {
                climaconChar = Int8(c.value)
                break
            }
            
            switch climaconChar {
            case Climacon.Cloud.rawValue, Climacon.CloudDown.rawValue, Climacon.CloudMoon.rawValue,
                Climacon.Fog.rawValue, Climacon.FogMoon.rawValue,
                Climacon.Haze.rawValue, Climacon.HazeMoon.rawValue:
                return "☁️"
            case Climacon.CloudSun.rawValue, Climacon.FogSun.rawValue, Climacon.HazeSun.rawValue:
                return "⛅️"
            case Climacon.Drizzle.rawValue, Climacon.DrizzleSun.rawValue, Climacon.DrizzleMoon.rawValue,
                Climacon.Showers.rawValue, Climacon.ShowersSun.rawValue, Climacon.ShowersMoon.rawValue,
                Climacon.Rain.rawValue, Climacon.RainSun.rawValue, Climacon.RainMoon.rawValue,
                Climacon.Downpour.rawValue, Climacon.DownpourSun.rawValue, Climacon.DownpourMoon.rawValue,
                Climacon.Umbrella.rawValue:
                return "☔️"
            case Climacon.Sun.rawValue, Climacon.Sunset.rawValue, Climacon.Sunrise.rawValue, Climacon.SunLow.rawValue, Climacon.SunLower.rawValue:
                return "☀️"
            case Climacon.MoonNew.rawValue:
                return "🌑"
            case Climacon.MoonWaxingCrescent.rawValue:
                return "🌒"
            case Climacon.MoonWaxingQuarter.rawValue:
                return "🌓"
            case Climacon.Moon.rawValue, Climacon.MoonWaxingGibbous.rawValue:
                return "🌔"
            case Climacon.MoonFull.rawValue:
                return "🌕"
            case Climacon.MoonWaningGibbous.rawValue:
                return "🌖"
            case Climacon.MoonWaningQuarter.rawValue:
                return "🌗"
            case Climacon.MoonWaningCrescent.rawValue:
                return "🌘"
            case Climacon.Sleet.rawValue, Climacon.SleetSun.rawValue, Climacon.SleetMoon.rawValue,
                Climacon.Hail.rawValue, Climacon.HailSun.rawValue, Climacon.HailMoon.rawValue,
                Climacon.Flurries.rawValue, Climacon.FlurriesSun.rawValue, Climacon.FlurriesMoon.rawValue,
                Climacon.Snow.rawValue, Climacon.SnowSun.rawValue, Climacon.SnowMoon.rawValue,
                Climacon.Snowflake.rawValue:
                return "❄️"
            case Climacon.Wind.rawValue, Climacon.WindCloud.rawValue, Climacon.WindCloudSun.rawValue, Climacon.WindCloudMoon.rawValue,
                Climacon.Tornado.rawValue:
                return "💨"
            case Climacon.Lightning.rawValue, Climacon.LightningSun.rawValue, Climacon.LightningMoon.rawValue:
                return "⚡️"
            default:
                return ""
            }
        }
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
            tripTypeString = ""
        }

        return tripTypeString
    }
    
    func batteryLifeUsed() -> Int16 {
        if (self.batteryAtStart == nil || self.batteryAtEnd == nil || self.batteryAtStart.shortValue == 0 || self.batteryAtEnd.shortValue == 0) {
            return 0
        }
        if (self.batteryAtStart.shortValue < self.batteryAtEnd.shortValue) {
            DDLogVerbose("Negative battery life used?")
            return 0
        }
        
        return (self.batteryAtStart.shortValue - self.batteryAtEnd.shortValue)
    }
    
    func duration() -> NSTimeInterval {
        return fabs(self.startDate.timeIntervalSinceDate(self.endDate))
    }
    
    func locationWithCoordinate(coordinate: CLLocationCoordinate2D) -> Location {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let location = Location.init(entity: NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        location.course = self.locations.firstObject!.course
        location.horizontalAccuracy = NSNumber(double: 0.0)
        location.latitude = NSNumber(double: coordinate.latitude)
        location.longitude = NSNumber(double: coordinate.longitude)
        location.speed = NSNumber(double: -1.0)
        location.isSmoothedLocation = true
        
        return location
    }
    
    func undoSmoothWithCompletionHandler(handler: ()->Void) {
        if (self.locations.count < 2 || !self.hasSmoothed) {
            return
        }
        
        DDLogVerbose("De-Smoothing route…")
        
        for element in self.locations.array {
            let location = element as! Location
            if location.isSmoothedLocation {
                location.trip = nil
                location.managedObjectContext?.deleteObject(location)
            }
        }
        
        DDLogVerbose("Route de-smoothed!")
        
        self.hasSmoothed = false
        
        handler()
    }
    
    func findStartingPlacemarkWithHandler(startingLocation : CLLocation, handler: ()->Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(startingLocation, completionHandler: { (placemarks, error) -> Void in
            if (placemarks == nil || placemarks.count == 0) {
                handler()
                return
            }
            let startingPlacemark = placemarks[0] as! CLPlacemark
            self.startingPlacemarkName = startingPlacemark.subLocality
            handler()
        })

    }
    
    func findDestinationPlacemarksWithHandler(handler: ()->Void) {
        if (self.locations.count < 2) {
            handler()
            return
        }
        
        let geocoder = CLGeocoder()
        let endingLocation = self.locations.lastObject as! Location
        
        geocoder.reverseGeocodeLocation(endingLocation.clLocation(), completionHandler: { (placemarks, error) -> Void in
            if (placemarks == nil || placemarks.count == 0) {
                handler()
                return
            }
            let endingPlacemark = placemarks[0] as! CLPlacemark
            self.endingPlacemarkName = endingPlacemark.subLocality
            handler()
        })
    }
    
    func close(handler: ()->Void = {}) {
        if (self.isClosed == true) {
            handler()
            return
        }
        
        var length : CLLocationDistance = 0
        var lastLocation : CLLocation! = nil
        for element in self.locations.array {
            let location = (element as! Location).clLocation()
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
            let endingLocation = self.locations.lastObject as! Location
            
            if (self.climacon == nil || self.climacon == "") {
                WeatherManager.sharedManager.queryCondition(NSDate(), location: endingLocation, handler: { (condition) -> Void in
                    if (condition != nil) {
                        self.temperature = NSNumber(float: Float(condition!.temperature.f))
                        self.climacon = String(UnicodeScalar(UInt32(condition!.climaconCharacter.rawValue)))
                    }
                    handler()
                })
            } else {
                handler()
            }
        }
    }
    
    func reopen() {
        self.isClosed = false
        self.simplifiedLocations = nil
    }
    
    var lengthMiles : Float {
        get {
            return (self.length.floatValue * 0.000621371)
        }
    }
    
    func closestLocationToCoordinate(coordinate: CLLocationCoordinate2D)->Location! {
        let targetLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    
        var closestLocation : Location? = nil
        var closestDisance = CLLocationDistanceMax
        for loc in self.locations {
            let location = loc as! Location
            let locDistance = targetLoc.distanceFromLocation(location.clLocation())
            if (locDistance < closestDisance) {
                closestDisance = locDistance
                closestLocation = location
            }
        }
        
        return closestLocation
    }
    
    func sendTripStartedNotification(startingLocation : CLLocation) {
        if (self.startingPlacemarkName != nil) {
            self.sendTripStartedNotificationImmediately()
        } else {
            self.findStartingPlacemarkWithHandler(startingLocation) { () -> Void in
                self.sendTripStartedNotificationImmediately()
            }
        }
    }
    
    private func sendTripStartedNotificationImmediately() {
        self.cancelTripStateNotification()
        
        var message = ""
        
        if (self.startingPlacemarkName != nil) {
            message = String(format: "Started a trip in %@…", self.startingPlacemarkName)
        } else {
            message = "Started a trip…"
        }
        
        self.currentStateNotification = UILocalNotification()
        self.currentStateNotification?.alertBody = message
        self.currentStateNotification?.category = "RIDE_STARTED_CATEGORY"
        UIApplication.sharedApplication().presentLocalNotificationNow(self.currentStateNotification!)
    }
    
    func sendTripCompletionNotification(handler: ()->Void = {}) {
        self.findDestinationPlacemarksWithHandler() {
            if (self.isClosed == false) {
                // in case the trip was reopened while we were calculating things
                handler()
                return
            }
        
            self.sendTripCompletionNotificationImmediately()
            handler()
        }
    }
    
    func sendTripCompletionNotificationImmediately() {
        self.cancelTripStateNotification()
        
        self.currentStateNotification = UILocalNotification()
        self.currentStateNotification?.alertBody = self.notificationString()
        if (self.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
            // don't play a sound or show rating stuff for anything but bike trips.
            self.currentStateNotification?.soundName = UILocalNotificationDefaultSoundName
            self.currentStateNotification?.alertAction = "rate"
            self.currentStateNotification?.category = "RIDE_COMPLETION_CATEGORY"
            self.currentStateNotification?.userInfo = ["RideNotificationTripUUID" : self.uuid]
        }
        UIApplication.sharedApplication().presentLocalNotificationNow(self.currentStateNotification!)

    }
    
    func notificationString()->String? {
        var message = ""
        
        if (self.startingPlacemarkName != nil && self.endingPlacemarkName != nil) {
            if (self.startingPlacemarkName == self.endingPlacemarkName) {
                message = String(format: "%@ %@ %.1f miles in %@", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName)
            } else {
                message = String(format: "%@ %@ %.1f miles from %@ to %@", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName, self.endingPlacemarkName)
            }
        } else if (self.startingPlacemarkName != nil) {
            message = String(format: "%@ %@ %.1f miles from %@", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName)
        } else {
            message = String(format: "%@ %@ %.1f miles", self.climoticon, self.activityTypeString(), self.lengthMiles)
        }
        
        if (self.activityType == NSNumber(short: Trip.ActivityType.Cycling.rawValue)) {
            let rewardString = self.rewardString()
            if (rewardString != nil) {
                message += (". " + rewardString!)
            }
        }
    
        return message
    }
    
    func rewardString()->String? {
        let totalMiles = Trip.totalCycledMiles
        
        
        if (self.isShittyWeather) {
            return "🏆 Crappy weather bonus points!"
        }
        
        if (totalMiles % 25 == 0) {
            return String(format: "💪 Your %.0fth mile!", totalMiles)
        }
        
        let numTrips = Trip.numberOfCycledTrips
        if (numTrips % 10 == 0) {
            return String(format: "🎉 Your %ith trip!", numTrips)
        }
        
        if (self.lengthMiles > 10.0) {
            return "🌄 Epic Ride!"
        }
        
        return nil
    }
    
    private func cancelTripStateNotification() {
        if (self.currentStateNotification != nil) {
            UIApplication.sharedApplication().cancelLocalNotification(self.currentStateNotification!)
            self.currentStateNotification = nil
        }
    }
    
    func simplify(handler: ()->Void = {}) {
        if (!self.isClosed || self.locations == nil || self.locations.count == 0) {
            handler()
            return
        }
        
        self.simplifyLocations(self.locations.array as! [Location], episilon: simplificationEpisilon)
        CoreDataManager.sharedManager.saveContext()
        handler()
    }
    
    // Ramer–Douglas–Peucker geometric simplication algorithm
    func simplifyLocations(locations: [Location], episilon : CLLocationDegrees) {
        var maximumDistance : CLLocationDegrees = 0
        var indexOfMaximumDistance = 0
        
        let startLoc = locations.first
        let endLoc = locations.last
        var counter = 1
        
        if (locations.count > 2) {
            for loc in locations[1...(locations.count - 2)] {
                let distance = self.shortestDistanceFromLineToPoint(startLoc!.coordinate(), lineEndPoint: endLoc!.coordinate(), point: loc.coordinate())
                if (distance > maximumDistance) {
                    indexOfMaximumDistance = counter
                    maximumDistance = distance
                }
                counter++
            }
        } else {
            // trivial case: two points are more than episilon distance away.
            return
        }
        
        if ( maximumDistance > episilon) {
            self.simplifyLocations(Array(locations[0...indexOfMaximumDistance]), episilon: episilon)
            self.simplifyLocations(Array(locations[indexOfMaximumDistance...(locations.count - 1)]), episilon: episilon)
        } else {
            startLoc!.simplifiedInTrip = self
            endLoc!.simplifiedInTrip = self
        }
    }
    
    private func shortestDistanceFromLineToPoint(lineStartPoint: CLLocationCoordinate2D, lineEndPoint: CLLocationCoordinate2D, point: CLLocationCoordinate2D)->CLLocationDegrees {
        // area of a triangle is given by a = .5 * |Ax(By-Cy) + Bx(Cy-Ay) + Cx(Ay-By)|
        let area = 0.5 * abs(lineStartPoint.longitude * (lineEndPoint.latitude  - point.latitude)
                            + lineEndPoint.longitude * (point.latitude - lineStartPoint.latitude)
                            + point.longitude * (lineStartPoint.latitude - lineEndPoint.latitude))
        
        // base of the triangle is the distance from our start to end points
        let base = sqrt(pow(lineStartPoint.longitude - lineEndPoint.longitude, 2) +
                            pow(lineStartPoint.latitude - lineEndPoint.latitude, 2))
        
        // height = 2* area / base
        return 2 * area / base
    }
    
    func smoothIfNeeded(handler: ()->Void) {
        if (self.locations.count < 2 || self.hasSmoothed) {
            return
        }
        
        DDLogVerbose("Smoothing route…")
        
        self.hasSmoothed = true
        
        let location0 = self.locations.firstObject as! Location
        let location1 = self.locations.objectAtIndex(1) as! Location
        
        let request = MKDirectionsRequest()
        request.setSource((location0 as Location).mapItem())
        request.setDestination((location1 as Location).mapItem())
        request.transportType = MKDirectionsTransportType.Walking
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        directions.calculateDirectionsWithCompletionHandler { (directionsResponse, error) -> Void in
            if (error == nil) {
                let route : MKRoute = directionsResponse.routes.first! as! MKRoute
                let pointCount = route.polyline!.pointCount
                var coords = [CLLocationCoordinate2D](count: pointCount, repeatedValue: kCLLocationCoordinate2DInvalid)
                route.polyline.getCoordinates(&coords, range: NSMakeRange(0, pointCount))
                let mutableLocations = self.locations.mutableCopy() as! NSMutableOrderedSet
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
            
            DDLogVerbose("Route smoothed!")
            
            handler()
        }
    }
    
    func mostRecentLocation() -> Location? {
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        let loc = self.locations.sortedArrayUsingDescriptors([sortDescriptor]).first as! Location
        return loc
    }
    
    var startDate : NSDate! {
        if (self.locations == nil || self.locations.count == 0) {
            return nil
        }
        
        return self.locations.firstObject?.date
    }
    
    var endDate : NSDate! {
        if (self.locations == nil || self.locations.count == 0) {
            return nil
        }
        
        return self.locations.lastObject?.date
    }
    
    var averageSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        for loc in self.locations.array {
            let location = loc as! Location
            if (location.speed!.doubleValue > 0 && location.horizontalAccuracy!.doubleValue <= RouteManager.sharedManager.acceptableLocationAccuracy) {
                count++
                sumSpeed += (location as Location).speed!.doubleValue
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
            MotionManager.sharedManager.queryMotionActivity(self.startDate, toDate: self.endDate) { (activities, error) in
                if (activities != nil) {
                    for activity in activities {
                        Activity(activity: activity as! CMMotionActivity, trip: self)
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
            DDLogInfo(String(format: "No activites! Found speed: %f", self.averageSpeed))
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
            let theActivity = (activity as! Activity)
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
        DDLogInfo(String(format: "Activities scores: %@, speed: %f", scores, self.averageSpeed))
        
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