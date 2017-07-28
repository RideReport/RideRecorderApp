//
//  Ride_Report_UITests.swift
//  Ride Report UITests
//
//  Created by William Henderson on 5/18/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import XCTest
import CoreMotion

class Ride_Report_UITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-hasSeenSetup","YES"])
        app.launch()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}