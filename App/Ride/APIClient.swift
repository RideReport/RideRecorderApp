//
//  APIClient.swift
//  Ride Report
//
//  Created by William Henderson on 12/11/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire
import OAuthSwift
import Locksmith

#if (arch(i386) || arch(x86_64)) && os(iOS)
let serverAddress = "https://api.ride.report/api/v2/"
#else
let serverAddress = "https://api.ride.report/api/v2/"
#endif
    
class APIClient {
    enum AccountVerificationStatus : Int16 { // has the user linked and verified an email to the account?
        case Unknown = 0
        case Unverified
        case Verified
    }
    
    // Status
    var accountVerificationStatus = AccountVerificationStatus.Unknown
    
    private var jsonDateFormatter = NSDateFormatter()
    private var manager : Manager
    private var rideKeychainUserName = "Ride Report Access Token"
    private var keychainDataIsInaccessible = false
    private var isRequestingAuthentication = false
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedClient : APIClient?
    }
    
    //
    // MARK: - Initializers
    //
    
    class var sharedClient:APIClient {
        assert(Static.sharedClient != nil, "Manager was not started before being used!")
        
        return Static.sharedClient!
    }
    
    class func startup() {
        if (Static.sharedClient == nil) {
            Static.sharedClient = APIClient()
            Static.sharedClient?.startup()
        }
    }
    
    func startup() {
        self.authenticateIfNeeded()
        if (self.authenticated) {
            self.updateAccountStatus()
            self.syncTrips()
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    func updateAccountStatus()-> Request {
        return self.makeAuthenticatedRequest(Alamofire.Method.GET, route: "status").validate().responseJSON(options: nil) { (request, response, jsonData, error) -> Void in
            if (error == nil) {
                // do stuff with the response
                let data = JSON(jsonData!)
                if let account_verified = data["account_verified"].bool {
                    if (account_verified) {
                        self.accountVerificationStatus = .Verified
                    } else {
                        self.accountVerificationStatus = .Unverified
                    }
                }
            } else {
                DDLogError(String(format: "Error retriving account status: %@", error!))
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func appDidBecomeActive() {
        self.syncTrips()
    }
    
    init () {
        self.jsonDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZZZ"
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.Knock.Ride.background")
        configuration.timeoutIntervalForRequest = 60
        let serverTrustPolicies : [String: ServerTrustPolicy] = [
            "api.ride.report": ServerTrustPolicy.PinPublicKeys(publicKeys: ServerTrustPolicy.publicKeysInBundle(), validateCertificateChain: true, validateHost: true)
        ]
        self.manager = Alamofire.Manager(configuration: configuration, serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
    }
    
    //
    // MARK: - Trip Synchronization
    //
    
    func syncTrips(syncInBackground: Bool = false) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            for aTrip in Trip.allTrips() {
                let trip = aTrip as! Trip

                if (trip.locations.count <= 6) {
                    // if it doesn't more than 6 points, toss it.
                    CoreDataManager.sharedManager.currentManagedObjectContext().deleteObject(trip)
                    self.saveAndSyncTripIfNeeded(trip)
                } else if !trip.isClosed {
                    trip.close() {
                        self.saveAndSyncTripIfNeeded(trip)
                    }
                } else {
                    self.saveAndSyncTripIfNeeded(trip, syncInBackground: syncInBackground)
                }
            }
        })
    }
    
    func saveAndSyncTripIfNeeded(trip: Trip, syncInBackground: Bool = false) {
        for incident in trip.incidents {
            if ((incident as! Incident).hasChanges) {
                trip.isSynced = false
            }
        }
        if (trip.hasChanges && trip.isSynced.boolValue) {
            trip.isSynced = false
        }
        
        CoreDataManager.sharedManager.saveContext()
        
        if (UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.syncTrip(trip)
                })
        } else if (syncInBackground) {
            // run background task synchronously to avoid being suspended first
            self.syncTrip(trip)
        }
    }
    
    //
    // MARK: - Authenciated API Methods
    //
    
    func sendVerificationTokenForEmail(email: String)-> Request {
        return self.makeAuthenticatedRequest(Alamofire.Method.POST, route: "send_email_code", parameters: ["email": email]).validate().response { (request, response, data, error) in
            if (error == nil) {
                DDLogInfo(String(format: "Response: %@", response!))
            } else {
                DDLogError(String(format: "Error: %@", error!))

                if (response?.statusCode == 400) {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        let alert = UIAlertView(title:nil, message: "That doesn't look like a valid email address. Please double-check your typing and try again.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    })
                }
            }
        }
    }
    
    func verifyToken(token: String)-> Request {
        return self.makeAuthenticatedRequest(Alamofire.Method.POST, route: "verify_email_code", parameters: ["code": token]).validate().response { (request, response, data, error) in
            if (error == nil) {
                DDLogInfo(String(format: "Response: %@", response!))
                self.updateAccountStatus()
            } else {
                DDLogError(String(format: "Error: %@", error!))
            }
        }
    }
    
    private func syncTrip(trip: Trip) {
        if (trip.isSynced.boolValue || !trip.isClosed.boolValue) {
            return
        }
        
        if (!self.authenticated) {
            self.authenticateIfNeeded()
            return
        }
        
        var tripDict = [
            "uuid": trip.uuid,
            "activityType": trip.activityType,
            "creationDate": self.jsonify(trip.creationDate),
            "rating": trip.rating,
            "ownerId": Profile.profile().uuid!
        ]
        var locations : [AnyObject!] = []
        for location in trip.locations.array {
            let aLocation = location as! Location
            locations.append([
                "course": aLocation.course!,
                "date": self.jsonify(aLocation.date!),
                "horizontalAccuracy": aLocation.horizontalAccuracy!,
                "speed": aLocation.speed!,
                "longitude": aLocation.longitude!,
                "latitude": aLocation.latitude!
            ])
        }
        tripDict["locations"] = locations

        self.makeAuthenticatedRequest(Alamofire.Method.POST, route: "save_trip", parameters: tripDict).validate().response { (request, response, data, error) in
            if (error == nil) {
                trip.isSynced = true
                DDLogInfo(String(format: "Response: %@", response!))
                CoreDataManager.sharedManager.saveContext()
            } else {
                DDLogError(String(format: "Error: %@", error!))
            }
        }
    }
    
    //
    // MARK: - Helpers
    //
    
    var requestHeaders: [String:String] {
        var headers = ["Content-Type": "application/json", "Accept": "application/json"]
        if let token = self.accessToken {
            headers["Authorization"] =  "Bearer \(token)"
        }
        
        return headers
    }
    
    private func jsonify(date: NSDate) -> String {
        return self.jsonDateFormatter.stringFromDate(date)
    }
    
    
    private func makeAuthenticatedRequest(method: Alamofire.Method, route: String, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .JSON) -> Request {        
        return self.manager.request(method, serverAddress + route, parameters: parameters, encoding: encoding, headers: self.requestHeaders).response { (request, response, data, error) in
            if (response?.statusCode == 401) {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if (self.authenticated) {
                        let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                        alert.show()
                        self.reauthenticate()
                    }
                })
            } else if (response?.statusCode == 500) {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    let alert = UIAlertView(title:nil, message: "OOps! Something is wrong on our end. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Trombone")
                    alert.show()
                })
            }
        }
    }
    
    //
    // MARK: - OAuth
    //
    
    var authenticated: Bool {
        return (self.accessToken != nil)
    }
    
    func reauthenticate() {
        if (!self.authenticated) {
            // avoid duplicate reauthenticate requests
            return
        }
        
        if (self.deleteAccessToken()) {
            self.authenticateIfNeeded()
        }
    }
    
    func authenticateIfNeeded() {
        if (self.authenticated || self.isRequestingAuthentication || self.keychainDataIsInaccessible) {
            return
        }
        
        self.isRequestingAuthentication = true
        
        let uuid = Profile.profile().uuid
        var parameters = ["client_id" : "1ARN1fJfH328K8XNWA48z6z5Ag09lWtSSVRHM9jw", "response_type" : "token"]
        parameters["uuid"] = uuid
        self.makeAuthenticatedRequest(Alamofire.Method.GET, route: "oauth_token", parameters: parameters, encoding: .URL).validate().responseJSON(options: nil) { (request, response, jsonData, error) -> Void in
            self.isRequestingAuthentication = false
            if (error == nil) {
                // do stuff with the response
                let data = JSON(jsonData!)
                if let accessToken = data["access_token"].string, expiresIn = data["expires_in"].string {
                    self.saveAccessToken(accessToken, expiresIn: expiresIn)
                    self.updateAccountStatus()
                }
            } else {
                let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                alert.show()
                DDLogError(String(format: "Error retriving access token: %@", error!))
            }
        }
    }
    
    func testAuthID() {
        self.makeAuthenticatedRequest(Alamofire.Method.GET, route: "oauth_info").validate().responseJSON(options: nil) { (request, response, jsonData, error) -> Void in
            if (error == nil) {
                // do stuff with the response
                let data = JSON(jsonData!)

            } else {
                DDLogError(String(format: "Error retriving access token: %@", error!))
            }
        }
    }
    
    //
    // MARK: - OAuth Token Keychain Management
    //

    private func saveAccessToken(token: String, expiresIn: String) -> Bool {
        self.deleteAccessToken()
        
        let saveTokenRequest = LocksmithRequest(userAccount: rideKeychainUserName, requestType: RequestType.Create, data: ["accessToken" : token, "expiresIn" : expiresIn])
        saveTokenRequest.synchronizable = true
        saveTokenRequest.accessible = Accessible.AfterFirstUnlockThisDeviceOnly
        let (dictionary, error) = Locksmith.performRequest(saveTokenRequest)
        
        if (error != nil) {
            DDLogError(String(format: "Error storing access token: %@", error!))
            return false
        } else {
            // make sure any old access token isn't memoized
            _hasLookedForAccessToken = false
            _accessToken = nil
            
            return true
        }
    }
    
    private func deleteAccessToken() -> Bool {
        let deleteRequest = LocksmithRequest(userAccount: rideKeychainUserName, requestType: RequestType.Delete)
        deleteRequest.synchronizable = true
        deleteRequest.accessible = Accessible.AfterFirstUnlockThisDeviceOnly
        let (dictionary, error) = Locksmith.performRequest(deleteRequest)
        
        if (error != nil) {
            DDLogError(String(format: "Error delete access token: %@", error!))
            return false
        } else {
            // make sure any old access token isn't memoized
            _hasLookedForAccessToken = false
            _accessToken = nil
            
            return true
        }
    }
    
    private var _hasLookedForAccessToken: Bool = false
    private var _accessToken: String? = nil
    private var accessToken: String? {
        if (!_hasLookedForAccessToken) {
            let loadTokenRequest = LocksmithRequest(userAccount: rideKeychainUserName, requestType: RequestType.Read)
            loadTokenRequest.synchronizable = true
            loadTokenRequest.accessible = Accessible.AfterFirstUnlockThisDeviceOnly
            let (dictionary, error) = Locksmith.performRequest(loadTokenRequest)
            _hasLookedForAccessToken = true
            self.keychainDataIsInaccessible = false

            if (error != nil || dictionary == nil) {
                DDLogError(String(format: "Error accessing access token: %@", error!))
                if (error!.code == Int(errSecInteractionNotAllowed)) {
                    // this is a special case. if we get this error, it's due to an obscure keychain bug causing the keychain to be temporarily inaccessible
                    // https://forums.developer.apple.com/message/9225#9225
                    // we'll want to try again later.
                    _hasLookedForAccessToken = false
                    self.keychainDataIsInaccessible = true
                } else if (error!.code == Int(-34018)) {
                    // this is a special case. if we get this error, it's because the device isn't unlocked yet.
                    // we'll want to try again later.
                    _hasLookedForAccessToken = false
                    self.keychainDataIsInaccessible = true
                }
            } else {
                _accessToken = dictionary?["accessToken"] as? String
            }
        }
        
        return _accessToken
    }
}
