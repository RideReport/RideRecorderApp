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

@objc enum ActivityType : Int16 {
    case Unknown = 0
    case Running
    case Cycling
    case Automotive
    case Walking
    case Bus
    case Rail
    case Stationary
    case Aviation
    
    static var count: Int { return Int(ActivityType.Stationary.rawValue) + 1}
    
    var emoji: String {
        get {
            var tripTypeString = ""
            switch self {
            case .Unknown:
                tripTypeString = "❓"
            case .Running:
                tripTypeString = "🏃"
            case .Cycling:
                tripTypeString = "🚲"
            case .Automotive:
                tripTypeString = "🚗"
            case .Walking:
                tripTypeString = "🚶"
            case .Bus:
                tripTypeString = "🚌"
            case .Rail:
                tripTypeString = "🚈"
            case .Stationary:
                tripTypeString = "💤"
            case .Aviation:
                tripTypeString = "✈️"
            }
            
            return tripTypeString
        }
    }
}

class Trip : NSManagedObject {
    let simplificationEpisilon: CLLocationDistance = 0.00005
    
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
    @NSManaged var activityType : ActivityType
    @NSManaged var batteryAtEnd : NSNumber!
    @NSManaged var batteryAtStart : NSNumber!
    @NSManaged var sensorDataCollections : NSOrderedSet!
    @NSManaged var locations : NSOrderedSet!
    @NSManaged var incidents : NSOrderedSet!
    @NSManaged var hasSmoothed : Bool
    @NSManaged var isSynced : Bool
    @NSManaged var locationsAreSynced : Bool
    @NSManaged var summaryIsSynced : Bool
    @NSManaged var locationsNotYetDownloaded : Bool
    @NSManaged var rewardDescription : String!
    @NSManaged var rewardEmoji : String!
    @NSManaged var healthKitUuid : String!
    
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
    @NSManaged var uuid : String!
    @NSManaged var creationDate : NSDate!
    @NSManaged var length : NSNumber?
    @NSManaged var rating : NSNumber!
    @NSManaged var climacon : String?
    @NSManaged var simplifiedLocations : NSOrderedSet!
    
    class func reloadSectionIdentifiers() {
        
        for trip in self.allTrips() {
            trip.setPrimitiveValue(nil, forKey: "sectionIdentifier")
        }
        
        CoreDataManager.sharedManager.saveContext()
    }
    
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
    
    convenience init(prototrip: Prototrip?) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Trip", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        if let thePrototrip = prototrip {
            self.creationDate = thePrototrip.creationDate
            self.batteryAtStart = thePrototrip.batteryAtStart
            thePrototrip.moveSensorDataAndLocationsToTrip(self)
        }
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
    
    class func mostRecentTrip() -> Trip? {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
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
    
    class func unclassifiedTrips() -> [AnyObject] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        let predicate = NSPredicate(format: "activityType == %i", ActivityType.Unknown.rawValue)
        fetchedRequest.predicate = predicate
        
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
    
    class func unweatheredTrips() -> [AnyObject] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        let predicate = NSPredicate(format: "climacon == nil OR climacon == ''")
        fetchedRequest.predicate = predicate
        
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
        let locationsAreSyncedPredicate = NSPredicate(format: "locationsAreSynced == NO")
        let syncedCompoundPredicate = NSCompoundPredicate(type: NSCompoundPredicateType.OrPredicateType, subpredicates: [locationsAreSyncedPredicate, syncedPredicate])

        fetchedRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicateType.AndPredicateType, subpredicates: [closedPredicate, syncedCompoundPredicate])
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
    
    class var numberOfBusTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Bus.rawValue)
        
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
    
    class var numberOfBusTripsLast30Days : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.Bus.rawValue, NSDate().daysFrom(-30))
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class var numberOfRewardedTrips : Int {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.CountResultType
        fetchedRequest.predicate = NSPredicate(format: "rewardEmoji != nil")
        
        var error : NSError?
        let count = context.countForFetchRequest(fetchedRequest, error: &error)
        if (count == NSNotFound || error != nil) {
            return 0
        }
        
        return count
    }
    
    class func bikeTripCountsGroupedByAttribute(attribute: String, additionalAttributes: [String]? = nil) -> [[String: AnyObject]] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let  countExpression = NSExpressionDescription()
        countExpression.name = "count"
        countExpression.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: attribute)])
        countExpression.expressionResultType = NSAttributeType.Integer32AttributeType
        let entityDescription = NSEntityDescription.entityForName("Trip", inManagedObjectContext: CoreDataManager.sharedManager.managedObjectContext!)!
        
        guard let attributeDescription = entityDescription.attributesByName[attribute] else {
            return []
        }
        
        let fetchedRequest = NSFetchRequest(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var propertiesToFetch = [attributeDescription, countExpression]
        var propertiesToGroupBy = [attributeDescription]
        if let otherAttributes = additionalAttributes {
            for otherAttribute in otherAttributes {
                if let attributeDesc = entityDescription.attributesByName[otherAttribute] {
                    propertiesToFetch.append(attributeDesc)
                    propertiesToGroupBy.append(attributeDesc)
                }
            }
        }
        
        fetchedRequest.propertiesToFetch = propertiesToFetch
        fetchedRequest.propertiesToGroupBy = propertiesToGroupBy
        fetchedRequest.resultType = NSFetchRequestResultType.DictionaryResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.Cycling.rawValue)
        
        var error : NSError?
        let results: [AnyObject]?

        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error1 as NSError {
            error = error1
            results = nil
        }
        if (results == nil || error != nil) {
            return []
        }
        
        let dictResults = results as! [[String: AnyObject]]
        
        if (dictResults.count == 1 && (dictResults[0]["count"]! as? NSNumber)?.integerValue == 0) {
            return []
        }
        
        return dictResults
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
        self.generateUUID()
    }
    
    override func awakeFromFetch() {
        super.awakeFromFetch()
        
        // should never happen, but some legacy clients may find themselves in this state
        if (self.uuid == nil) {
            self.generateUUID()
        }
    }
    
    func generateUUID() {
        self.uuid = NSUUID().UUIDString
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
        for location in self.accurateLocations() {
            let cllocation = location.clLocation()
            if (lastLocation == nil) {
                lastLocation = cllocation
                continue
            }
            length += lastLocation!.distanceFromLocation(cllocation)
            lastLocation = cllocation
        }
        
        self.length = NSNumber(double: length)
    }
    
    func calculateAggregatePredictedActivityType() {
        // something for airplanes needs to go right here.
        
        var activityClassTopConfidenceVotes : [ActivityType: Float] = [:]
        for collection in self.sensorDataCollections {
            if let topPrediction = (collection as? SensorDataCollection)?.topActivityTypePrediction {
                var voteValue = topPrediction.confidence.floatValue
                let averageSpeed = collection.averageSpeed
                
                if averageSpeed < 0 {
                    // negative speed means location data wasn't good. count these votes for half
                    voteValue = voteValue/2
                } else {
                    // otherwise, we give zero or partial vote power depending on if the prediction had a reasonable speed
                    switch topPrediction.activityType {
                    case .Automotive, .Cycling, .Rail, .Bus where averageSpeed < 1:
                        voteValue = 0
                    case .Automotive where averageSpeed < 4.5:
                        voteValue = voteValue/3
                    case .Bus, .Rail where averageSpeed < 3.6:
                        voteValue = voteValue/3
                    case .Cycling where averageSpeed < 3:
                        voteValue = voteValue/3
                    case .Running where averageSpeed < 2.2:
                        voteValue = 0
                    case .Walking where averageSpeed > 3:
                        voteValue = 0
                    case .Stationary where averageSpeed > 1:
                        voteValue = 0
                    default:
                        break
                    }
                }
                
                let currentVote = activityClassTopConfidenceVotes[topPrediction.activityType] ?? 0
                activityClassTopConfidenceVotes[topPrediction.activityType] = currentVote + voteValue
            }
        }
        
        var topActivityType = ActivityType.Unknown
        var topVote: Float = 0
        for (activityType, vote) in activityClassTopConfidenceVotes {
            if vote > topVote {
                topActivityType = activityType
                topVote = vote
            }
        }
        
        self.activityType = topActivityType
    }
    
    func close(handler: ()->Void = {}) {
        if (self.isClosed == true) {
            handler()
            return
        }
        
        self.calculateAggregatePredictedActivityType()
        self.calculateLength()
        self.isClosed = true
        
        NSNotificationCenter.defaultCenter().postNotificationName("TripDidCloseOrCancelTrip", object: self)
        self.saveAndMarkDirty()
        handler()
    }
    
    func reopen(withPrototrip prototrip: Prototrip?) {
        self.isClosed = false
        self.locationsAreSynced = false
        self.simplifiedLocations = nil
        
        if let thePrototrip = prototrip {
            thePrototrip.moveSensorDataAndLocationsToTrip(self)
        }
    }
    
    func loadSummaryFromAPNDictionary(summary: [NSObject: AnyObject]) {
        if let climacon = summary["weatherEmoji"] as? String {
            self.climacon = climacon
        }
        
        if let startPlaceName = summary["startPlaceName"] as? String {
            self.startingPlacemarkName = startPlaceName
        }
        
        if let endPlaceName = summary["endPlaceName"] as? String {
            self.endingPlacemarkName = endPlaceName
        }
        
        if let rewardEmoji = summary["rewardEmoji"] as? String,
            rewardDescription = summary["rewardDescription"] as? String {
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
    
    func loadSummaryFromJSON(summary: [String: JSON]) {
        if let ready = summary["ready"]?.boolValue {
            self.summaryIsSynced = ready
        }
        
        if let climacon = summary["weatherEmoji"]?.string {
            self.climacon = climacon
        }
        
        if let startPlaceName = summary["startPlaceName"]?.string {
            self.startingPlacemarkName = startPlaceName
        }
        
        if let endPlaceName = summary["endPlaceName"]?.string {
            self.endingPlacemarkName = endPlaceName
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
            guard let length = self.length else {
                return 0.0
            }
            
            return (length.floatValue * 0.000621371)
        }
    }
    
    var lengthFeet : Float {
        get {
            guard let length = self.length else {
                return 0.0
            }
            
            return (length.floatValue * 3.28084)
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
    
    func sendTripCompletionNotificationLocally(clearRemoteMessage: Bool = false, forFutureDate scheduleDate: NSDate? = nil) {
        DDLogInfo("Sending notification…")
        
        self.cancelTripStateNotification(clearRemoteMessage)
        
        if (self.activityType == .Cycling) {
            // don't show a notification for anything but bike trips.
            self.currentStateNotification = UILocalNotification()
            self.currentStateNotification?.alertBody = self.notificationString()
            self.currentStateNotification?.soundName = UILocalNotificationDefaultSoundName
            self.currentStateNotification?.alertAction = "rate"
            self.currentStateNotification?.category = "RIDE_COMPLETION_CATEGORY"
            
            self.currentStateNotification?.userInfo = ["uuid" : self.uuid]
            
            if let date = scheduleDate {
                self.currentStateNotification?.fireDate = date
                UIApplication.sharedApplication().scheduleLocalNotification(self.currentStateNotification!)
            } else {
                // 1 second delay to avoid it being cleared at the end of the run loop by cancelTripStateNotification
                self.currentStateNotification?.fireDate = NSDate().secondsFrom(1)
                UIApplication.sharedApplication().scheduleLocalNotification(self.currentStateNotification!)
            }
        }
    }
    
    func notificationString()->String? {
        var message = ""
        
        if (self.startingPlacemarkName != nil && self.endingPlacemarkName != nil) {
            if (self.startingPlacemarkName == self.endingPlacemarkName) {
                message = String(format: "%@ %@ %.1f miles in %@.", self.climacon ?? "", self.activityType.emoji, self.lengthMiles, self.startingPlacemarkName)
            } else {
                message = String(format: "%@ %@ %.1f miles from %@ to %@.", self.climacon ?? "", self.activityType.emoji, self.lengthMiles, self.startingPlacemarkName, self.endingPlacemarkName)
            }
        } else if (self.startingPlacemarkName != nil) {
            message = String(format: "%@ %@ %.1f miles from %@.", self.climacon ?? "", self.activityType.emoji, self.lengthMiles, self.startingPlacemarkName)
        } else {
            message = String(format: "%@ %@ %.1f miles.", self.climacon ?? "", self.activityType.emoji, self.lengthMiles)
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
                message = String(format: "%@ %@ Rode %.1f miles in %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.lengthMiles, self.startingPlacemarkName)
            } else {
                message = String(format: "%@ %@ Rode %.1f miles from %@ to %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.lengthMiles, self.startingPlacemarkName, self.endingPlacemarkName)
            }
        } else if (self.startingPlacemarkName != nil) {
            message = String(format: "%@ %@ Rode %.1f miles from %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.lengthMiles, self.startingPlacemarkName)
        } else {
            message = String(format: "%@ %@ Rode %.1f miles with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.lengthMiles)
        }
        
        
        return message
    }
    
    var isFirstBikeTripToday: Bool {
        if let tripsToday = Trip.bikeTripsToday() {
            return tripsToday.contains(self) && tripsToday.count == 1
        }
        
        return false
    }
    
    func cancelTripStateNotification(clearRemoteMessage: Bool = false) {
        // clear any remote push notifications
        if clearRemoteMessage {
            UIApplication.sharedApplication().applicationIconBadgeNumber = 1
            UIApplication.sharedApplication().applicationIconBadgeNumber = 0
        }
        
        if (self.currentStateNotification != nil) {
            UIApplication.sharedApplication().cancelLocalNotification(self.currentStateNotification!)
            self.currentStateNotification = nil
        }
    }
    
    func accurateLocations()->[Location] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "trip == %@ AND horizontalAccuracy <= %f", self, Location.acceptableLocationAccuracy)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
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
        
        return results as! [Location]
    }
    
    func simplify(handler: ()->Void = {}) {
        let accurateLocs = self.accurateLocations()
        
        if (self.simplifiedLocations != nil) {
            for loc in self.simplifiedLocations.array {
                (loc as! Location).simplifiedInTrip = nil
            }
        }
        
        if (!self.isClosed || accurateLocs.count == 0) {
            handler()
            return
        }
        
        self.simplifyLocations(accurateLocs, episilon: simplificationEpisilon)
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
                counter += 1
            }
        } else {
            // trivial case: two points are more than episilon distance away.
            startLoc!.simplifiedInTrip = self
            endLoc!.simplifiedInTrip = self
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
        let part1 = lineStartPoint.longitude * (lineEndPoint.latitude - point.latitude)
        let part2 = lineEndPoint.longitude * (point.latitude - lineStartPoint.latitude)
        let part3 = point.longitude * (lineStartPoint.latitude - lineEndPoint.latitude)
        let area = 0.5 * abs(part1
                            + part2
                            + part3)
        
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
    
    func bestStartLocation() -> Location? {
        guard self.locations != nil && self.locations.count > 0 else {
            return nil
        }
        
        for loc in self.locations {
            if let location = loc as? Location where location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy {
                return location
            }
        }
        
        return self.locations.firstObject as? Location
    }
    
    func bestEndLocation() -> Location? {
        guard self.locations != nil && self.locations.count > 0 else {
            return nil
        }
        
        for loc in self.locations.reverse() {
            if let location = loc as? Location where location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy {
                return location
            }
        }
        
        return self.locations.lastObject as? Location
    }
    
    
    
    var startDate : NSDate {
        // don't use a geofenced location
        for loc in self.locations {
            if let location = loc as? Location where !location.isGeofencedLocation {
                if let date = location.date {
                    return date
                } else {
                    break
                }
            }
        }
        
        return self.creationDate
    }
    
    var endDate : NSDate {
        guard let loc = self.locations.lastObject as? Location,
            date = loc.date else {
            return self.creationDate
        }
        
        return date
    }
    
    var averageSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        for loc in self.locations.array {
            let location = loc as! Location
            if (location.speed!.doubleValue > 0 && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed!.doubleValue
            }
        }
        
        if (count == 0) {
            return 0
        }
        
        return sumSpeed/Double(count)
    }
}