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
import HealthKit
import UserNotifications
import MapboxStatic

@objc enum ActivityType : Int16 {
    case unknown = 0
    case running
    case cycling
    case automotive
    case walking
    case bus
    case rail
    case stationary
    case aviation
    
    static var count: Int { return Int(ActivityType.stationary.rawValue) + 1}
    
    var isMotorizedMode: Bool {
        get {
            return (self == .automotive || self == .bus || self == .rail)
        }
    }
    
    var emoji: String {
        get {
            var tripTypeString = ""
            switch self {
            case .unknown:
                tripTypeString = "❓"
            case .running:
                tripTypeString = "🏃"
            case .cycling:
                tripTypeString = "🚲"
            case .automotive:
                tripTypeString = "🚗"
            case .walking:
                tripTypeString = "🚶"
            case .bus:
                tripTypeString = "🚌"
            case .rail:
                tripTypeString = "🚈"
            case .stationary:
                tripTypeString = "💤"
            case .aviation:
                tripTypeString = "✈️"
            }
            
            return tripTypeString
        }
    }
    
    var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
    
    var noun: String {
        get {
            var tripTypeString = ""
            switch self {
            case .unknown:
                tripTypeString = "Unknown"
            case .running:
                tripTypeString = "Run"
            case .cycling:
                tripTypeString = "Bike Ride"
            case .automotive:
                tripTypeString = "Drive"
            case .walking:
                tripTypeString = "Walk"
            case .bus:
                tripTypeString = "Bus Ride"
            case .rail:
                tripTypeString = "Train Ride"
            case .stationary:
                tripTypeString = "Sitting"
            case .aviation:
                tripTypeString = "Flight"
            }
            
            return tripTypeString
        }
    }
}


enum RatingChoice: Int16 {
    case notSet = 0
    case good
    case bad
    case mixed
    
    var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
    
    var notificationActionIdentifier: String {
        get {
            switch self {
            case .bad:
                return "BAD_RIDE_IDENTIFIER"
            case .good:
                return "GOOD_RIDE_IDENTIFIER"
            case .mixed:
                return "MIXED_RIDE_IDENTIFIER"
            case .notSet:
                return ""
            }
        }
    }
}

enum RatingVersion: Int16 {
    case v1 = 0
    case v2beta
    
    var availableRatings: [Rating] {
        switch self {
        case .v1:
            return [Rating.init(choice: .bad, version: .v1), Rating.init(choice: .good, version: .v1)]
        case .v2beta:
            return [Rating.init(choice: .bad, version: .v2beta), Rating.init(choice: .mixed, version: .v2beta), Rating.init(choice: .good, version: .v2beta)]
        }
    }
    
    var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
}

extension Rating: Equatable {}
func ==(lhs: Rating, rhs: Rating) -> Bool {
    return lhs.choice == rhs.choice && lhs.version == rhs.version
}

struct Rating {
    private(set) var choice: RatingChoice
    private(set) var version: RatingVersion
    
    static func ratingWithCurrentVersion(_ choice: RatingChoice) -> Rating {
        return Rating(choice: choice, version: Profile.profile().ratingVersion)
    }
    
    init(choice: RatingChoice, version: RatingVersion) {
        self.choice = choice
        self.version = version
    }
    
    init(rating: Int16, version: Int16) {
        self.choice = RatingChoice(rawValue: rating) ?? RatingChoice.notSet
        self.version = RatingVersion(rawValue: version) ?? Profile.profile().ratingVersion
    }
    
    var emoji: String {
        get {
            switch self.choice {
            case .bad:
                return "😡"
            case .good:
                return "☺️"
            case .mixed:
                return "😕"
            case .notSet:
                return ""
            }
        }
    }
    
    var noun: String {
        get {
            switch self.version {
            case .v1:
                switch self.choice {
                case .bad:
                    return "Not Great"
                case .good:
                    return "Great"
                case .mixed:
                    return "Mixed"
                case .notSet:
                    return ""
                }
            case .v2beta:
                switch self.choice {
                case .bad:
                    return "Stressful"
                case .good:
                    return "Chill"
                case .mixed:
                    return "Mixed"
                case .notSet:
                    return ""
                }
            }
        }
    }
}

class Trip : NSManagedObject {
    let simplificationEpisilon: CLLocationDistance = 0.00005
    
    private struct Static {
        static var timeFormatter : DateFormatter!
        static var sectionDateFormatter : DateFormatter!
    }
    
    class var sectionDateFormatter : DateFormatter {
        get {
            if (Static.sectionDateFormatter == nil) {
                Static.sectionDateFormatter = DateFormatter()
                Static.sectionDateFormatter.locale = Locale.current
                Static.sectionDateFormatter.dateFormat = "yyyy-MM-dd"
            }
            
            return Static.sectionDateFormatter
        }
    }
    
    class var timeDateFormatter : DateFormatter {
        get {
            if (Static.timeFormatter == nil) {
                Static.timeFormatter = DateFormatter()
                Static.timeFormatter.locale = Locale.current
                Static.timeFormatter.dateFormat = "h:mma"
                Static.timeFormatter.amSymbol = (Static.timeFormatter.amSymbol as NSString).lowercased
                Static.timeFormatter.pmSymbol = (Static.timeFormatter.pmSymbol as NSString).lowercased
            }
            
            return Static.timeFormatter
        }
    }
    
    private var currentStateNotification : UILocalNotification? = nil
        
    @NSManaged var startingPlacemarkName : String?
    @NSManaged var endingPlacemarkName : String?
    var activityType : ActivityType {
        get {
            if let num = (self.primitiveValue(forKey: "activityType") as? NSNumber),
            let activityType = ActivityType(rawValue: num.int16Value) {
                return activityType
            }
            
            return .unknown
        }
        set {
            let oldValue = self.activityType
            
            self.willChangeValue(forKey: "activityType")
            self.setPrimitiveValue(NSNumber(value: newValue.rawValue as Int16), forKey: "activityType")
            self.didChangeValue(forKey: "activityType")
            
            if oldValue != newValue {
                if self.isClosed {
                    self.sectionIdentifier = self.sectionIdentifierString()
                }

                DispatchQueue.main.async {
                    // newly closed trips should be synced to healthkit
                    if (HealthKitManager.hasStarted) {
                        self.isSavedToHealthKit = false
                        HealthKitManager.shared.saveOrUpdateTrip(self)
                    }
                }
            }
        }
    }
    
    @NSManaged var ratingVersion : NSNumber
    var rating: Rating {
        get {
            if let numRating = (self.primitiveValue(forKey: "rating") as? NSNumber),
                let numVersion = (self.primitiveValue(forKey: "ratingVersion") as? NSNumber) {
                return  Rating(rating: numRating.int16Value, version: numVersion.int16Value)
            }
            
            return Rating.ratingWithCurrentVersion(RatingChoice.notSet)
        }
        set {
            self.willChangeValue(forKey: "rating")
            self.setPrimitiveValue(NSNumber(value: newValue.choice.rawValue as Int16), forKey: "rating")
            self.didChangeValue(forKey: "rating")
            
            self.willChangeValue(forKey: "ratingVersion")
            self.setPrimitiveValue(NSNumber(value: newValue.version.rawValue as Int16), forKey: "ratingVersion")
            self.didChangeValue(forKey: "ratingVersion")
        }
    }
    
    @NSManaged var batteryAtEnd : NSNumber?
    @NSManaged var batteryAtStart : NSNumber?
    @NSManaged var sensorDataCollections : NSOrderedSet!
    @NSManaged var locations : NSOrderedSet!
    @NSManaged var incidents : NSOrderedSet!
    @NSManaged var tripRewards : NSOrderedSet!
    @NSManaged var hasSmoothed : Bool
    @NSManaged var isSynced : Bool
    @NSManaged var isSavedToHealthKit : Bool
    @NSManaged var locationsAreSynced : Bool
    @NSManaged var summaryIsSynced : Bool
    @NSManaged var locationsNotYetDownloaded : Bool
    @NSManaged var healthKitUuid : String?
    var isBeingSavedToHealthKit: Bool = false
    var workoutObject: HKWorkout? = nil
    
    var isClosed : Bool {
        get {
            if let num = (self.primitiveValue(forKey: "isClosed") as? NSNumber) {
                return num.boolValue
            }
            return false
        }
        set {
            let oldValue = self.isClosed
            
            self.willChangeValue(forKey: "isClosed")
            self.setPrimitiveValue(nil, forKey: "sectionIdentifier")
            self.setPrimitiveValue(NSNumber(value: newValue as Bool), forKey: "isClosed")
            self.didChangeValue(forKey: "isClosed")
            
            if newValue {
                if !oldValue {
                    DispatchQueue.main.async {
                        // newly closed trips should be synced to healthkit
                        if (HealthKitManager.hasStarted) {
                            self.isSavedToHealthKit = false
                            HealthKitManager.shared.saveOrUpdateTrip(self)
                        }
                    }
                }
                
                self.sectionIdentifier = self.sectionIdentifierString()
            } else {
                self.sectionIdentifier = Trip.inProgressSectionIdentifierSuffix() // force it to sort at the top of a reverse-sorted list
            }
        }
    }
    @NSManaged var uuid : String!
    @NSManaged var creationDate : Date!
    @NSManaged var length : Meters
    var inProgressLength : Meters = 0
    private var lastInProgressLocation : Location? = nil
    @NSManaged var climacon : String?
    var sectionIdentifier : String? {
        get {
            return self.primitiveValue(forKey: "sectionIdentifier") as? String
        }
        set {
            if (newValue != self.sectionIdentifier) {
                // work around dumb bug
                // https://developer.apple.com/library/prerelease/content/releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/index.html
                didChangeSection = true
            }
            self.willChangeValue(forKey: "sectionIdentifier")
            self.setPrimitiveValue(newValue, forKey: "sectionIdentifier")
            self.didChangeValue(forKey: "sectionIdentifier")
        }
    }
    var didChangeSection : Bool = false
    @NSManaged var simplifiedLocations : NSOrderedSet!
    
    class func cyclingSectionIdentifierSuffix()->String {
        return "yy"
    }
    
    class func inProgressSectionIdentifierSuffix()->String {
        return "z"
    }
    
    private func sectionIdentifierString()->String {
        return  Trip.sectionDateFormatter.string(from: self.creationDate) + (self.activityType == .cycling ? Trip.cyclingSectionIdentifierSuffix() : "")
    }
    
    class func reloadSectionIdentifiers(_ exhaustively: Bool = false) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        if !exhaustively {
            fetchedRequest.predicate = NSPredicate(format: "sectionIdentifier == nil")
        }
        
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        guard let trips = results as? [Trip] else {
            return
        }
        
        for trip in trips {
            trip.sectionIdentifier = trip.sectionIdentifierString()
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Trip", in: context)!, insertInto: context)
    }
    
    convenience init(prototrip: Prototrip?) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Trip", in: context)!, insertInto: context)
        
        if let thePrototrip = prototrip {
            self.creationDate = thePrototrip.creationDate as Date!
            self.batteryAtStart = thePrototrip.batteryAtStart
            thePrototrip.moveSensorDataAndLocationsToTrip(self)
        }
    }
    
    class func tripCount() -> Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class func allBikeTrips(_ limit: Int = 0) -> [AnyObject] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.cycling.rawValue)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        if (results == nil) {
            return []
        }
        
        return results!
    }
    
    class func allTrips(_ limit: Int = 0) -> [AnyObject] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        if (results == nil) {
            return []
        }
        
        return results!
    }
    
    class func allTripsWithUUIDs(_ limit: Int = 0) -> [AnyObject] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "uuid != \"\" AND uuid != nil")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.predicate = NSPredicate(format: "creationDate > %@", Date().daysFrom(-7) as CVarArg)
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return []
        }
        
        return results!
    }
    
    class func tripWithUUID(_ uuid: String) -> Trip! {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "uuid == [c] %@", uuid)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func tripWithCreationDate(_ creationDate: Date) -> Trip! {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        
        // fudge the creation date by a second, just in case
        fetchedRequest.predicate = NSPredicate(format: "(creationDate >= %@) AND (creationDate =< %@)", creationDate.secondsFrom(-1) as CVarArg, creationDate.secondsFrom(1) as CVarArg)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.cycling.rawValue, Date().beginingOfDay() as CVarArg)
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.cycling.rawValue)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        let closedPredicate = NSPredicate(format: "isClosed == NO")
        fetchedRequest.predicate = closedPredicate
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        let predicate = NSPredicate(format: "activityType == %i", ActivityType.unknown.rawValue)
        fetchedRequest.predicate = predicate
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        let predicate = NSPredicate(format: "climacon == nil OR climacon == ''")
        fetchedRequest.predicate = predicate
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        let closedPredicate = NSPredicate(format: "isClosed == YES")
        let syncedPredicate = NSPredicate(format: "isSynced == NO")
        let locationsAreSyncedPredicate = NSPredicate(format: "locationsAreSynced == NO")
        let syncedCompoundPredicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.or, subpredicates: [locationsAreSyncedPredicate, syncedPredicate])

        fetchedRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [closedPredicate, syncedCompoundPredicate])
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if (results == nil || results!.count == 0) {
            return nil
        }
        
        return (results!.first as! Trip)
    }
    
    class func nextUnsyncedSummaryTrip() -> Trip? {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        let closedPredicate = NSPredicate(format: "isClosed == YES")
        let syncedPredicate = NSPredicate(format: "summaryIsSynced == NO")
        
        fetchedRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [closedPredicate, syncedPredicate])
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.cycling.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfAutomotiveTrips : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.automotive.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfBusTrips : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i", ActivityType.bus.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfCycledTripsLast30Days : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.cycling.rawValue, Date().daysFrom(-30) as CVarArg)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfAutomotiveTripsLast30Days : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.automotive.rawValue, Date().daysFrom(-30) as CVarArg)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfBusTripsLast30Days : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND creationDate > %@", ActivityType.bus.rawValue, Date().daysFrom(-30) as CVarArg)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfRewardedTrips : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "tripRewards.@count > 0")
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfBadTrips : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND rating == %i", ActivityType.cycling.rawValue, RatingChoice.bad.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = Date()
        self.generateUUID()
        self.sectionIdentifier = "z" // has to be non-nil or it will not show up in the list
    }
    
    override func awakeFromFetch() {
        super.awakeFromFetch()
        
        // should never happen, but some legacy clients may find themselves in this state
        if (self.uuid == nil) {
            self.generateUUID()
        }
    }
    
    func generateUUID() {
        self.uuid = UUID().uuidString
    }
    
    func batteryLifeUsed() -> Int16 {
        guard let batteryAtStart = self.batteryAtStart, let  batteryAtEnd = self.batteryAtEnd else {
            return 0
        }
        
        if (batteryAtStart.int16Value == 0 || batteryAtEnd.int16Value == 0) {
            return 0
        }
        
        
        if (batteryAtStart.int16Value < batteryAtEnd.int16Value) {
            DDLogVerbose("Negative battery life used?")
            return 0
        }
        
        return (batteryAtStart.int16Value - batteryAtEnd.int16Value)
    }
    
    func duration() -> TimeInterval {
        return fabs(self.startDate.timeIntervalSince(self.endDate))
    }
    
    func locationWithCoordinate(_ coordinate: CLLocationCoordinate2D) -> Location {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let location = Location.init(entity: NSEntityDescription.entity(forEntityName: "Location", in: context)!, insertInto: context)
        
        location.course = (self.locations.firstObject! as AnyObject).course
        location.horizontalAccuracy = NSNumber(value: 0.0 as Double)
        location.latitude = NSNumber(value: coordinate.latitude as Double)
        location.longitude = NSNumber(value: coordinate.longitude as Double)
        location.speed = NSNumber(value: -1.0 as Double)
        location.isSmoothedLocation = true
        
        return location
    }
    
    func undoSmoothWithCompletionHandler(_ handler: ()->Void) {
        if (self.locations.count < 2 || !self.hasSmoothed) {
            return
        }
        
        DDLogVerbose("De-Smoothing route…")
        
        for element in self.locations.array {
            let location = element as! Location
            if location.isSmoothedLocation {
                location.trip = nil
                location.managedObjectContext?.delete(location)
            }
        }
        
        DDLogVerbose("Route de-smoothed!")
        
        self.hasSmoothed = false
        
        handler()
    }
    
    func cancel() {
        CoreDataManager.shared.currentManagedObjectContext().delete(self)
        CoreDataManager.shared.saveContext()
        NotificationCenter.default.post(name: Notification.Name(rawValue: "TripDidCloseOrCancelTrip"), object: self)
    }
    
    func saveAndMarkDirty() {
        if (self.hasChanges && self.isSynced) {
            self.isSynced = false
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    private func calculateLength()-> Void {
        var length : CLLocationDistance = 0
        var lastLocation : CLLocation! = nil
        for location in self.usableLocationsForSimplification() {
            let cllocation = location.clLocation()
            if (lastLocation == nil) {
                lastLocation = cllocation
                continue
            }
            length += lastLocation!.distance(from: cllocation)
            lastLocation = cllocation
        }
        
        self.length = Float(length)
    }
    
    func updateInProgressLength()->Bool {
        let locSize = self.locations.count
        if (locSize % 10 == 0) {
            // every 10
            if let thisLoc = self.locations.lastObject as? Location {
                if let lasLoc = self.lastInProgressLocation {
                    let thiscllocation = thisLoc.clLocation()
                    let lastcllocation = lasLoc.clLocation()

                    inProgressLength += Float(lastcllocation.distance(from: thiscllocation))
                    lastInProgressLocation = thisLoc
                    return true
                } else {
                    lastInProgressLocation = thisLoc
                }
            }
        }
        
        return false
    }
    
    func calculateAggregatePredictedActivityType() {
        // something for airplanes needs to go right here.
    
        if self.aggregateRoughtSpeed > 75.0 {
            // special case for air travel. just look at the speed.
            self.activityType = .aviation

            return
        }
        
        var activityClassTopConfidenceVotes : [ActivityType: Float] = [:]
        for collection in self.sensorDataCollections {
            if let topPrediction = (collection as? SensorDataCollection)?.topActivityTypePrediction {
                var voteValue = powf(topPrediction.confidence.floatValue, 1.5) // make the difference bigger
                let averageMovingSpeed = (collection as AnyObject).averageMovingSpeed as Double
                let averageSpeed = (collection as AnyObject).averageSpeed as Double
                
                if averageSpeed < 0 {
                    // negative speed means location data wasn't good. count these votes for half
                    voteValue = voteValue/2
                } else {
                    // otherwise, we give zero or partial vote power depending on if the prediction had a reasonable speed
                    switch topPrediction.activityType {
                    case .automotive where averageSpeed < 1, .cycling where averageSpeed < 1, .rail where averageSpeed < 1, .bus where averageSpeed < 1:
                        voteValue = 0
                    case .automotive where averageMovingSpeed < 3.6:
                        voteValue = voteValue/3
                    case .bus where averageMovingSpeed < 3.6:
                        voteValue = voteValue/3
                    case .rail where averageMovingSpeed < 3.6:
                        voteValue = voteValue/3
                    case .cycling where averageMovingSpeed < 3 || averageMovingSpeed > 13.4:
                        voteValue = voteValue/3
                    case .running where averageMovingSpeed < 2.2:
                        voteValue = 0
                    case .walking where averageSpeed > 3:
                        voteValue = 0
                    case .stationary where averageSpeed > 1 || self.length > 100: // don't include stationary unless the trip is essentially phantom
                        voteValue = 0
                    default:
                        break
                    }
                }
                
                let currentVote = activityClassTopConfidenceVotes[topPrediction.activityType] ?? 0
                activityClassTopConfidenceVotes[topPrediction.activityType] = currentVote + voteValue
            }
        }
        
        var topActivityType = ActivityType.unknown
        var topVote: Float = 0
        for (activityType, vote) in activityClassTopConfidenceVotes {
            if vote > topVote {
                topActivityType = activityType
                topVote = vote
            }
        }
        
        if topVote == 0 {
            DDLogInfo("No sensor collections voted! Falling back on speed…")
            // if no one voted, fall back on speeds
            if (averageSpeed >= 8) {
                topActivityType = .automotive
            } else if (averageSpeed >= 3) {
                topActivityType = .cycling
            } else {
                topActivityType = .walking
            }
        } else if topActivityType == .cycling && self.averageMovingSpeed <= 2 && self.length < 800 && topVote < 0.7 {
            // https://github.com/KnockSoftware/Ride/issues/243
            topActivityType = .walking
        }
        
        self.activityType = topActivityType
    }
    
    var debugPredictionsDescription: String {
        return sensorDataCollections.reduce("", {sum, prediction in sum + (prediction as! SensorDataCollection).debugDescription + "\r"})
    }
    
    func close(_ handler: ()->Void = {}) {
        if (self.isClosed == true) {
            handler()
            return
        }
        
        self.calculateAggregatePredictedActivityType()
        self.calculateLength()
        self.isClosed = true
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "TripDidCloseOrCancelTrip"), object: self)
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
        
        CoreDataManager.shared.saveContext()
    }
    
    func loadSummaryFromAPNDictionary(_ summary: [AnyHashable: Any]) {
        self.summaryIsSynced = true

        if let climacon = summary["weatherEmoji"] as? String {
            self.climacon = climacon
        }
        
        if let startPlaceName = summary["startPlaceName"] as? String {
            self.startingPlacemarkName = startPlaceName
        }
        
        if let endPlaceName = summary["endPlaceName"] as? String {
            self.endingPlacemarkName = endPlaceName
        }
        
        for reward in self.tripRewards.array as! [TripReward] {
            self.managedObjectContext?.delete(reward)
        }
        
        if let rewardEmoji = summary["rewardEmoji"] as? String,
            let rewardDescription = summary["rewardDescription"] as? String, rewardDescription != "" && rewardEmoji != "" {
            let _ = TripReward(trip: self, emoji: rewardEmoji, descriptionText: rewardDescription)
        } else if let rewards = summary["rewards"] as? [AnyObject] {
            for reward in rewards {
                if let dict = reward as? [String: Any], let reward = TripReward.reward(dictionary: dict) {
                    reward.trip = self
                }
            }
        }
    }
    
    func loadSummaryFromJSON(_ summary: [String: JSON]) {
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
        
        for reward in self.tripRewards.array as! [TripReward] {
            self.managedObjectContext?.delete(reward)
        }
        
        if let rewardEmoji = summary["rewardEmoji"]?.string,
            let rewardDescription = summary["rewardDescription"]?.string, rewardDescription != "" && rewardEmoji != "" {
            let _ = TripReward(trip: self, emoji: rewardEmoji, descriptionText: rewardDescription)
        } else if let rewards = summary["rewards"]?.array {
            for reward in rewards {
                if let dict = reward.dictionaryObject, let reward = TripReward.reward(dictionary: dict) {
                    reward.trip = self
                }
            }
        }
    }

    func closestLocationToCoordinate(_ coordinate: CLLocationCoordinate2D)->Location! {
        let targetLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    
        var closestLocation : Location? = nil
        var closestDisance = CLLocationDistanceMax
        for loc in self.locations {
            let location = loc as! Location
            let locDistance = targetLoc.distance(from: location.clLocation())
            if (locDistance < closestDisance) {
                closestDisance = locDistance
                closestLocation = location
            }
        }
        
        return closestLocation
    }
    
    @available(iOS 10.0, *)
    private func createRouteMapAttachement(_ handler: @escaping (_ attachment: UNNotificationAttachment?)->Void) {
        if let locations = self.simplifiedLocations?.array as? [Location], locations.count > 0 {
            let width = UIScreen.main.bounds.width
            let height = UIScreen.main.bounds.height - 370 // make sure that all three buttons fit on the screen without scrolling
            
            var coords = [CLLocationCoordinate2D]()

            
            for loc in locations {
                coords.append(loc.coordinate())
            }
            
            let path = Path(
                coordinates: coords
            )
            path.strokeWidth = 18
            path.strokeColor = {
                if(self.rating.choice == RatingChoice.good) {
                    return ColorPallete.shared.goodGreen
                } else if(self.rating.choice == RatingChoice.bad) {
                    return ColorPallete.shared.badRed
                } else {
                    return ColorPallete.shared.unknownGrey
                }
            }()
            path.fillColor = UIColor.clear
            path.fillOpacity = 0.0
            
            let backingPath = Path(
                coordinates: coords
            )
            backingPath.strokeWidth = 24
            backingPath.strokeColor = UIColor(red: 115/255, green: 123/255, blue: 102/255, alpha: 1.0)
            backingPath.fillColor = UIColor.clear
            backingPath.fillOpacity = 0.0
            
            let startMarker = CustomMarker(
                coordinate: locations.first!.coordinate(),
                url: URL(string: "https://s3-us-west-2.amazonaws.com/ridereport/pinGreen%402x.png")!
            )
            
            let endMarker = CustomMarker(
                coordinate: locations.last!.coordinate(),
                url: URL(string: "https://s3-us-west-2.amazonaws.com/ridereport/pinRed%402x.png")!
            )
            
            let options = SnapshotOptions(
                mapIdentifiers: ["quicklywilliam.2onj5igf"],
                size: CGSize(width: width, height: height))
            options.centerCoordinate = nil
            options.overlays = [backingPath, path, startMarker, endMarker]
            let snapshot = Snapshot(
                options: options,
                accessToken: "pk.eyJ1IjoicXVpY2tseXdpbGxpYW0iLCJhIjoibmZ3UkZpayJ9.8gNggPy6H5dpzf4Sph4-sA")
            
            let filePath = NSTemporaryDirectory() + (self.uuid + ".png")
            
            var taskFinished = false
            
            let task = snapshot.image(completionHandler: { (image, error) in
                if (taskFinished) {
                    return
                }
                
                taskFinished = true
                
                if let image = image {
                    let data = UIImagePNGRepresentation(image)
                    try? data?.write(to: URL(fileURLWithPath: filePath), options: .atomic)
                    if let attachment = try? UNNotificationAttachment(identifier: "map", url: NSURL(fileURLWithPath: filePath) as URL, options: [UNNotificationAttachmentOptionsThumbnailClippingRectKey:  CGRect(x: 0.5, y: 0.5, width: 1, height: 1).dictionaryRepresentation]) {
                        handler(attachment)
                        return
                    }
                }
                
                handler(nil)
            })
            
            // timeout after two seconds, runs on same (main) thread as snapshot.image callback
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                if (!taskFinished) {
                    taskFinished = true
                    task.cancel()
                    handler(nil)
                }
            })
        } else {
            handler(nil)
        }
    }
    
    func sendTripCompletionNotificationLocally(_ clearRemoteMessage: Bool = false, secondsFromNow: TimeInterval = 0) {
        DDLogInfo("Sending notification…")
        
        self.cancelTripStateNotification(clearRemoteMessage)
        
        if (self.activityType == .cycling) {
            // don't show a notification for anything but bike trips.
            
            var userInfo = ["uuid" : self.uuid, "rideDescription" : self.displayString(), "rideEmoji" : self.climacon ?? self.activityType.emoji]
            if let reward = self.tripRewards.firstObject as? TripReward {
                userInfo["rewardEmoji"] = reward.displaySafeEmoji
                userInfo["rewardDescription"] = reward.descriptionText
            }
            
            if #available(iOS 10.0, *) {
                let backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    DDLogInfo("Schedule trip notification background task expired!")
                })
                
                let attachmentCallbackHandler = { (attachment: UNNotificationAttachment?) in
                    let content = UNMutableNotificationContent()
                    content.categoryIdentifier = "RIDE_COMPLETION_CATEGORY"
                    content.sound = UNNotificationSound(named: "bell.aiff")
                    content.body = self.notificationString()
                    content.userInfo = userInfo
                    if let attachment = attachment {
                        content.attachments = [attachment]
                    }
                    
                    // 1 second delay to avoid it being cleared at the end of the run loop by cancelTripStateNotification
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsFromNow > 0 ? secondsFromNow : 1, repeats: false)
                    let requestIdentifier = "sampleRequest"
                    let request = UNNotificationRequest(identifier: requestIdentifier,
                                                        content: content,
                                                        trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { (error) in
                        DispatchQueue.main.async {
                            if (backgroundTaskID != UIBackgroundTaskInvalid) {
                                DDLogInfo("Ending trip notification background task!")
                                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                            }
                        }
                    }
                }
                
                guard let locs = self.simplifiedLocations, locs.count > 0 else {
                    self.simplify({
                        self.createRouteMapAttachement(attachmentCallbackHandler)
                    })
                    return
                }
                
                createRouteMapAttachement(attachmentCallbackHandler)
            } else {
                self.currentStateNotification = UILocalNotification()
                self.currentStateNotification?.alertBody = self.notificationString()
                self.currentStateNotification?.soundName = "bell.aiff"
                self.currentStateNotification?.alertAction = "rate"
                self.currentStateNotification?.category = "RIDE_COMPLETION_CATEGORY"
                self.currentStateNotification?.userInfo = userInfo
                
                if secondsFromNow > 0 {
                    self.currentStateNotification?.fireDate = Date().secondsFrom(Int(secondsFromNow))
                    UIApplication.shared.scheduleLocalNotification(self.currentStateNotification!)
                } else {
                    // 1 second delay to avoid it being cleared at the end of the run loop by cancelTripStateNotification
                    self.currentStateNotification?.fireDate = Date().secondsFrom(1)
                    UIApplication.shared.scheduleLocalNotification(self.currentStateNotification!)
                }
            }
        }
    }
    
    var areaDescriptionString: String {
        get {
            var areaDescriptionString = ""

            if let startingPlacemarkName = self.startingPlacemarkName, let endingPlacemarkName = self.endingPlacemarkName {
                if (self.startingPlacemarkName == self.endingPlacemarkName) {
                    areaDescriptionString = String(format: "in %@", startingPlacemarkName)
                } else {
                    areaDescriptionString = String(format: "from %@ to %@", startingPlacemarkName, endingPlacemarkName)
                }
            } else if let startingPlacemarkName = self.startingPlacemarkName {
                areaDescriptionString = String(format: "from %@", startingPlacemarkName)
            } else if let endingPlacemarkName = self.endingPlacemarkName {
                areaDescriptionString = String(format: "to %@", endingPlacemarkName)
            }
            
            return areaDescriptionString
        }
    }
    
    func notificationString()->String {
        var message = ""
        
        message = String(format: "%@ %@ %@%@.", self.climacon ?? "", self.activityType.emoji, self.length.distanceString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        if let reward = self.tripRewards.firstObject as? TripReward {
                message += (" " + reward.displaySafeEmoji + " " + reward.descriptionText)
        }
        
        return message
    }
    
    func timeString()->String {
        var timeString = ""

        if (self.creationDate != nil) {
            timeString = String(format: "%@", Trip.timeDateFormatter.string(from: self.creationDate))
        }
        
        return timeString
    }
    
    func displayString()->String {
        let areaDescriptionString = self.areaDescriptionString
        let description = String(format: "%@%@.", self.length.distanceString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        return description
    }
    
    func displayStringWithTime()->String {
        let areaDescriptionString = self.areaDescriptionString
        let description = String(format: "%@ for %@%@.", self.timeString(), self.length.distanceString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        return description
    }
    
    func fullDisplayString()->String {
        let areaDescriptionString = self.areaDescriptionString
        var description = String(format: "%@ %@%@.", self.climacon ?? "", self.length.distanceString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        for reward in self.tripRewards.array as! [TripReward] {
            description += ("\n\n" + reward.displaySafeEmoji + " " + reward.descriptionText)
        }
        
        return description
    }
    
    func shareString()->String {
        var message = ""
        
        if let startingPlacemarkName = self.startingPlacemarkName, let endingPlacemarkName = self.endingPlacemarkName {
            if (self.startingPlacemarkName == self.endingPlacemarkName) {
                message = String(format: "%@ %@ Rode %@ in %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.length.distanceString(), startingPlacemarkName)
            } else {
                message = String(format: "%@ %@ Rode %@ from %@ to %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.length.distanceString(), startingPlacemarkName, endingPlacemarkName)
            }
        } else if let startingPlacemarkName = self.startingPlacemarkName {
            message = String(format: "%@ %@ Rode %@ from %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.length.distanceString(), startingPlacemarkName)
        } else if let endingPlacemarkName = self.endingPlacemarkName {
            message = String(format: "%@ %@ Rode %@ to %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.length.distanceString(), endingPlacemarkName)
        } else {
            message = String(format: "%@ %@ Rode %@ with @RideReportApp!", self.climacon ?? "", self.activityType.emoji, self.length.distanceString())
        }
        
        
        return message
    }
    
    var isFirstBikeTripToday: Bool {
        if let tripsToday = Trip.bikeTripsToday() {
            return tripsToday.contains(self) && tripsToday.count == 1
        }
        
        return false
    }

    func cancelTripStateNotification(_ clearRemoteMessage: Bool = false) {
        // clear any remote push notifications
        if clearRemoteMessage {
            UIApplication.shared.applicationIconBadgeNumber = 1
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        if (self.currentStateNotification != nil) {
            UIApplication.shared.cancelLocalNotification(self.currentStateNotification!)
            self.currentStateNotification = nil
        }
    }
    
    private func usableLocationsForSimplification()->[Location] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "trip == %@ AND (horizontalAccuracy <= %f OR isGeofencedLocation == YES)", self, Location.acceptableLocationAccuracy)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        if (results == nil) {
            return []
        }
        
        return results as! [Location]
    }
    
    func simplify(_ handler: ()->Void = {}) {
        let accurateLocs = self.usableLocationsForSimplification()
        
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
        CoreDataManager.shared.saveContext()
        handler()
    }
    
    // Ramer–Douglas–Peucker geometric simplication algorithm
    func simplifyLocations(_ locations: [Location], episilon : CLLocationDegrees) {
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
    
    private func shortestDistanceFromLineToPoint(_ lineStartPoint: CLLocationCoordinate2D, lineEndPoint: CLLocationCoordinate2D, point: CLLocationCoordinate2D)->CLLocationDegrees {
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
    
    func smoothIfNeeded(_ handler: @escaping ()->Void) {
        if (self.locations.count < 2 || self.hasSmoothed) {
            return
        }
        
        DDLogVerbose("Smoothing route…")
        
        self.hasSmoothed = true
        
        let location0 = self.locations.firstObject as! Location
        let location1 = self.locations.object(at: 1) as! Location
        
        let request = MKDirectionsRequest()
        request.source = (location0 as Location).mapItem()
        request.destination = (location1 as Location).mapItem()
        request.transportType = MKDirectionsTransportType.walking
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        directions.calculate { (directionsResponse, error) -> Void in
            if (error == nil) {
                let route : MKRoute = directionsResponse!.routes.first!
                let pointCount = route.polyline.pointCount
                var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
                route.polyline.getCoordinates(&coords, range: NSMakeRange(0, pointCount))
                let mutableLocations = self.locations.mutableCopy() as! NSMutableOrderedSet
                for index in 0..<pointCount {
                    let location = self.locationWithCoordinate(coords[index])
                    location.date = location0.date
                    location.trip = self
                    mutableLocations.insert(location, at: 1+index)
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
        let loc = self.locations.sortedArray(using: [sortDescriptor]).first as! Location
        return loc
    }
    
    func bestStartLocation() -> Location? {
        guard self.locations != nil && self.locations.count > 0 else {
            return nil
        }
        
        for loc in self.locations {
            if let location = loc as? Location, location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy {
                return location
            }
        }
        
        return self.locations.firstObject as? Location
    }
    
    func bestEndLocation() -> Location? {
        guard self.locations != nil && self.locations.count > 0 else {
            return nil
        }
        
        for loc in self.locations.reversed() {
            if let location = loc as? Location, location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy {
                return location
            }
        }
        
        return self.locations.lastObject as? Location
    }
    
    
    
    var startDate : Date {
        // don't use a geofenced location
        for loc in self.locations {
            if let location = loc as? Location, !location.isGeofencedLocation {
                if let date = location.date {
                    return date as Date
                } else {
                    break
                }
            }
        }
        
        return self.creationDate
    }
    
    var endDate : Date {
        guard let loc = self.locations.lastObject as? Location,
            let date = loc.date else {
            return self.creationDate
        }
        
        return date as Date
    }
    
    var aggregateRoughtSpeed: CLLocationSpeed {
        guard let startLoc = self.locations.firstObject as? Location, let endLoc = self.locations.lastObject as? Location,
        let startDate = startLoc.date, let endDate = endLoc.date else {
            return 0.0
        }
        
        let distance = startLoc.clLocation().distance(from: endLoc.clLocation())
        let time = endDate.timeIntervalSince(startDate as Date)
        
        return distance/time
    }
    
    var averageBikingSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        for loc in self.locations.array {
            let location = loc as! Location
            if (location.speed!.doubleValue > 1.0 && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed!.doubleValue
            }
        }
        
        if (count == 0) {
            return 0
        }
        
        return sumSpeed/Double(count)
    }
    
    var averageMovingSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        for loc in self.locations.array {
            let location = loc as! Location
            if (location.speed!.doubleValue > Location.minimumMovingSpeed && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed!.doubleValue
            }
        }
        
        if (count == 0) {
            return 0
        }
        
        return sumSpeed/Double(count)
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
