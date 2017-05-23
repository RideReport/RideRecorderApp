//
//  APIClientTests.Swift
//  RideTests
//
//  Created by William Henderson on 9/23/15.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import XCTest
import Alamofire
import OHHTTPStubs

let baseAPIPath = "/api/v2/"

class APIClientTests: XCTestCase {
    
    private func stubEndpoint(_ endpoint: String, filename: String) {
        stub(condition: isPath(baseAPIPath + endpoint)) { _ in
            let filePath = Bundle(for: type(of: self)).path(forResource: filename, ofType: "json")
            let fileData = NSData(contentsOfFile: filePath!)
            
            let jsonDict = try! JSONSerialization.jsonObject(with: fileData! as Data, options: JSONSerialization.ReadingOptions.allowFragments) as! NSDictionary
            return OHHTTPStubsResponse(jsonObject: jsonDict["body"]!, statusCode: Int32((jsonDict["status-code"]! as! NSNumber).intValue), headers: (jsonDict["headers"]! as! [AnyHashable: Any]))
        }
    }
    
    override func setUp() {
        super.setUp()
        CoreDataManager.startup(true)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        OHHTTPStubs.removeAllStubs()
    }
    
    func duplicateUUIDDoesNotCreateNewTrip() {
        // request fails with 509
    }

    
    func createAuthorizedClient() {
        Profile.profile().accessToken = "fooBooBat"
        Profile.profile().accessTokenExpiresIn = Date(timeIntervalSinceNow: 999999.0)
        
        APIClient.startup(true)
    }
    
    func createBikeRide()->Trip {
        let trip = Trip()
        trip.length = 4599 // in meters
        trip.activityType = ActivityType.cycling
        
        let startLoc = Location(trip: trip)
        startLoc.verticalAccuracy = NSNumber(value: 5 as Int)
        startLoc.horizontalAccuracy = NSNumber(value: 5 as Int)
        startLoc.course = NSNumber(value: 0 as Int)
        startLoc.latitude = NSNumber(value: 45.518161 as Float)
        startLoc.longitude = NSNumber(value: -122.679393 as Float)
        startLoc.speed = NSNumber(value: 3 as Int)
        startLoc.date = Date(timeIntervalSinceNow: 15 * 60 * -1.0)
        
        let endLoc = Location(trip: trip)
        endLoc.verticalAccuracy = NSNumber(value: 5 as Int)
        endLoc.horizontalAccuracy = NSNumber(value: 5 as Int)
        endLoc.course = NSNumber(value: 0 as Int)
        endLoc.latitude = NSNumber(value: 45.515424 as Float)
        endLoc.longitude = NSNumber(value: -122.650811 as Float)
        endLoc.speed = NSNumber(value: 3 as Int)
        endLoc.date = Date()
        
        trip.isClosed = true
        trip.saveAndMarkDirty()
        
        return trip
    }
    
    func testSyncTripSummaryNotReady() {
        createAuthorizedClient()
        
        let trip = createBikeRide()
        
        let expectation = self.expectation(description: "TripSync")
        stubEndpoint("trips/" + trip.uuid, filename: "new_trip_201")
        
        APIClient.shared.syncTrip(trip).apiResponse { (response) -> Void in
            expectation.fulfill()
            XCTAssertEqual(response.response?.statusCode, 201)
            XCTAssert(trip.isSynced)
            XCTAssertNil(trip.startingPlacemarkName)
            XCTAssertNil(trip.climacon)
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testSyncTripSummaryReady() {
        createAuthorizedClient()
        
        let trip = createBikeRide()
        
        let expectation = self.expectation(description: "TripSync")
        stubEndpoint("trips/" + trip.uuid, filename: "trip_with_ready_summary_200")
        
        APIClient.shared.syncTrip(trip).apiResponse { (response) -> Void in
            expectation.fulfill()
            XCTAssertEqual(response.response?.statusCode, 200)
            XCTAssert(trip.isSynced)
            XCTAssertNotNil(trip.startingPlacemarkName)
            XCTAssertNotNil(trip.climacon)
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testSyncDuplicateTripShouldFailAndChangeUUID() {
        createAuthorizedClient()
        
        testSyncTripSummaryNotReady()
        let trip = Trip.mostRecentTrip()!
        
        let trip2 = createBikeRide()
        trip2.uuid = trip.uuid
        trip.saveAndMarkDirty()
        
        let expectation = self.expectation(description: "TripSyncFails")
        stubEndpoint("trips/" + trip2.uuid, filename: "new_trip_409")
        
        APIClient.shared.syncTrip(trip2).apiResponse { (response) -> Void in
            XCTAssertEqual(response.response?.statusCode, 409)
            XCTAssert(!trip2.isSynced)
            XCTAssertNotEqual(trip.uuid, trip2.uuid)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
}
