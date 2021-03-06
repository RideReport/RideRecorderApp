//
//  Route.swift
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
import CocoaLumberjack

public class  Route: NSManagedObject {
    let simplificationEpisilon: CLLocationDistance = 0.00005
    let simplificationSpeedEpisilon: CLLocationSpeed = 4
    var wasStoppedManually : Bool = false
    
    public var requiresManualStopping: Bool = false
    
    public internal(set) var activityType : ActivityType {
        get {
            return ActivityType(rawValue: self.activityTypeInteger) ?? ActivityType.unknown
        }
        set {
            self.activityTypeInteger = newValue.rawValue
        }
    }
    
    var lastLocationUpdateCount : Int = 0
    private var lastInProgressLocation : Location? = nil
    
    convenience init() {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Route", in: context)!, insertInto: context)
    }
    
    class func mostRecentRoute() -> Route? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Route")
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
        
        return (results!.first as! Route)
    }
    
    class func openRoutes() -> [Route] {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Route")
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
        
        return results! as! [Route]
    }
    
    class func nextClosedUnuploadedRoute() -> Route? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Route")
        let closedPredicate = NSPredicate(format: "isClosed == YES")
        let ununploadedPredicate = NSPredicate(format: "isUploaded == NO")

        fetchedRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [closedPredicate, ununploadedPredicate])
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
        
        return (results!.first as! Route)
    }
    
    class func nextUnuploadedSummaryRoute() -> Route? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Route")
        let closedPredicate = NSPredicate(format: "isClosed == YES")
        let ununploadedPredicate = NSPredicate(format: "isSummaryUploaded == NO")
        
        fetchedRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [closedPredicate, ununploadedPredicate])
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
        
        return (results!.first as! Route)
    }
    
    public class func findRoute(withUUID uuid: String)->Route? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Route")
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
        
        return (results!.first as? Route)
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = Date()
        self.generateUUID()
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        
        // should never happen, but some legacy clients may find themselves in this state
        if (self.uuid == nil) {
            self.generateUUID()
        }
    }
    
    func loadFromJSON(JSON: JSON) {
        if let activityTypeInteger = JSON["activityType"].int16 {
            self.activityTypeInteger = activityTypeInteger
        }
        
        if let dateString = JSON["creationDate"].string, let date = Date.dateFromJSONString(dateString) {
            self.creationDate = date
        }
        
        if let length = JSON["length"].float {
            self.length = length
        }
    }
    
    func locationCount() -> Int {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "route == %@", self)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    public func fetchLocations()->[Location] {
        return self.fetchOrderedLocations(simplified: false, includingInferred: true)
    }
    
    public func fetchOrGenerateSummaryLocations()->[Location] {
        var locs: [Location] = []
        
        if self.activityType != .cycling {
            locs = self.fetchOrderedLocations(simplified: false, includingInferred: true)
        } else {
            locs = self.fetchOrderedLocations(simplified: true, includingInferred: true)
            if (locs.count == 0 && self.locationCount() > 0) {
                self.simplify()
                locs = self.fetchOrderedLocations(simplified: true, includingInferred: true)
            }
        }
        
        return locs
    }
    
    #if DEBUG
    public func fetchOrderedLocationsForReplay()->[Location] {
        return self.fetchOrderedLocations(includingInferred: false)
    }
    #endif
    
    func fetchOrderedLocations(simplified: Bool = false, includingInferred: Bool)->[Location] {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        
        var andPredicates: [NSPredicate] = []
        if simplified == true {
            andPredicates.append(NSPredicate(format: "simplifiedInRoute == %@", self))
        } else {
            andPredicates.append(NSPredicate(format: "route == %@", self))
        }
        
        if !includingInferred {
            for source in LocationSource.inferredSources {
                andPredicates.append(NSPredicate(format: "sourceInteger != %i", source.rawValue))
            }
        }
        
        fetchedRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let locs = results as? [Location] else {
            return []
        }
        
        return locs
    }
    
    func generateUUID() {
        self.uuid = UUID().uuidString
    }
    
    func duration() -> TimeInterval {
        return fabs(self.startDate.timeIntervalSince(self.endDate))
    }
    
    func cancel() {
        let uuidToDelete: String = self.uuid
        RouteRecorderDatabaseManager.shared.currentManagedObjectContext().delete(self)
        RouteRecorderDatabaseManager.shared.saveContext()
        
        if let delegate = RouteRecorder.shared.delegate {
            DispatchQueue.main.async(execute: {
                delegate.didCancelRoute(withUUID: uuidToDelete)
            })
        }
    }
    
    func calculateLength()-> Void {
        guard self.activityType == .cycling else {
            guard let startLoc = self.firstLocation(includeCopied: true), let endLoc = self.mostRecentLocation() else {
                self.length = 0.0
                return
            }
            
            self.length = Float(startLoc.clLocation().distance(from: endLoc.clLocation()))
            return
        }
        
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
    
    func saveLocationsAndUpdateLength(intermittently: Bool = true)->Bool {
        let locSize = self.locationCount()
        
        let updateInterval = (UIApplication.shared.applicationState == UIApplication.State.active) ? 10 : 60 // update less often in the background
        if (!intermittently || lastLocationUpdateCount == -1 || abs(locSize - lastLocationUpdateCount) > updateInterval) {
            // every 10
            if let thisLoc = self.mostRecentLocation() {
                if let lasLoc = self.lastInProgressLocation {
                    let thiscllocation = thisLoc.clLocation()
                    let lastcllocation = lasLoc.clLocation()

                    lastLocationUpdateCount = locSize
                    self.length += Float(lastcllocation.distance(from: thiscllocation))
                    lastInProgressLocation = thisLoc
                    
                    RouteRecorderDatabaseManager.shared.saveContext()
                    
                    if let delegate = RouteRecorder.shared.delegate {
                        DispatchQueue.main.async(execute: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            delegate.didUpdateInProgressRoute(route: strongSelf)
                        })
                    }

                    return true
                } else {
                    lastInProgressLocation = thisLoc
                }
            }
        }
        
        return false
    }
    
    var debugPredictionsDescription: String {
        return self.predictionAggregators.reduce("", {sum, prediction in sum + prediction.debugDescription + "\r"})
    }
    
    func open() {
        if let lastArrivalLocation = RouteRecorderStore.store().lastArrivalLocation {
            let inferredLoc = Location(lastArrivalLocation: lastArrivalLocation)
            inferredLoc.route = self
        } else {
            DDLogInfo("No lastArrivalLocation found")
        }
        
        
        if let delegate = RouteRecorder.shared.delegate {
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                delegate.didOpenRoute(route: strongSelf)
            })
        }
    }
    
    #if DEBUG
    public func reclose() {
        self.isClosed = false
        self.close()
    }
    #endif
    
    func close() {
        guard self.isClosed != true else {
            return
        }
        
        if self.locationCount() <= 1 {
            DDLogInfo("Tossing route with only one location")
            
            self.cancel()

            return
        } else if self.locationCount() == 2 {
            if let startLoc = self.firstLocation(includeCopied: true), let endLoc = self.mostRecentLocation(),
                startLoc.clLocation().distance(from: endLoc.clLocation()) < 200 {
                DDLogInfo("Canceling short route with only a couple locations")
                self.cancel()
                
                return
            }
        }
        
        if let startLoc = self.firstLocation(includeCopied: true), let endLoc = self.mostRecentLocation() {
            let distance = startLoc.clLocation().distance(from: endLoc.clLocation())
            let time = endLoc.date.timeIntervalSince(startLoc.date as Date)
            
            let oneHundredMiles = 100.0 * 1609.34
            let oneHour = Double(60*60)
            let twoHundredMilesPerHour = 200 / 2.23694
            
            if distance/time > twoHundredMilesPerHour && time > oneHour && distance > oneHundredMiles {
                // special case for air travel. including copied locs because it is likely that is all we have if the user enabled airplane mode.
                DDLogInfo("Re-classifiying trip as aviation trip due to very high speed.")
                self.activityType = .aviation
            }
        }
        
        let avgSpeed = self.averageMovingSpeed
        if self.activityType == .cycling && avgSpeed > 11.176 { // 25 mph
            if self.locationCount() > 20 { // make sure we have enough locations to ensure some confidence in the speed
                DDLogInfo("Re-classifiying trip as car trip due to high average moving speed.")

                self.activityType = .automotive
            }
        }
        else if self.activityType == .cycling && avgSpeed >= 0 && avgSpeed < 2 {
            // identify short walking trips that were mistaken for bike trips
            DDLogInfo("Re-classifiying bike trip as walking trip due to low speed.")
            self.activityType = .walking
        }
        else if self.activityType == .cycling && avgSpeed == -1 {
            // We were unable to get a gps fix for any locations in the entire trip - if this was a sufficiently short trip, reclassify it as walking
            // We'll use the distance between the endpoints and subtract the horizontal accuracies
            let halfMile = 804.67
            var endpointDistance = Double(self.length)
            if let startLoc = self.firstLocation(includeCopied: true), let endLoc = self.mostRecentLocation() {
                endpointDistance = startLoc.clLocation().distance(from: endLoc.clLocation())
                endpointDistance -= startLoc.horizontalAccuracy
                endpointDistance -= endLoc.horizontalAccuracy
            }
            if endpointDistance < halfMile {
                DDLogInfo("Re-classifying trip as walking due to unusable speeds")
                self.activityType = .walking
            }
        }
        
        self.calculateLength()
        
        if self.activityType.isMotorizedMode && self.length < 300.0 {
            DDLogInfo("Tossing motorized route that was too short")
            
            self.cancel()

            return
        }
        
        DDLogInfo("Closing route")
        
        RouteRecorderStore.store().lastArrivalLocation = self.mostRecentLocation()
        RouteRecorderDatabaseManager.shared.saveContext()

        self.simplify({
            self.isClosed = true
            self.closedDate = Date()
            if let delegate = RouteRecorder.shared.delegate {
                DispatchQueue.main.async(execute: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    delegate.didCloseRoute(route: strongSelf)
                })
            }
            if ProcessInfo.processInfo.environment["IS_TEST_SCHEME"] != nil {
                let routeClosedNotification = Notification(name: Notification.Name(rawValue: "TestRouteClosed"), object: self, userInfo: nil)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(routeClosedNotification)
                }
                
            }
        })
    }
    
    func reopen() {
        self.isClosed = false
        self.closedDate = nil
        self.lastLocationUpdateCount = -1
        self.isUploaded = false
        self.isSummaryUploaded = false
        self.simplifiedLocations = Set<Location>()
        
        RouteRecorderDatabaseManager.shared.saveContext()
        
        if let delegate = RouteRecorder.shared.delegate {
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                delegate.didOpenRoute(route: strongSelf)
            })
        }
    }
    
    func closestLocationToCoordinate(_ coordinate: CLLocationCoordinate2D)->Location! {
        let targetLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    
        var closestLocation : Location? = nil
        var closestDisance = CLLocationDistanceMax
        for location in self.fetchOrderedLocations(includingInferred: true) {
            let locDistance = targetLoc.distance(from: location.clLocation())
            if (locDistance < closestDisance) {
                closestDisance = locDistance
                closestLocation = location
            }
        }
        
        return closestLocation
    }
    
    private func usableLocationsForSimplification()->[Location] {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "route == %@ AND (horizontalAccuracy <= %f OR sourceInteger != %i)", self, Location.acceptableLocationAccuracy, LocationSource.activeGPS.rawValue)
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
    
    #if DEBUG
    public func resimplify() {
        self.simplify()
    }
    #endif
    
    func simplify(_ handler: ()->Void = {}) {
        let accurateOrNonActiveLocs = self.usableLocationsForSimplification()
        
        let currentSimplifiedLocs = self.fetchOrderedLocations(simplified: true, includingInferred: true)
        for loc in currentSimplifiedLocs {
            loc.simplifiedInRoute = nil
        }
        
        if (accurateOrNonActiveLocs.count == 0) {
            handler()
            return
        }
        
        self.simplifyLocations(accurateOrNonActiveLocs, episilon: simplificationEpisilon, speedEpisilon: simplificationSpeedEpisilon)
        
        RouteRecorderDatabaseManager.shared.saveContext()
        handler()
    }
    
    // Ramer–Douglas–Peucker geometric simplication algorithm
    private func simplifyLocations(_ locations: [Location], episilon : CLLocationDegrees, speedEpisilon: CLLocationSpeed) {
        var maximumDistance : CLLocationDegrees = 0
        var indexOfMaximumDistance = 0
        
        var maximumSpeedDifference : CLLocationSpeed = 0
        var indexOfMaximumSpeedDifference = 0
        
        let startLoc = locations.first
        let endLoc = locations.last
        var counter = 1
        
        var currentlyStopped = startLoc!.speed >= 0 && startLoc!.speed < Location.minimumMovingSpeed
        
        if (locations.count > 2) {
            for loc in locations[counter...(locations.count - 2)] {
                let distance = self.shortestDistanceFromLineToPoint(startLoc!.coordinate(), lineEndPoint: endLoc!.coordinate(), point: loc.coordinate())
                if (distance > maximumDistance) {
                    indexOfMaximumDistance = counter
                    maximumDistance = distance
                }
                
                let startSpeed = startLoc!.speed
                let endSpeed = endLoc!.speed
                let speedSlope = (endSpeed - startSpeed) / endLoc!.timeIntervalSinceLocation(location: startLoc!)
                
                if startSpeed >= 0 && endSpeed >= 0 && loc.speed >= 0 {
                    let expectedSpeed = startSpeed + speedSlope * loc.timeIntervalSinceLocation(location: startLoc!)
                    let speedDifference = fabs(expectedSpeed - loc.speed)
                    if (speedDifference > maximumSpeedDifference) {
                        indexOfMaximumSpeedDifference = counter
                        maximumSpeedDifference = speedDifference
                    } else if (!currentlyStopped && loc.speed < Location.minimumMovingSpeed) {
                        currentlyStopped = true
                        indexOfMaximumSpeedDifference = counter
                        maximumSpeedDifference = Double.greatestFiniteMagnitude
                    } else if (currentlyStopped && loc.speed >= Location.minimumMovingSpeed) {
                        currentlyStopped = false
                        indexOfMaximumSpeedDifference = counter
                        maximumSpeedDifference = Double.greatestFiniteMagnitude
                    }
                }
                
                counter += 1
            }
        } else {
            // trivial case: two points are more than episilon distance away.
            startLoc!.simplifiedInRoute = self
            endLoc!.simplifiedInRoute = self
            return
        }
        
        if (maximumDistance > episilon || maximumSpeedDifference > speedEpisilon) {
            var cutOffIndex = indexOfMaximumSpeedDifference
            if (maximumDistance > episilon && maximumSpeedDifference < Double.greatestFiniteMagnitude) {
                // If both conditions are met, we prefer to include points that affect the geometry
                // – unless the maximumSpeedDifference speed is greatestFiniteMagnitude because the user stopped
                cutOffIndex = indexOfMaximumDistance
            }
            self.simplifyLocations(Array(locations[0...cutOffIndex]), episilon: episilon, speedEpisilon: speedEpisilon)
            self.simplifyLocations(Array(locations[cutOffIndex...(locations.count - 1)]), episilon: episilon, speedEpisilon: speedEpisilon)
        } else {
            startLoc!.simplifiedInRoute = self

            var i = 0
            for loc in locations {
                // also include any non-GPS location, plus the first location following it
                if loc.source != .activeGPS {
                    if loc.simplifiedInRoute == nil {
                        loc.simplifiedInRoute = self
                    }
                    if (i + 1) < locations.count {
                        if locations[i + 1].simplifiedInRoute == nil {
                            locations[i + 1].simplifiedInRoute = self
                        }
                    }
                }
                i += 1
            }
            
            endLoc!.simplifiedInRoute = self
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
    
    func mostRecentLocation() -> Location? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "route == %@", self)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let loc = results?.first as? Location else {
            return nil
        }
        
        return loc
    }
    
    func mostRecentLocationsForLightTrigger()-> [Location]? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "route == %@", self)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchedRequest.fetchLimit = 5 // This number is somewhat arbitrary and can be adjusted if we want to send more or fewer
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let locations = results as? [Location] else {
            return nil
        }
        
        return locations
    }
    
    func addPredictionAggregator(_ predictionAggregator: PredictionAggregator) {
        predictionAggregator.route = self
        
        for loc in predictionAggregator.locations {
            loc.route = self
        }
    }
    
    func firstLocation(includeCopied: Bool) -> Location? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        if includeCopied {
            fetchedRequest.predicate = NSPredicate(format: "route == %@", self)
        } else {
            fetchedRequest.predicate = NSPredicate(format: "route == %@ AND sourceInteger != %i AND sourceInteger != %i", self, LocationSource.geofence.rawValue, LocationSource.lastRouteArrival.rawValue)
        }
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let loc = results?.first as? Location else {
            return nil
        }
        
        return loc
    }
    
    public var startDate : Date {
        if let firstLoc = self.firstLocation(includeCopied: false) {
            return firstLoc.date
        }
        
        return self.creationDate
    }
    
    public var endDate : Date {
        if let firstLoc = self.mostRecentLocation() {
            return firstLoc.date
        }
        
        return self.creationDate
    }
    
    var averageMovingSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        let locs = self.fetchOrderedLocations(simplified: false, includingInferred: false)
        var hasFoundLocWithSpeed = false

        for location in locs {
            if (location.speed > Location.minimumMovingSpeed) {
                count += 1
                sumSpeed += (location as Location).speed
            } else if location.speed >= 0 {
                hasFoundLocWithSpeed = true
            }
        }
        
        if (count == 0) {
            if hasFoundLocWithSpeed {
                return 0
            } else {
                return -1
            }
        }
        
        return sumSpeed/Double(count)
    }
}
