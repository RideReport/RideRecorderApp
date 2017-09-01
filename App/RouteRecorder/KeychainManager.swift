//
//  Keychain.swift
//  k
//
//  Created by William Henderson.
//  Copyright (c) 2017 Serious Software. All rights reserved.
//

import Foundation
import KeychainAccess

public class KeychainManager {
    public static private(set) var shared : KeychainManager!
    
    struct Static {
        static var onceToken : Int = 0
        static var sharedManager : KeychainManager?
    }
    
    private(set) var keychain: Keychain!
    
    public var accessToken : String? {
        get {
            do {
                if let token = try self.keychain.getString("accessToken") {
                    return token
                }
            } catch let error {
                DDLogError("Error accessing keychain: \(error)")
            }
            
            return nil
        }
        set {
            self.keychain["accessToken"] = newValue
        }
    }
    
    public var accessTokenExpiresIn : Date? {
        get {
            do {
                if let expiresInData = try self.keychain.getData("accessTokenExpiresIn"),
                    let expiresIn = NSKeyedUnarchiver.unarchiveObject(with: expiresInData) as? Date {
                    
                    return expiresIn
                }
            } catch let error {
                DDLogError("Error accessing keychain: \(error)")
            }
            
            return nil
        }
        set {
            if let newExpiresIn = newValue {
                self.keychain[data: "accessTokenExpiresIn"] = NSKeyedArchiver.archivedData(withRootObject: newExpiresIn)
            } else {
                self.keychain[data: "accessTokenExpiresIn"] = nil
            }
        }
    }
    
    class func startup() {
        if (KeychainManager.shared == nil) {
            KeychainManager.shared = KeychainManager()
            KeychainManager.shared.keychain = Keychain(service: "com.Knock.RideReport").accessibility(.afterFirstUnlock)
        }
    }
}
