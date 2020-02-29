//
//  RouteClassificationTests.swift
//  Ride Report Tests
//
//  Created by Heather Buletti on 8/28/18.
//  Copyright © 2018 Knock Softwae, Inc. All rights reserved.
//

import XCTest
import RouteRecorder
import CoreMotion
import CoreLocation
import CocoaLumberjack

@testable import RouteRecorder

class RouteClassificationTests: XCTestCase {
    
    override func setUp() {
        DDLog.add(DDTTYLogger.sharedInstance)
        CoreDataManager.startup(true)
        RouteRecorderDatabaseManager.startup(true)
        let gpxLocationManager = LocationManager(type: .gpx)
        gpxLocationManager.secondLength = 0.1
        
        RouteRecorder.inject(motionManager: CMMotionManager(),
                             locationManager: gpxLocationManager,
                             routeManager: RouteManager(),
                             randomForestManager: RandomForestManager(),
                             classificationManager: TestClassificationManager())
    }
    
    override func tearDown() {
    }
    
    func testMisclassifiedWalkingTrips() {
        if let path = Bundle.init(for: type(of: self)).path(forResource: "Misclassified Walking Trips", ofType: nil) {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: path)
                
                for jsonFile in files {
                    let tripUUID = jsonFile.replacingOccurrences(of: ".json", with: "")
                    print("Testing locations from trip \(tripUUID)")
                    // load trip from file
                    var locations = [CLLocation]()
                    if let tripData = NSData.init(contentsOf: URL(fileURLWithPath: jsonFile, relativeTo: URL(fileURLWithPath: path))) as Data? {
                        if let locationData = try? JSONSerialization.jsonObject(with: tripData, options: JSONSerialization.ReadingOptions.allowFragments) as? [[String:Any]] {
                            for locationDict in locationData! {
                                let newCoordinate = CLLocationCoordinate2D(latitude: locationDict["latitude"] as! Double, longitude: locationDict["longitude"] as! Double)
                                let newLocation = CLLocation(coordinate: newCoordinate, altitude: locationDict["altitude"] as! Double, horizontalAccuracy: locationDict["horizontalAccuracy"] as! Double, verticalAccuracy: locationDict["verticalAccuracy"] as! Double, course: locationDict["course"] as! Double, speed: locationDict["speed"] as! Double, timestamp: Date.dateFromJSONString(locationDict["date"] as! String) ?? Date())
                                locations.append(newLocation)
                            }
                        }
                    }
                    
                    RouteRecorder.shared.locationManager.setLocations(locations: locations)
                    
                    let predictionTemplate = PredictedActivity(activityType: .automotive, confidence: 0.4, prediction: nil)
                    let predictionTemplate2 = PredictedActivity(activityType: .automotive, confidence: 0.5, prediction: nil)
                    let predictionTemplate3 = PredictedActivity(activityType: .automotive, confidence: 0.6, prediction: nil)
                    let predictionTemplate4 = PredictedActivity(activityType: .cycling, confidence: 1.0, prediction: nil)
                    RouteRecorder.shared.classificationManager.setTestPredictionsTemplates(testPredictions: [predictionTemplate4])
                    
                    RouteRecorder.shared.randomForestManager.startup()
                    RouteRecorder.shared.classificationManager.startup(handler: {})
                    
                    RouteRecorder.shared.routeManager.startup(true)
                    
                    //let routeClosedPredicate = NSPredicate(format: "isClosed == true")
                    let expectation = self.expectation(forNotification: NSNotification.Name(rawValue: "TestRouteClosed"), object: nil) { (notification) -> Bool in
                        if let route = notification.object as? Route {
                            print("Route closed notification received for \(route.uuid!) - activity type is \(route.activityType)")
                            XCTAssertTrue((route.activityType == .walking))
                        }
                        return true
                    }
                    
                    //self.wait(for: [expectation], timeout: 240)
                
                    self.waitForExpectations(timeout: 240.0) { (error) in
                        print("!!!DONE WAITING: \(String(describing: error))")
                    }
                    //        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1000.0) {
                    //            routeClosedExpectation.fulfill()
                    //        }
                    
                }
            } catch {
                print("Error getting contents of directory : \(error)")
            }
        }
    }
    
    
}
