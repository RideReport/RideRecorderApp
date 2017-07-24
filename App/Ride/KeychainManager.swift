//
//  Keychain.swift
//  k
//
//  Created by William Henderson.
//  Copyright (c) 2017 Serious Software. All rights reserved.
//

import Foundation
import KeychainAccess

class KeychainManager {
    static private(set) var keychain: Keychain!
    
    class func startup() {
        if (KeychainManager.keychain == nil) {
            KeychainManager.keychain = Keychain(service: "com.Knock.RideReport").accessibility(.afterFirstUnlock)
        }
    }
}
