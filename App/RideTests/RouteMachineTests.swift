//
//  RouteMachineTests.swift
//  Ride
//
//  Created by William Henderson on 10/29/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import XCTest
import CoreLocation
import CoreMotion

class RouteMachineTests: XCTestCase {

    override func setUp() {
        class MockLocationManager: CLLocationManager {
            override func requestAlwaysAuthorization() {
                self.delegate.locationManager!(self, didChangeAuthorizationStatus: CLAuthorizationStatus.Authorized)
            }
            
            override func startUpdatingLocation() {
                let locations = [CLLocation(coordinate: CLLocationCoordinate2DMake(0.0, 0.0), altitude: 0.0, horizontalAccuracy: 1.0, verticalAccuracy: 1.0, course: 90, speed: 1, timestamp: NSDate())]
                self.delegate.locationManager!(self, didUpdateLocations: locations)
            }
        }
        
        class MockActivityManager: CMMotionActivityManager {
            override class func isActivityAvailable() -> Bool {
                return true
            }
            
            override func startActivityUpdatesToQueue(queue: NSOperationQueue!, withHandler handler: CMMotionActivityHandler!) {
                handler(MockMotionActivity())
            }
        }
        
        class MockMotionActivity : CMMotionActivity {

            func isCycling() -> Bool {
                return true
            }
        }
        
        class MockRouteMachine : RouteMachine {
            private var locationManager : CLLocationManager!
            private var motionActivityManager : CMMotionActivityManager!

            override init () {
                super.init()
                self.locationManager = MockLocationManager()
                self.motionActivityManager = MockActivityManager()
            }
        }
        
        super.setUp()
        
        MockRouteMachine.sharedMachine.startup()
    }
    
    override func tearDown() {
        super.tearDown()
    }

}
