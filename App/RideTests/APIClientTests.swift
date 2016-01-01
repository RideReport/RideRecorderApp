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
    
    private func stubEndpoint(endpoint: String, filename: String) {
        stub(isPath(baseAPIPath + endpoint)) { _ in
            let filePath = NSBundle(forClass: self.dynamicType).pathForResource(filename, ofType: "json")
            let fileData = NSData(contentsOfFile: filePath!)
            
            let jsonDict = try! NSJSONSerialization.JSONObjectWithData(fileData!, options: NSJSONReadingOptions.AllowFragments) as! NSDictionary
            return OHHTTPStubsResponse(JSONObject: jsonDict["body"]!, statusCode: (jsonDict["status-code"]! as! NSNumber).intValue, headers: jsonDict["headers"]! as! [NSObject : AnyObject])
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
        Profile.profile().accessTokenExpiresIn = NSDate(timeIntervalSinceNow: 999999.0)
        
        APIClient.startup(true)
    }
    
    func createBikeRide()->Trip {
        let trip = Trip()
        trip.length = 4599 // in meters
        trip.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
        
        let startLoc = Location(trip: trip)
        startLoc.verticalAccuracy = NSNumber(integer: 5)
        startLoc.horizontalAccuracy = NSNumber(integer: 5)
        startLoc.course = NSNumber(integer: 0)
        startLoc.latitude = NSNumber(float: 45.518161)
        startLoc.longitude = NSNumber(float: -122.679393)
        startLoc.speed = NSNumber(integer: 3)
        startLoc.date = NSDate(timeIntervalSinceNow: 15 * 60 * -1.0)
        
        let endLoc = Location(trip: trip)
        endLoc.verticalAccuracy = NSNumber(integer: 5)
        endLoc.horizontalAccuracy = NSNumber(integer: 5)
        endLoc.course = NSNumber(integer: 0)
        endLoc.latitude = NSNumber(float: 45.515424)
        endLoc.longitude = NSNumber(float: -122.650811)
        endLoc.speed = NSNumber(integer: 3)
        endLoc.date = NSDate()
        
        trip.isClosed = true
        trip.saveAndMarkDirty()
        
        return trip
    }
    
    func testSyncTripSummaryNotReady() {
        createAuthorizedClient()
        
        let trip = createBikeRide()
        
        let expectation = expectationWithDescription("TripSync")
        stubEndpoint("trips/" + trip.uuid, filename: "new_trip_201")
        
        APIClient.sharedClient.syncTrip(trip).apiResponse { (response) -> Void in
            expectation.fulfill()
            XCTAssertEqual(response.response?.statusCode, 201)
            XCTAssert(trip.isSynced)
            XCTAssertNil(trip.startingPlacemarkName)
            XCTAssertNil(trip.climacon)
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testSyncTripSummaryReady() {
        createAuthorizedClient()
        
        let trip = createBikeRide()
        
        let expectation = expectationWithDescription("TripSync")
        stubEndpoint("trips/" + trip.uuid, filename: "trip_with_ready_summary_200")
        
        APIClient.sharedClient.syncTrip(trip).apiResponse { (response) -> Void in
            expectation.fulfill()
            XCTAssertEqual(response.response?.statusCode, 200)
            XCTAssert(trip.isSynced)
            XCTAssertNotNil(trip.startingPlacemarkName)
            XCTAssertNotNil(trip.climacon)
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
    
    func testSyncDuplicateTripShouldFailAndChangeUUID() {
        createAuthorizedClient()
        
        testSyncTripSummaryNotReady()
        let trip = Trip.mostRecentBikeTrip()!
        
        let trip2 = createBikeRide()
        trip2.uuid = trip.uuid
        trip.saveAndMarkDirty()
        
        let expectation = expectationWithDescription("TripSyncFails")
        stubEndpoint("trips/" + trip2.uuid, filename: "new_trip_409")
        
        APIClient.sharedClient.syncTrip(trip2).apiResponse { (response) -> Void in
            XCTAssertEqual(response.response?.statusCode, 409)
            XCTAssert(!trip2.isSynced)
            XCTAssertNotEqual(trip.uuid, trip2.uuid)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(1, handler: nil)
    }
}
