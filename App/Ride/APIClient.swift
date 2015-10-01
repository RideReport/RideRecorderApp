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
import KeychainAccess

#if (arch(i386) || arch(x86_64)) && os(iOS)
let serverAddress = "https://localhost/api/v2/"
    #else
let serverAddress = "https://api.ride.report/api/v2/"
#endif

public let AuthenticatedAPIRequestErrorDomain = "com.Knock.Ride.error"
let APIRequestBaseHeaders = ["Content-Type": "application/json", "Accept": "application/json"]

class AuthenticatedAPIRequest {
    private var request: Request? = nil
    private var authToken: String?
    typealias APIResponseBlock = (NSHTTPURLResponse?, Result<JSON>) -> Void
    
    enum AuthenticatedAPIRequestErrorCode: Int {
        case Unauthenticated = 1
        case DuplicateRequest
        case ClientAborted
    }
    
    class func unauthenticatedError() -> NSError {
        return NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.Unauthenticated.rawValue, userInfo: nil)
    }
    
    class func duplicateRequestError() -> NSError {
        return NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.DuplicateRequest.rawValue, userInfo: nil)
    }
    
    class func clientAbortedError() -> NSError {
        return NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.ClientAborted.rawValue, userInfo: nil)
    }
    
    convenience init(requestError: NSError, completionHandler: APIResponseBlock = {(_,_) in }) {
        self.init()

        completionHandler(nil, .Failure(nil, requestError))
    }
    
    convenience init(client: APIClient, method: Alamofire.Method, route: String, parameters: [String: AnyObject]? = nil, completionHandler: APIResponseBlock) {
        self.init()
        
        if (!client.authenticated) {
            client.authenticateIfNeeded()
            completionHandler(nil, .Failure(nil, AuthenticatedAPIRequest.unauthenticatedError()))
            return
        }
        
        var headers = APIRequestBaseHeaders
        if let token = client.accessToken {
            self.authToken = token
            headers["Authorization"] =  "Bearer \(token)"
        }
        
        self.request = client.manager.request(method, serverAddress + route, parameters: parameters, encoding: .JSON, headers: headers)
        
        request!.validate().responseJSON { (request, response, result) in
            switch result {
            case .Success(let jsonData):
                let json = JSON(jsonData)
                completionHandler(response, .Success(json))
            case .Failure(let data, let error):
                if (response?.statusCode == 401) {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        if (self.authToken == client.accessToken) {
                            // make sure the token that generated the 401 is still current
                            // since it is possible we've already reauthenciated
                            client.reauthenticate()
                        }
                    })
                } else if (response?.statusCode == 500) {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        let alert = UIAlertView(title:nil, message: "OOps! Something is wrong on our end. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Trombone")
                        alert.show()
                    })
                }
                completionHandler(response, .Failure(data, error))
            }
        }
    }
    
    func apiResponse(completionHandler: APIResponseBlock) {
        if (self.request == nil) {
            completionHandler(nil, .Failure(nil, AuthenticatedAPIRequest.unauthenticatedError()))
        }
        
        self.request!.responseJSON { (request, response, result) in
            switch result {
            case .Success(let jsonData):
                let json = JSON(jsonData)
                completionHandler(response, .Success(json))
            case .Failure(let data, let error):
                completionHandler(response, .Failure(data, error))
            }
        }
    }
}

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
        self.updateAccountStatus()
        
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                NSNotificationCenter.defaultCenter().removeObserver(self, name: "CoreDataManagerDidStartup", object: nil)
                self.syncTrips()
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
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
            for aTrip in Trip.closedUnsyncedTrips() {
                let trip = aTrip as! Trip
                self.saveAndSyncTripIfNeeded(trip, syncInBackground: syncInBackground)
            }
        })
    }
    
    func saveAndSyncTripIfNeeded(trip: Trip, syncInBackground: Bool = false)->AuthenticatedAPIRequest {
        for incident in trip.incidents {
            if ((incident as! Incident).hasChanges) {
                trip.isSynced = false
            }
        }
        trip.saveAndMarkDirty()
        
        if (syncInBackground || UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
            return self.syncTrip(trip)
        } else {
            return AuthenticatedAPIRequest(requestError: AuthenticatedAPIRequest.clientAbortedError())
        }
    }
    
    //
    // MARK: - Authenciated API Methods
    //
    
    func updateAccountStatus()-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method:Alamofire.Method.GET, route: "status") { (_, result) -> Void in
            switch result {
            case .Success(let json):
                NSNotificationCenter.defaultCenter().postNotificationName("APIClientAccountStatusDidReturn", object: nil)
                
                if let account_verified = json["account_verified"].bool {
                    if (account_verified) {
                        self.accountVerificationStatus = .Verified
                    } else {
                        self.accountVerificationStatus = .Unverified
                    }
                }
            case .Failure(_, let error):
                DDLogError(String(format: "Error retriving account status: %@", error as NSError))
            }
        }
    }
    
    func sendVerificationTokenForEmail(email: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "send_email_code", parameters: ["email": email]) { (response, result) in
            switch result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .Failure(_, let error):
                DDLogError(String(format: "Error sending verification email: %@", error as NSError))
                
                if let code = response?.statusCode where code == 400 {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        let alert = UIAlertView(title:nil, message: "That doesn't look like a valid email address. Please double-check your typing and try again.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    })
                }
            }
        }
    }
    
    func verifyToken(token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "verify_email_code", parameters: ["code": token]) { (_, result) in
            switch result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .Failure(_, let error):
                DDLogError(String(format: "Error verifying email token: %@", error as NSError))
            }
        }
    }
    
    func verifyFacebook(token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "verify_facebook_login", parameters: ["token": token]) { (response, result) in
            switch result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .Failure(_, let error):
                DDLogError(String(format: "Error verifying facebook token: %@", error as NSError))
                if let code = response?.statusCode where code == 400 {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        let alert = UIAlertView(title:nil, message: "There was an error communicating with Facebook. Please try again later or use sign up using your email address instead.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    })
                }
            }
        }
    }
    
    private func syncTrip(trip: Trip)->AuthenticatedAPIRequest {
        if (trip.isSynced.boolValue || !trip.isClosed.boolValue) {
            return AuthenticatedAPIRequest(requestError: AuthenticatedAPIRequest.duplicateRequestError())
        }
        
        var tripDict = [
            "activityType": trip.activityType,
            "creationDate": self.jsonify(trip.creationDate),
            "rating": trip.rating,
            "ownerId": Profile.profile().uuid!
        ]
        var routeURL = "save_trip"
        var method = Alamofire.Method.POST
        
        if (trip.locationsAreSynced.boolValue) {
            routeURL = "/trips/" + trip.uuid
            method = Alamofire.Method.PATCH
        } else {
            tripDict["uuid"] = trip.uuid
            var locations : [AnyObject!] = []
            for location in trip.locations.array {
                let aLocation = location as! Location
                var locDict = [
                    "course": aLocation.course!,
                    "date": self.jsonify(aLocation.date!),
                    "horizontalAccuracy": aLocation.horizontalAccuracy!,
                    "speed": aLocation.speed!,
                    "longitude": aLocation.longitude!,
                    "latitude": aLocation.latitude!
                ]
                if let altitude = aLocation.altitude, let verticalAccuracy = aLocation.verticalAccuracy {
                    locDict["altitude"] = altitude
                    locDict["verticalAccuracy"] = verticalAccuracy
                }
                locations.append(locDict)
            }
            tripDict["locations"] = locations

        }
        
        return AuthenticatedAPIRequest(client: self, method: method, route: routeURL, parameters: tripDict) { (response, result) in
            switch result {
            case .Success(let json):
                trip.isSynced = true
                trip.locationsAreSynced = true
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                CoreDataManager.sharedManager.saveContext()

            case .Failure(_, let error):
                DDLogError(String(format: "Error syncing trip: %@", error as NSError))
            }
        }
    }
    
    func testAuthID()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "oauth_info") { (response, result) in
            switch result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .Failure(_, let error):
                DDLogError(String(format: "Error retriving access token: %@", error as NSError))
            }
        }
    }
    
    //
    // MARK: - Helpers
    //
    
    private func jsonify(date: NSDate) -> String {
        return self.jsonDateFormatter.stringFromDate(date)
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
        
        self.manager.request(.GET, serverAddress + "oauth_token", parameters: parameters, encoding: .URL, headers: APIRequestBaseHeaders).validate().responseJSON { (request, response, result) in
            self.isRequestingAuthentication = false

            switch result {
            case .Success(let jsonData):
                let json = JSON(jsonData)
                
                if let accessToken = json["access_token"].string, expiresIn = json["expires_in"].string {
                    self.saveAccessToken(accessToken, expiresIn: expiresIn)
                    self.updateAccountStatus()
                }
            case .Failure(_, let error):
                DDLogError(String(format: "Error retriving access token: %@", error as NSError))
                let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                alert.show()
            }

        }
    }

    
    //
    // MARK: - OAuth Token Keychain Management
    //
    
    private var rideKeychainUserName = "Ride Report Access Token"
    
    private var keychainItem: Keychain {
        get {
            let keychain = Keychain(service: "com.Knock.Ride")
            .synchronizable(true)
            .accessibility(.AfterFirstUnlockThisDeviceOnly)
            
            
            return keychain
        }
    }

    private func saveAccessToken(token: String, expiresIn: String) -> Bool {
        let data = ["accessToken" : token, "expiresIn" : expiresIn]
        let encodedData = NSKeyedArchiver.archivedDataWithRootObject(data)

        self.deleteAccessToken()
        
        do {
            try self.keychainItem.set(encodedData, key: self.rideKeychainUserName)
            // make sure any old access token isn't memoized
            _hasLookedForAccessToken = false
            _accessToken = nil
            
            return true
        } catch let error {
            DDLogError(String(format: "Error storing access token: %@", error as NSError))
            return false
        }
    }
    
    private func deleteAccessToken() -> Bool {
        do {
            try self.keychainItem.remove(self.rideKeychainUserName)
            // make sure any old access token isn't memoized
            _hasLookedForAccessToken = false
            _accessToken = nil
            
            return true
        } catch let error {
            DDLogError(String(format: "Error delete access token: %@", error as NSError))
            return false
        }
    }
    
    private var _hasLookedForAccessToken: Bool = false
    private var _accessToken: String? = nil
    private var accessToken: String? {
        if (!_hasLookedForAccessToken) {
            _hasLookedForAccessToken = true
            self.keychainDataIsInaccessible = false
            
            do {
                if let data = try self.keychainItem.getData(self.rideKeychainUserName) {
                    if let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? NSDictionary {
                        // make sure any old access token isn't memoized
                        _accessToken = dict["accessToken"] as? String
                        
                    }
                }
            } catch let err {
                let error = err as NSError
                DDLogError(String(format: "Error accessing access token: %@", error))
                if (error.code == Int(-34018)) {
                    // this is a special case. if we get this error, it's due to an obscure keychain bug causing the keychain to be temporarily inaccessible
                    // https://forums.developer.apple.com/message/9225#9225
                    // we'll want to try again later.
                    _hasLookedForAccessToken = false
                    self.keychainDataIsInaccessible = true
                } else if (error.code == Int(errSecInteractionNotAllowed)) {
                    // this is a special case. if we get this error, it's because the device isn't unlocked yet.
                    // we'll want to try again later.
                    _hasLookedForAccessToken = false
                    self.keychainDataIsInaccessible = true
                }
            }
        }
        
        return _accessToken
    }
}
