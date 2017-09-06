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
import MapboxStatic

public class  Trip: NSManagedObject {
    private var currentStateNotification : UILocalNotification? = nil
    
    var isBeingSavedToHealthKit: Bool = false
    var workoutObject: HKWorkout? = nil
    var wasStoppedManually : Bool = false
    
    public var route: Route? {
        get {
            let context = CoreDataManager.shared.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Route")
            fetchedRequest.predicate = NSPredicate(format: "uuid == [c] %@", self.uuid)
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
            
            return (results!.first as? Route)
        }
    }
    
    
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
    
    var activityType : ActivityType {
        get {
            return ActivityType(rawValue: self.activityTypeInteger) ?? ActivityType.unknown
        }
        set {
            let oldValue = self.activityType
            
            self.activityTypeInteger = newValue.rawValue
            
            if oldValue != newValue {
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
    
    var rating: Rating {
        get {
            return Rating(rating: self.ratingInteger, version: self.ratingVersion)
        }
        set {
            self.ratingInteger = newValue.choice.rawValue
            self.ratingVersion = newValue.version.rawValue
        }
    }
    
    var didChangeSection : Bool = false
    
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
    
    class func cyclingSectionIdentifierSuffix()->String {
        return "yy"
    }
    
    class func inProgressSectionIdentifierSuffix()->String {
        return "z"
    }
    
    private func sectionIdentifierString()->String {
        return  Trip.sectionDateFormatter.string(from: self.startDate) + (self.activityType == .cycling ? Trip.cyclingSectionIdentifierSuffix() : "")
    }
    
    class func reloadSectionIdentifiers(_ exhaustively: Bool = false) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        if !exhaustively {
            fetchedRequest.predicate = NSPredicate(format: "sectionIdentifier == nil")
        }
        
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
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
    
    convenience init(route: Route) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Trip", in: context)!, insertInto: context)
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
        self.sectionIdentifier = "z" // has to be non-nil or it will not show up in the list
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
    
    @available(iOS 10.0, *)
    private func createRouteMapAttachement(_ handler: @escaping (_ attachment: UNNotificationAttachment?)->Void) {
        guard let route = self.route else {
            handler(nil)
            return
        }
        
        let locations = route.generateSummaryLocations()
        
        if locations.count > 0 {
            let width = UIScreen.main.bounds.width
            let height = UIScreen.main.bounds.height - 370 // make sure that all three buttons fit on the screen without scrolling
            
            var coords = [CLLocationCoordinate2D]()
            
            
            for loc in locations {
                coords.append(loc.coordinate())
            }
            
            let path = Path(
                coordinates: coords
            )
            path.strokeWidth = 8
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
            
            let backingPath = Path(
                coordinates: coords
            )
            backingPath.strokeWidth = 12
            backingPath.strokeColor = UIColor(red: 115/255, green: 123/255, blue: 102/255, alpha: 1.0)
            backingPath.fillColor = UIColor.clear
            
            let startMarker = CustomMarker(
                coordinate: locations.first!.coordinate(),
                url: URL(string: "https://s3-us-west-2.amazonaws.com/ridereport/pinGreen%402x.png")!
            )
            
            let endMarker = CustomMarker(
                coordinate: locations.last!.coordinate(),
                url: URL(string: "https://s3-us-west-2.amazonaws.com/ridereport/pinRed%402x.png")!
            )
            
            let options = SnapshotOptions(
                styleURL: URL(string: "mapbox://styles/quicklywilliam/cire41sgs0001ghme6posegq0")!,
                size: CGSize(width: width, height: height))
            options.showsAttribution = false
            
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
    
    func sendTripCompletionNotificationLocally(_ clearRemoteMessage: Bool = false, secondsFromNow: TimeInterval = 0) {
        DDLogInfo("Scheduling notification…")
        
        self.cancelTripStateNotification(clearRemoteMessage)
        
        if (self.activityType == .cycling) {
            // don't show a notification for anything but bike trips.
            
            var userInfo: [String: Any] = ["uuid" : self.uuid, "rideDescription" : self.displayStringWithTime(), "rideLength" : self.length]
            
            var rewardDicts: [[String: Any]] = []
            for element in self.tripRewards {
                if let reward = element as? TripReward {
                    var rewardDict: [String: Any] = [:]
                    rewardDict["rewardUUID"] = reward.rewardUUID
                    rewardDict["displaySafeEmoji"] = reward.displaySafeEmoji
                    rewardDict["descriptionText"] = reward.descriptionText
                    rewardDicts.append(rewardDict)
                }
            }
            userInfo["rewards"] = rewardDicts
            
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
