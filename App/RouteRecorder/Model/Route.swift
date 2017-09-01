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

public class  Route: NSManagedObject {
    let simplificationEpisilon: CLLocationDistance = 0.00005
    var wasStoppedManually : Bool = false
    
    var activityType : ActivityType {
        get {
            return ActivityType(rawValue: self.activityTypeInteger) ?? ActivityType.unknown
        }
        set {
            let oldValue = self.activityType
            self.activityTypeInteger = newValue.rawValue
        }
    }
    
    var inProgressLength : CLLocationDistance = 0
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
    
    func locationCount() -> Int {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        fetchedRequest.predicate = NSPredicate(format: "route == %@", self)
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    func generateSummaryLocations()->[Location] {
        var locs: [Location] = []
        
        if self.activityType != .cycling || !self.isClosed || locs.isEmpty {
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
        RouteRecorderDatabaseManager.shared.currentManagedObjectContext().delete(self)
        RouteRecorderDatabaseManager.shared.saveContext()
        
        if let delegate = RouteRecorder.shared.delegate {
            delegate.didCancelRoute(route: self)
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
    
    func saveLocationsAndUpdateInProgressLength(intermittently: Bool = true)->Bool {
        let locSize = self.locationCount()
        if (!intermittently || lastLocationUpdateCount == -1 || abs(locSize - lastLocationUpdateCount) > 10) {
            // every 10
            if let thisLoc = self.mostRecentLocation() {
                if let lasLoc = self.lastInProgressLocation {
                    let thiscllocation = thisLoc.clLocation()
                    let lastcllocation = lasLoc.clLocation()

                    lastLocationUpdateCount = locSize
                    inProgressLength += Double(lastcllocation.distance(from: thiscllocation))
                    lastInProgressLocation = thisLoc
                    
                    RouteRecorderDatabaseManager.shared.saveContext()

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
        }
        
        if let delegate = RouteRecorder.shared.delegate {
            delegate.didOpenRoute(route: self)
        }
    }
    
    func close() {
        guard self.isClosed != true else {
            return
        }
        
        
        guard self.locationCount() > 1 else {
            DDLogInfo("Tossing route with only one location")
            
            self.cancel()

            return
        }
        
        if self.activityType.isMotorizedMode && self.locationCount() <= 2 {
            DDLogInfo("Tossing motorized route with only a couple locations")
            
            self.cancel()

            return
        }
        
        self.calculateLength()
        
        if self.activityType.isMotorizedMode && self.length < 250.0 {
            DDLogInfo("Tossing motorized route that was too short")
            
            self.cancel()

            return
        }
        
        DDLogInfo("Closing route")
        
        RouteRecorderStore.store().lastArrivalLocation = self.mostRecentLocation()
        RouteRecorderDatabaseManager.shared.saveContext()

        self.simplify({
            self.isClosed = true
            if let delegate = RouteRecorder.shared.delegate {
                delegate.didCloseRoute(route: self)
            }
        })
    }
    
    func reopen() {
        self.isClosed = false
        self.lastLocationUpdateCount = -1
        self.isUploaded = false
        self.isSummaryUploaded = false
        self.simplifiedLocations = Set<Location>()
        
        RouteRecorderDatabaseManager.shared.saveContext()
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
    
    func simplify(_ handler: ()->Void = {}) {
        let accurateLocs = self.usableLocationsForSimplification()
        
        let currentSimplifiedLocs = self.fetchOrderedLocations(simplified: true, includingInferred: true)
        for loc in currentSimplifiedLocs {
            loc.simplifiedInRoute = nil
        }
        
        if (accurateLocs.count == 0) {
            handler()
            return
        }
        
        self.simplifyLocations(accurateLocs, episilon: simplificationEpisilon)
        
        RouteRecorderDatabaseManager.shared.saveContext()
        handler()
    }
    
    // Ramer–Douglas–Peucker geometric simplication algorithm
    private func simplifyLocations(_ locations: [Location], episilon : CLLocationDegrees) {
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
            startLoc!.simplifiedInRoute = self
            endLoc!.simplifiedInRoute = self
            return
        }
        
        if ( maximumDistance > episilon) {
            self.simplifyLocations(Array(locations[0...indexOfMaximumDistance]), episilon: episilon)
            self.simplifyLocations(Array(locations[indexOfMaximumDistance...(locations.count - 1)]), episilon: episilon)
        } else {
            startLoc!.simplifiedInRoute = self

            var i = 0
            for loc in locations {
                // also include any inferred location, plus the first location following it
                if loc.source.isInferred {
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
    
    
    var startDate : Date {
        if let firstLoc = self.firstLocation(includeCopied: false) {
            return firstLoc.date
        }
        
        return self.creationDate
    }
    
    var endDate : Date {
        if let firstLoc = self.mostRecentLocation() {
            return firstLoc.date
        }
        
        return self.creationDate
    }
    
    var aggregateRoughtSpeed: CLLocationSpeed {
        guard let startLoc = self.firstLocation(includeCopied: false), let endLoc = self.mostRecentLocation() else {
            return 0.0
        }
        
        let distance = startLoc.clLocation().distance(from: endLoc.clLocation())
        let time = endDate.timeIntervalSince(startLoc.date)
        
        return distance/time
    }
    
    var aproximateAverageBikingSpeed : CLLocationSpeed {
        var sumSpeed : Double = 0.0
        var count = 0
        let simplifiedLocs = self.fetchOrderedLocations(simplified: true, includingInferred: false)
        for location in simplifiedLocs {
            if (location.speed > 1.0 && location.horizontalAccuracy <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed
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
        let locs = self.fetchOrderedLocations(simplified: true, includingInferred: false)

        for location in locs {
            if (location.speed > Location.minimumMovingSpeed && location.horizontalAccuracy <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed
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
        let locs = self.fetchOrderedLocations(simplified: true, includingInferred: false)

        for location in locs {
            if (location.speed > 0 && location.horizontalAccuracy <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed
            }
        }
        
        if (count == 0) {
            return 0
        }
        
        return sumSpeed/Double(count)
    }
}
