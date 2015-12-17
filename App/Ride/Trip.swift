//
//  Trip.swift
//  Ride Report
//
//  Created by William Henderson on 10/29/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON
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
        case Transit
    }
    
    enum Rating : Int16 {
        case NotSet = 0
        case Good
        case Bad
    }
    
    private struct Static {
        static var dateFormatter : NSDateFormatter!
        static var yearDateFormatter : NSDateFormatter!
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
    @NSManaged var locationsAreSynced : Bool
    @NSManaged var locationsNotYetDownloaded : Bool
    @NSManaged var rewardDescription : String!
    @NSManaged var rewardEmoji : String!
    
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
    @NSManaged var uuid : String?
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
                if (self.creationDate == nil || (self.creationDate.isToday() && !self.isClosed)) {
                    sectionString = "In Progress"
                } else if (self.creationDate.isToday()) {
                    sectionString = "Today"
                } else if (self.creationDate.isYesterday()) {
                    sectionString = "Yesterday"
                } else if (self.creationDate.isInLastWeek()) {
                    sectionString = self.creationDate.weekDay()
                } else if (self.creationDate.isThisYear()) {
                    sectionString = Trip.dateFormatter.stringFromDate(self.creationDate)
                } else {
                    sectionString = Trip.yearDateFormatter.stringFromDate(self.creationDate)
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
    
    class var yearDateFormatter : NSDateFormatter {
        get {
            if (Static.yearDateFormatter == nil) {
                Static.yearDateFormatter = NSDateFormatter()
                Static.yearDateFormatter.locale = NSLocale.currentLocale()
                Static.yearDateFormatter.dateFormat = "MMM d ''yy"
            }
            
            return Static.yearDateFormatter
        }
    }
    
    convenience init() {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Trip", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
    }
    
    class func tripCount() -> Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (error != nil) {
            return 0
        }
        
        return count
    }
    
    class func allBikeTrips(limit: Int = 0) -> [AnyObject] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Cycling.rawValue)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        if (results == nil) {
            return []
        }
        
        return results!
    }
    
    class func allTrips(limit: Int = 0) -> [AnyObject] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        if (results == nil) {
            return []
        }
        
        return results!
    }
    
    class func allTripsWithUUIDs(limit: Int = 0) -> [AnyObject] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "uuid != \"\" AND uuid != nil")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
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
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return []
        }
        
        return results!
    }
    
    class func tripWithUUID(uuid: String) -> Trip! {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "uuid == [c] %@", uuid)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func tripWithCreationDate(creationDate: NSDate) -> Trip! {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        
        // fudge the creation date by a second, just in case
        fetchedRequest.predicate = NSPredicate(format: "(creationDate >= %@) AND (creationDate =< %@)", creationDate.secondsFrom(-1), creationDate.secondsFrom(1))
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func bikeTripsToday() -> [Trip]? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.Cycling.rawValue, NSDate().beginingOfDay())
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return results! as? [Trip]
    }
    
    class func mostRecentBikeTrip() -> Trip? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Cycling.rawValue)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func leastRecentBikeTrip() -> Trip? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Cycling.rawValue)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func openTrips() -> [AnyObject] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        let closedPredicate = NSPredicate(format: "isClosed == NO")
        fetchedRequest.predicate = closedPredicate
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return []
        }
        
        return results!
    }
    
    class func nextClosedUnsyncedTrips() -> Trip? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        let closedPredicate = NSPredicate(format: "isClosed == YES")
        let syncedPredicate = NSPredicate(format: "isSynced == NO")
        fetchedRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicateType.AndPredicateType, subpredicates: [closedPredicate, syncedPredicate])
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class var numberOfCycledTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Cycling.rawValue)
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfAutomotiveTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Automotive.rawValue)
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfTransitTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Transit.rawValue)
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfCycledTripsLast30Days : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.Cycling.rawValue, NSDate().daysFrom(-30))
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfAutomotiveTripsLast30Days : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.Automotive.rawValue, NSDate().daysFrom(-30))
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfTransitTripsLast30Days : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.Transit.rawValue, NSDate().daysFrom(-30))
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfUnratedTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND rating == %i", ActivityType.Cycling.rawValue, Rating.NotSet.rawValue)
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfBadTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND rating == %i", ActivityType.Cycling.rawValue, Rating.Bad.rawValue)
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfGoodTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND rating == %i", ActivityType.Cycling.rawValue, Rating.Good.rawValue)
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    private class func rainClimaconSet()->Set<String> {
        var climaconSet: Set<String> = Set([])
        for climaconRaw in [Climacon.Drizzle.rawValue, Climacon.DrizzleSun.rawValue, Climacon.DrizzleMoon.rawValue,
            Climacon.Showers.rawValue, Climacon.ShowersSun.rawValue, Climacon.ShowersMoon.rawValue,
            Climacon.Rain.rawValue, Climacon.RainSun.rawValue, Climacon.RainMoon.rawValue,
            Climacon.Downpour.rawValue, Climacon.DownpourSun.rawValue, Climacon.DownpourMoon.rawValue,
            Climacon.Umbrella.rawValue] {
                climaconSet.insert(String(UnicodeScalar(Int(climaconRaw))))
        }
        
        return climaconSet
    }
    
    class var numberOfWarmSunnyTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND temperature >= 45 AND climacon != \"\" AND NOT(climacon IN %@)", ActivityType.Cycling.rawValue, rainClimaconSet())
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfRainyTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND climacon IN %@", ActivityType.Cycling.rawValue, rainClimaconSet())
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfColdTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND temperature < 40 AND climacon != \"\" AND NOT(climacon IN %@)", ActivityType.Cycling.rawValue, rainClimaconSet())
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var totalCycledMilesThisWeek : Float {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.DictionaryResultType
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.Cycling.rawValue, NSDate().daysFrom(-7))
        
        let sumDescription = NSExpressionDescription()
        sumDescription.name = "sumOfLengths"
        sumDescription.expression = NSExpression(forKeyPath: "@sum.length")
        sumDescription.expressionResultType = NSAttributeType.FloatAttributeType
        fetchedRequest.propertiesToFetch = [sumDescription]

        var error : NSError?
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error1 as NSError {
            error = error1
            results = nil
        }
        if (results == nil || error != nil) {
            return 0.0
        }
        
        let totalLength = (results![0] as! NSDictionary).objectForKey("sumOfLengths") as! NSNumber
        return (totalLength.floatValue * 0.000621371)
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = NSDate()
    }
    
    var isShittyWeather : Bool {
        get {
            if (self.climacon == nil || (self.climacon!).characters.count == 0) {
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
            case Climacon.Rain.rawValue, Climacon.Downpour.rawValue, Climacon.DownpourSun.rawValue, Climacon.DownpourMoon.rawValue,
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
            if (self.climacon == nil || (self.climacon!).characters.count == 0) {
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
        } else if (self.activityType.shortValue == Trip.ActivityType.Transit.rawValue) {
            tripTypeString = "🚋"
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
    
    func cancel() {
        CoreDataManager.sharedManager.currentManagedObjectContext().deleteObject(self)
        CoreDataManager.sharedManager.saveContext()
        NSNotificationCenter.defaultCenter().postNotificationName("TripDidCloseOrCancelTrip", object: self)
    }
    
    func saveAndMarkDirty() {
        if (self.hasChanges && self.isSynced.boolValue) {
            self.isSynced = false
        }
        
        CoreDataManager.sharedManager.saveContext()
    }
    
    private func calculateLength()-> Void {
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
    }
    
    func close(handler: ()->Void = {}) {
        if (self.isClosed == true) {
            handler()
            return
        }
        
        self.calculateLength()
        self.isClosed = true
        
        self.clasifyActivityType { () -> Void in
            NSNotificationCenter.defaultCenter().postNotificationName("TripDidCloseOrCancelTrip", object: self)
            self.saveAndMarkDirty()
            handler()
        }
    }
    
    func reopen() {
        self.isClosed = false
        self.locationsAreSynced = false
        self.simplifiedLocations = nil
    }
    
    func loadSummaryFromJSON(summary: [String: JSON]) {
        if let conditions = summary["weather"]?["conditions"],
            climacon = conditions["icon"].string,
            temperature = conditions["temperature"].number {
            self.temperature = temperature
            self.climacon = String(UnicodeScalar(UInt32(CZForecastioAPI.climaconForIconName(climacon).rawValue)))
        }
        
        if let rewardEmoji = summary["rewardEmoji"]?.string,
            rewardDescription = summary["rewardDescription"]?.string {
                if (rewardDescription == "") {
                    self.rewardDescription = nil
                } else {
                    self.rewardDescription = rewardDescription
                }
                
                if (rewardEmoji == "") {
                    self.rewardEmoji = nil
                } else {
                    self.rewardEmoji = rewardEmoji
                }
        }
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
    
    func sendTripCompletionNotificationLocally() {
        DDLogInfo("Sending notification…")

        self.cancelTripStateNotification()
        
        if (self.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
            // don't show a notification for anything but bike trips.
            self.currentStateNotification = UILocalNotification()
            self.currentStateNotification?.alertBody = self.notificationString()
            self.currentStateNotification?.soundName = UILocalNotificationDefaultSoundName
            self.currentStateNotification?.alertAction = "rate"
            self.currentStateNotification?.category = "RIDE_COMPLETION_CATEGORY"
            
            if let uuid = self.uuid {
                self.currentStateNotification?.userInfo = ["uuid" : uuid]
            }
            UIApplication.sharedApplication().presentLocalNotificationNow(self.currentStateNotification!)
        }
    }
    
    func notificationString()->String? {
        var message = ""
        
        if (self.startingPlacemarkName != nil && self.endingPlacemarkName != nil) {
            if (self.startingPlacemarkName == self.endingPlacemarkName) {
                message = String(format: "%@ %@ %.1f miles in %@.", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName)
            } else {
                message = String(format: "%@ %@ %.1f miles from %@ to %@.", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName, self.endingPlacemarkName)
            }
        } else if (self.startingPlacemarkName != nil) {
            message = String(format: "%@ %@ %.1f miles from %@.", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName)
        } else {
            message = String(format: "%@ %@ %.1f miles.", self.climoticon, self.activityTypeString(), self.lengthMiles)
        }
        
        if let rewardDescription = self.rewardDescription,
            rewardEmoji = self.rewardEmoji {
                message += (" " + rewardEmoji + " " + rewardDescription)
        }
        
        
        return message
    }
    
    func shareString()->String {
        var message = ""
        
        if (self.startingPlacemarkName != nil && self.endingPlacemarkName != nil) {
            if (self.startingPlacemarkName == self.endingPlacemarkName) {
                message = String(format: "%@ %@ Rode %.1f miles in %@ with @RideReportApp!", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName)
            } else {
                message = String(format: "%@ %@ Rode %.1f miles from %@ to %@ with @RideReportApp!", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName, self.endingPlacemarkName)
            }
        } else if (self.startingPlacemarkName != nil) {
            message = String(format: "%@ %@ Rode %.1f miles from %@ with @RideReportApp!", self.climoticon, self.activityTypeString(), self.lengthMiles, self.startingPlacemarkName)
        } else {
            message = String(format: "%@ %@ Rode %.1f miles with @RideReportApp!", self.climoticon, self.activityTypeString(), self.lengthMiles)
        }
        
        
        return message
    }
    
    var isFirstBikeTripToday: Bool {
        if let tripsToday = Trip.bikeTripsToday() {
            return tripsToday.contains(self) && tripsToday.count == 1
        }
        
        return false
    }
    
    func cancelTripStateNotification() {
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
        request.source = (location0 as Location).mapItem()
        request.destination = (location1 as Location).mapItem()
        request.transportType = MKDirectionsTransportType.Walking
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        directions.calculateDirectionsWithCompletionHandler { (directionsResponse, error) -> Void in
            if (error == nil) {
                let route : MKRoute = directionsResponse!.routes.first!
                let pointCount = route.polyline.pointCount
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
                dispatch_async(dispatch_get_main_queue(), {
                    if (activities == nil || activities!.count == 0) {
                        #if DEBUG
                            let notif = UILocalNotification()
                            notif.alertBody = "🐞 Got no motion activities!!"
                            notif.category = "NO_MOTION_DATA_CATEGORY"
                            if let uuid = self.uuid {
                                notif.userInfo = ["uuid" : uuid]
                            }
                            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
                        #endif
                    } else {
                        for activity in activities! {
                            Activity(activity: activity , trip: self)
                        }
                    }
                    
                    CoreDataManager.sharedManager.saveContext()
                    
                    self.runActivityClassification()
                    handler()
                })
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
        
        scores.sortInPlace{$1 < $0}
        if scores[0] == 0 {
            // if no one scored, possibly because there was no activity data available, fall back on speeds.
            DDLogInfo(String(format: "No activites scored! Found speed: %f", self.averageSpeed))
            if (self.averageSpeed >= 8) {
                self.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            } else if (self.averageSpeed >= 3) {
                self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            } else {
                self.activityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
            }
        } else if scores[0] == cycleScore {
            if (self.averageSpeed >= 8.5) {
                // Core Motion misidentifies auto trips as cycling
                self.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            } else {
                self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            }
        } else if scores[0] == walkScore {
            if (self.averageSpeed >= 3) {
                // Core Motion misidentifies cycling as walking, particularly when your phone is in your pocket during the ride
                self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            } else {
                self.activityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
            }
        } else if scores[0] == autoScore {
            if (((Double(walkScore + cycleScore + runScore)/Double(autoScore)) > 0.5 && self.averageSpeed < 8.5) ||
                self.averageSpeed < 5.5) {
                // Core Motion misidentifies cycling as automotive
                // if it isn't a decisive victory, also look at speed
                self.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            } else {
                self.activityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            }
        } else if scores[0] == runScore {
            self.activityType = NSNumber(short: Trip.ActivityType.Running.rawValue)
        }
        
    }

}