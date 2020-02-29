//
//  Ride_Report_UITests.swift
//  Ride Report UITests
//
//  Created by William Henderson on 5/18/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import XCTest
import CoreMotion
import Alamofire
import Mockingjay

class Ride_Report_UITests: XCTestCase {
    let baseAPIPath = "/api/v4/"

    private func stubEndpoint(_ endpoint: String, filename: String) {
        let filePath = Bundle(for: type(of: self)).path(forResource: filename, ofType: "json")
        let fileData = NSData(contentsOfFile: filePath!)
        
        let jsonDict = try! JSONSerialization.jsonObject(with: fileData! as Data, options: JSONSerialization.ReadingOptions.allowFragments) as! NSDictionary
        
        stub(uri(baseAPIPath + endpoint),
             json(jsonDict["body"]!,
                  status: (jsonDict["status-code"]! as! NSNumber).intValue,
                  headers: jsonDict["headers"]! as! [String: String])
        )
    }
    
    
    override func setUp() {
        super.setUp()
    }
    
    private func launchApp() {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-hasSeenSetup","YES"])
        app.launchArguments.append("UITestMode")
        app.launch()
    }
    
    func testGetApplications() {
        launchApp()
        
        stubEndpoint("applications", filename: "get_applications")
        
        let app = XCUIApplication()
        app.tabBars.buttons["Profile"].tap()
        
        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["🔗 Connected Apps"]/*[[".cells.staticTexts[\"🔗 Connected Apps\"]",".staticTexts[\"🔗 Connected Apps\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Connect App"]/*[[".cells.staticTexts[\"Connect App\"]",".staticTexts[\"Connect App\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
      
        app.wait(for: .runningBackground, timeout: 20)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}
