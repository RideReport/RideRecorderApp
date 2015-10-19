//
//  APIClientTests.Swift
//  RideTests
//
//  Created by William Henderson on 9/23/15.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import XCTest

class APIClientTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        CoreDataManager.startup()
        APIClient.startup()

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAccountStatusUnverified() {
        APIClient.sharedClient.updateAccountStatus().apiResponse { (_, _) -> Void in
            assert(APIClient.sharedClient.accountVerificationStatus == .Unverified)
        }
        
    }
}
