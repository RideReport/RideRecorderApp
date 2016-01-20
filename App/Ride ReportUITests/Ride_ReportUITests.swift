//
//  Ride_ReportUITests.swift
//  Ride ReportUITests
//
//  Created by William Henderson on 1/19/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import XCTest

class Ride_ReportUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // Failed to find matching element please file bug (bugreport.apple.com) and provide output from Console.app
        
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        
        
        snapshot("01RoutesView")

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
}
