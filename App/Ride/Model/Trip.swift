//
//  Trip.swift
//  Ride Report
//
//  Created by William Henderson on 10/29/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON
import RouteRecorder
import CoreData
import CoreLocation
import CoreMotion
import MapKit
import HealthKit
import UserNotifications
import CocoaLumberjack

public class  Trip: NSManagedObject {
    private var currentStateNotification : UILocalNotification? = nil
    
    var isBeingSavedToHealthKit: Bool = false
    var workoutObject: HKWorkout? = nil
    var wasStoppedManually : Bool = false
    
    public var route: Route? {
        get {
            return Route.findRoute(withUUID: self.uuid)
        }
    }
    
    
    private struct Static {
        static var timeFormatter : DateFormatter!
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
    
    var startDate : Date {
        get {
            return self.primitiveValue(forKey: "startDate") as! Date
        }
        set {
            let oldValue = self.primitiveValue(forKey: "startDate") as? Date // could be nil if entity is new
            
            self.willChangeValue(forKey: "startDate")
            self.setPrimitiveValue(newValue, forKey: "startDate")
            self.didChangeValue(forKey: "startDate")
            
            if (newValue != oldValue || (self.bikeTripOfTripsListRow == nil && self.otherTripOfTripsListRow == nil)) {
                updateTripListRow()
            }
        }
    }
    
    var activityType : ActivityType {
        get {
            return ActivityType(rawValue: self.activityTypeInteger) ?? ActivityType.unknown
        }
        set {
            let oldValue = self.activityType
            
            self.activityTypeInteger = newValue.rawValue
            
            if oldValue != newValue || (self.bikeTripOfTripsListRow == nil && self.otherTripOfTripsListRow == nil) {
                self.updateTripListRow()

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
    
    private func updateTripListRow() {
        let section = TripsListSection.section(forTrip: self)
        
        if activityType == .cycling {
            self.otherTripOfTripsListRow = nil
            
            if let row = self.bikeTripOfTripsListRow {
                row.updateSortName()
                row.section = section
            } else {
                let row = TripsListRow()
                row.bikeTrip = self
                row.updateSortName()
                row.section = section
            }
        } else {
            self.bikeTripOfTripsListRow = nil
            var row: TripsListRow! = section.otherTripsRow
            
            if row == nil || !row.isOtherTripsRow {
                row = TripsListRow()
                row.isOtherTripsRow = true
                row.updateSortName()
                row.section = section
                section.otherTripsRow = row
            }
            self.otherTripOfTripsListRow = row
        }
    }
    
    var rating: Rating {
        get {
            return Rating(rating: self.ratingInteger, version: self.ratingVersion)
        }
        set {
            self.ratingInteger = newValue.choice.rawValue
            self.ratingVersion = newValue.version.rawValue
        }
    }
    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Trip", in: context)!, insertInto: context)
    }
    
    class func findAndUpdateOrCreateTrip(withRoute route: Route) -> Trip {
        var trip: Trip! = Trip.tripWithUUID(route.uuid)
            
        if (trip == nil) {
            let context = CoreDataManager.shared.currentManagedObjectContext()
            trip = Trip(entity: NSEntityDescription.entity(forEntityName: "Trip", in: context)!, insertInto: context)
            trip.uuid = route.uuid
        }
        
        trip.startDate = route.startDate
        trip.endDate = route.endDate
        trip.activityType = route.activityType
        trip.length = route.length
        
        trip.bikeTripOfTripsListRow?.updateSortName() // force a row update so our distance will re-draw
        
        return trip
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
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i", ActivityType.cycling.rawValue)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
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
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
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
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
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
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        fetchedRequest.predicate = NSPredicate(format: "startDate > %@", Date().daysFrom(-7) as CVarArg)
        
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
    
    class func bikeTripsToday() -> [Trip]? {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i AND startDate > %@", ActivityType.cycling.rawValue, Date().beginingOfDay() as CVarArg)
        
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
    
    class func leastRecentBikeTrip() -> Trip? {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i", ActivityType.cycling.rawValue)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
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
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i", ActivityType.cycling.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfAutomotiveTrips : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i", ActivityType.automotive.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfBusTrips : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i", ActivityType.bus.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfCycledTripsLast30Days : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i AND startDate > %@", ActivityType.cycling.rawValue, Date().daysFrom(-30) as CVarArg)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfAutomotiveTripsLast30Days : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i AND startDate > %@", ActivityType.automotive.rawValue, Date().daysFrom(-30) as CVarArg)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfBusTripsLast30Days : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i AND startDate > %@", ActivityType.bus.rawValue, Date().daysFrom(-30) as CVarArg)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    class var numberOfBadTrips : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i AND rating == %i", ActivityType.cycling.rawValue, RatingChoice.bad.rawValue)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
    }
    
    func duration() -> TimeInterval {
        return fabs(self.startDate.timeIntervalSince(self.endDate))
    }
    
    func saveAndMarkDirty() {
        if (self.hasChanges && self.isSynced) {
            self.isSynced = false
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    func loadSummaryFromAPNDictionary(_ summary: [AnyHashable: Any]) {
        self.isSummarySynced = true

        if let climacon = summary["weatherEmoji"] as? String {
            self.climacon = climacon
        }
        
        if let temp = summary["temperature"] as? NSNumber {
            self.temperature = temp
        } else {
            self.temperature = nil
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
    
    func loadFromJSON(_ tripJson: JSON) {
        if let activityTypeNumber = tripJson["activityType"].number,
            let ratingChoiceNumber = tripJson["rating"].number,
            let length = tripJson["length"].number,
            let activityType = ActivityType(rawValue: activityTypeNumber.int16Value) {
            let ratingVersionNumber = tripJson["ratingVersion"].number ?? RatingVersion.v1.numberValue // if not given, the server is speaking the old version-less API
            self.rating = Rating(rating: ratingChoiceNumber.int16Value, version: ratingVersionNumber.int16Value)
            self.activityType = activityType
            self.length = length.floatValue
        }
        
        if let displayDataURLString = tripJson["displayDataURL"].string {
            self.displayDataURLString = displayDataURLString
        }
        
        if let summary = tripJson["summary"].dictionary {
            self.loadSummaryFromJSON(summary)
        }
    }
    
    func loadSummaryFromJSON(_ summary: [String: JSON]) {
        if let ready = summary["ready"]?.boolValue {
            self.isSummarySynced = ready
        }
        
        if let climacon = summary["weatherEmoji"]?.string {
            self.climacon = climacon
        }
        
        if let temp = summary["temperature"]?.int {
            self.temperature = NSNumber(value: temp)
        } else {
            self.temperature = nil
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
    
    func cancelTripStateNotificationOnLegacyDevices() {
        if #available(iOS 10.0, *) {
            // return
        } else {
            if (self.currentStateNotification != nil) {
                UIApplication.shared.cancelLocalNotification(self.currentStateNotification!)
                self.currentStateNotification = nil
            }
        }
    }
    
    func sendTripCompletionNotificationLocally(secondsFromNow: TimeInterval) {
        DDLogInfo("Scheduling notification…")
        
        self.cancelTripStateNotificationOnLegacyDevices()
        
        if (self.activityType == .cycling) {
            // don't show a notification for anything but bike trips.
            
            var userInfo: [String: Any] = ["uuid" : self.uuid, "description" : self.displayStringWithTime(), "length" : self.length]
            
            var rewardDicts: [[String: Any]] = []
            for element in self.tripRewards {
                if let reward = element as? TripReward {
                    var rewardDict: [String: Any] = [:]
                    rewardDict["reward_uuid"] = reward.rewardUUID
                    rewardDict["emoji"] = reward.displaySafeEmoji
                    rewardDict["description"] = reward.descriptionText
                    rewardDicts.append(rewardDict)
                }
            }
            userInfo["rewards"] = rewardDicts
            
            if #available(iOS 10.0, *) {
                let backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    DDLogInfo("Schedule trip notification background task expired!")
                })
                
                let content = UNMutableNotificationContent()
                content.categoryIdentifier = "RIDE_COMPLETION_CATEGORY"
                content.sound = UNNotificationSound(named: "bell.aiff")
                content.body = self.notificationString()
                content.userInfo = userInfo
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsFromNow, repeats: false)
                let request = UNNotificationRequest(identifier: self.uuid,
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
        if self.tripRewards.count > 1 {
            var countEmoji = ""
            switch self.tripRewards.count {
                case 2:
                    countEmoji = "2️⃣"
                case 3:
                    countEmoji = "3️⃣"
                case 4:
                    countEmoji = "4️⃣"
                case 5:
                    countEmoji = "5️⃣"
                case 6:
                    countEmoji = "6️⃣"
                case 7:
                    countEmoji = "7️⃣"
                case 8:
                    countEmoji = "8️⃣"
                case 9:
                    countEmoji = "9️⃣"
                case 10:
                    countEmoji = "🔟"
                default:
                    countEmoji = String(self.tripRewards.count)
            }
            
            message += (" ❎" + countEmoji + " combo!")
        }
        
        return message
    }
    
    func weatherString()->String {
        var tempString = ""
        if let temp = self.temperature {
            if #available(iOS 10.0, *) {
                // if we try to drop the units using the temperatureWithoutUnit unit option
                // then we also end up always in fahrenheit.
                // tracked by rdar://problem/32681781
                let measurement = Measurement(value: temp.doubleValue, unit: UnitTemperature.fahrenheit)
                let formatter = MeasurementFormatter()
                formatter.numberFormatter.maximumFractionDigits = 0
                formatter.unitStyle = .short
                tempString = formatter.string(from: measurement)
            } else {
                tempString = String(format: "%0.fºF", temp.doubleValue)
            }
        }
        return String(format: "%@%@", self.climacon ?? "", tempString)
    }
    
    func calorieString()->String {
        return String(format: "%0.fcal", self.caloriesBurned)
    }
    
    func timeString()->String {
        let timeString = String(format: "%@", Trip.timeDateFormatter.string(from: self.startDate))
        
        return timeString
    }
    
    func displayString()->String {
        let areaDescriptionString = self.areaDescriptionString
        let description = String(format: "%@%@.", self.length.distanceString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
        return description
    }
    
    func displayStringWithTime()->String {
        let areaDescriptionString = self.areaDescriptionString
        let description = String(format: "%@%@.", self.timeString(), (areaDescriptionString != "") ? (" " + areaDescriptionString) : "")
        
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
}
