//
//  StopRouteTests.swift
//  Ride Report Tests
//
//  Created by Heather Buletti on 9/19/18.
//  Copyright © 2018 Knock Softwae, Inc. All rights reserved.
//

import XCTest
import CoreLocation
import CocoaLumberjack
import CoreMotion
import SwiftyJSON

@testable import RouteRecorder

class StopRouteTests: XCTestCase {

    override func setUp() {
        DDLog.add(DDTTYLogger.sharedInstance)
        CoreDataManager.startup(true)
        RouteRecorderDatabaseManager.startup(true)
        
        RouteRecorder.inject(motionManager: CMMotionManager(),
                             locationManager: LocationManager(type: .coreLocation),
                             routeManager: RouteManager(),
                             randomForestManager: RandomForestManager(),
                             classificationManager: SensorClassificationManager())
    }

    override func tearDown() {
    }

    func testStopMisclassifiedWalkingRoutes() {
        if let path = Bundle.init(for: type(of: self)).path(forResource: "Misclassified Walking Trips", ofType: nil) {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: path)
                
                for jsonFile in files {
                    RouteRecorderStore.store().lastArrivalLocation = nil
                    let route = Route()
                    route.uuid = jsonFile.replacingOccurrences(of: ".json", with: "")
                    route.activityType = .cycling  // These routes were misclassified as biking, so set that as the predicted activity
                    
                    var locations = [Location]()
                    if let tripData = NSData.init(contentsOf: URL(fileURLWithPath: jsonFile, relativeTo: URL(fileURLWithPath: path))) as Data? {
                        if let tripLocations = JSON(tripData).dictionary?["locations"]?.array {
                            for location in tripLocations {
                                let newLocation = Location.init(JSON: location)
                                newLocation?.route = route
                                locations.append(newLocation!)
                            }
                        }
                    }
                    
                    RouteRecorderDatabaseManager.shared.saveContext()
                    
                    route.open()
                    route.close()
                    
                    RouteRecorderDatabaseManager.shared.saveContext()
                    
                    self.expectation(forNotification: NSNotification.Name(rawValue: "TestRouteClosed"), object: nil) { (notification) -> Bool in
                        if let route = notification.object as? Route {
                            print("Route closed notification received for \(route.uuid!) - activity type is \(route.activityType)")
                            XCTAssertTrue((route.activityType == .walking))
                        }
                        return true
                    }
                    
                    self.waitForExpectations(timeout: 240.0) { (error) in
                        if error != nil {
                            print("Error waiting for expectation for route with UUID \(jsonFile): \(String(describing: error))")
                        }
                    }
                }
            } catch {
                print("Error getting contents of directory : \(error)")
            }
        }
    }
}
