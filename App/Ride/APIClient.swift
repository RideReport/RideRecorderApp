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
//let serverAddress = "https://localhost/api/v2/"
let serverAddress = "https://api.ride.report/api/v2/"
    #else
let serverAddress = "https://api.ride.report/api/v2/"
#endif

public let AuthenticatedAPIRequestErrorDomain = "com.Knock.Ride.error"
let APIRequestBaseHeaders = ["Content-Type": "application/json", "Accept": "application/json, text/plain"]

class AuthenticatedAPIRequest {
    typealias APIResponseBlock = (NSHTTPURLResponse?, Result<JSON>) -> Void

    // a block that fires once at completion, unlike APIResponseBlocks which are appended
    var requestCompletetionBlock: ()->Void = {}
    
    private var request: Request? = nil
    private var authToken: String?
    
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
            self.requestCompletetionBlock()
            return
        }
        
        var headers = APIRequestBaseHeaders
        if let token = client.accessToken {
            self.authToken = token
            headers["Authorization"] =  "Bearer \(token)"
        }
        
        self.request = client.manager.request(method, serverAddress + route, parameters: parameters, encoding: ParameterEncoding.JSON.gzipped, headers: headers)
        
        let handleHTTPResonseErrors = { (response: NSHTTPURLResponse?) in
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
        }
        
        if (method == .DELETE) {
            // delete does not return JSON https://github.com/KnockSoftware/rideserver/issues/48
            request!.validate().responseString(encoding: NSASCIIStringEncoding, completionHandler: { (request, response, result) in
                switch result {
                case .Success(_):
                    completionHandler(response, .Success(JSON("")))
                case .Failure(let data, let error):
                    handleHTTPResonseErrors(response)
                    completionHandler(response, .Failure(data, error))
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            })
        } else {
            request!.validate().responseJSON { (request, response, result) in
                switch result {
                case .Success(let jsonData):
                    let json = JSON(jsonData)
                    completionHandler(response, .Success(json))
                case .Failure(let data, let error):
                    handleHTTPResonseErrors(response)
                    completionHandler(response, .Failure(data, error))
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            }
        }
    }
    
    func apiResponse(completionHandler: APIResponseBlock) {
        if (self.request == nil) {
            completionHandler(nil, .Failure(nil, AuthenticatedAPIRequest.unauthenticatedError()))
            return
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

    enum Area {
        case Unknown
        case Area(name: String, count: UInt, countRatePerHour: UInt, launched: Bool)
        case NonArea
    }
    
    var area : Area = .Unknown
    
    // Status
    var accountVerificationStatus = AccountVerificationStatus.Unknown {
        didSet {
            NSNotificationCenter.defaultCenter().postNotificationName("APIClientAccountStatusDidChange", object: nil)
        }
    }
    
    
    private var jsonDateFormatter = NSDateFormatter()
    private var manager : Manager
    private var tripRequests : [Trip: AuthenticatedAPIRequest] = [:]
    private var keychainDataIsInaccessible = false
    private var isRequestingAuthentication = false
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedClient : APIClient? = nil
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
        self.getAccessToken() { (success) in
            if (success) {
                self.authenticateIfNeeded()
                if (self.authenticated) {
                    self.updateAccountStatus()
                    NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
                }
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                    self.getAccessToken() { (success) in
                        if (success) {
                            self.authenticateIfNeeded()
                            if (self.authenticated) {
                                self.updateAccountStatus()
                            }
                        } else {
                            let notif = UILocalNotification()
                            notif.alertBody = "It looks like you restarted your phone! Plese unlock it to use Ride Report."
                            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
                        }
                    }
                })
            }
        }
        
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                NSNotificationCenter.defaultCenter().removeObserver(self, name: "CoreDataManagerDidStartup", object: nil)
                self.syncTrips()
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func appDidBecomeActive() {
        self.syncTrips()
        self.updateAccountStatus()
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
    
    func getAllTrips()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "trips", completionHandler: { (_, result) -> Void in
            switch result {
            case .Success(let json):
                for tripJson in json.array! {
                    if (Trip.tripWithUUID(tripJson["uuid"].string!) == nil) {
                        let trip = Trip()
                        trip.uuid = tripJson["uuid"].string!
                        trip.activityType = tripJson["activityType"].number!
                        trip.rating = tripJson["rating"].number!
                        trip.isClosed = true
                        trip.isSynced = true
                        trip.locationsAreSynced = true
                        trip.length = tripJson["length"].number!
                        trip.creationDate = self.jsonDateFormatter.dateFromString(tripJson["creationDate"].string!)
                        trip.locationsNotYetDownloaded = true
                    }
                }
                CoreDataManager.sharedManager.saveContext()
            case .Failure(_, let error):
                DDLogError(String(format: "Error retriving getting trip data: %@", error as NSError))
            }
        })
    }
    
    func getTrip(trip: Trip)->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "trips/" + trip.uuid, completionHandler: { (_, result) -> Void in
            switch result {
            case .Success(let json):
                trip.locations = NSOrderedSet() // just in case
                for locationJson in json["locations"].array! {
                    let loc = Location(trip: trip)
                    loc.date = self.jsonDateFormatter.dateFromString(locationJson["date"].string!)
                    loc.latitude = locationJson["latitude"].number!
                    loc.longitude = locationJson["longitude"].number!
                    loc.course = locationJson["course"].number!
                    loc.speed = locationJson["speed"].number!
                    loc.horizontalAccuracy = locationJson["horizontalAccuracy"].number!
                }
                trip.locationsNotYetDownloaded = false
                CoreDataManager.sharedManager.saveContext()
            case .Failure(_, let error):
                DDLogError(String(format: "Error retriving getting individual trip data: %@", error as NSError))
            }
        })

    }
    
    func deleteTrip(trip: Trip)->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.DELETE, route: "trips/" + trip.uuid, completionHandler: { (response, result) -> Void in
            switch result {
            case .Success(_), .Failure(_,_) where response?.statusCode == 404:
                // it's possible the server already deleted the object, in which case it will send a 404.
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    trip.managedObjectContext?.deleteObject(trip)
                    CoreDataManager.sharedManager.saveContext()
                })
            case .Failure(_, let error):
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    let alert = UIAlertView(title:nil, message: "There was an error deleting that trip. Please try again later.", delegate: nil, cancelButtonTitle:"Darn")
                    alert.show()
                })
                DDLogError(String(format: "Error deleting trip data: %@", error as NSError))
            }
        })
        
    }
    
    func syncTrips(syncInBackground: Bool = false) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            for aTrip in Trip.closedUnsyncedTrips() {
                let trip = aTrip as! Trip
                self.saveAndSyncTripIfNeeded(trip, syncInBackground: syncInBackground)
            }
        })
    }
    
    func saveAndSyncTripIfNeeded(trip: Trip, syncInBackground: Bool = false) {
        for incident in trip.incidents {
            if ((incident as! Incident).hasChanges) {
                trip.isSynced = false
            }
        }
        trip.saveAndMarkDirty()
        
        if (syncInBackground || UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
            self.syncTrip(trip)
        }
    }
    
    //
    // MARK: - Authenciated API Methods
    //
    
    func updateAccountStatus()-> AuthenticatedAPIRequest {
        var params : [String: String] = [:]
        if (RouteManager.hasStarted()) {
            if let loc = RouteManager.sharedManager.location {
                params["lnglat"] = String(loc.coordinate.longitude) + "," + String(loc.coordinate.latitude)
            }
        }
            
        return AuthenticatedAPIRequest(client: self, method:Alamofire.Method.POST, route: "status", parameters: params) { (response, result) -> Void in
            switch result {
            case .Success(let json):
                if let areaJson = json["area"].dictionary {
                    if let name = areaJson["name"]?.string, let count = areaJson["count_info"]?["count"].uInt, let countRatePerHour = areaJson["count_info"]?["per_hour"].uInt, let launched = areaJson["launched"]?.bool {
                        self.area = .Area(name: name, count: count, countRatePerHour: countRatePerHour, launched: launched)
                    } else {
                        self.area = .NonArea
                    }
                    NSNotificationCenter.defaultCenter().postNotificationName("APIClientAccountStatusDidGetArea", object: nil)
                } else {
                    self.area = .Unknown
                }
                
                if let account_verified = json["account_verified"].bool {
                    if (account_verified) {
                        if (self.accountVerificationStatus == .Unverified) {
                            // if we are just moved to an authenticated account, get any trips on the server
                            self.getAllTrips()
                        }
                        self.accountVerificationStatus = .Verified
                    } else {
                        self.accountVerificationStatus = .Unverified
                    }
                }
            case .Failure(_, let error):
                DDLogError(String(format: "Error retriving account status: %@", error as NSError))
                if (response?.statusCode == 401) {
                    self.deauthortizeClient()
                }
            }
        }
    }
    
    func logout()-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "logout") { (response, result) in
            switch result {
            case .Success(_):
                DDLogInfo("Logged out!")
                self.deauthortizeClient()
            case .Failure(_, let error):
                DDLogError(String(format: "Error logging out: %@", error as NSError))
                self.authenticateIfNeeded()
            }
        }
    }
    
    private func deauthortizeClient() {
        self.deleteAccessToken() { (success) -> Void in
            // if we can't do this, we are in a bad state.
            assert(success)
            
            Profile.deleteProfile()
            self.authenticateIfNeeded()
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
    
    private func syncTrip(trip: Trip) {
        if (trip.isSynced.boolValue || !trip.isClosed.boolValue) {
            return
        }
        
        if let existingRequest = self.tripRequests[trip] {
            // if an existing API request is in flight, wait to sync until after it completes
            
            existingRequest.requestCompletetionBlock = {
                // we need to reset isSynced since the changes were made after the request went out.
                trip.isSynced = false
                self.syncTrip(trip)
            }
            return
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
            routeURL = "trips/" + trip.uuid
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
        
        self.tripRequests[trip] = AuthenticatedAPIRequest(client: self, method: method, route: routeURL, parameters: tripDict) { (response, result) in
            self.tripRequests[trip] = nil
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
        
        return
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
        
        self.deleteAccessToken() { (success) in
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
                    self.saveAccessToken(accessToken, expiresIn: expiresIn) { (success) -> Void in
                        if (success) {
                            self.accountVerificationStatus = .Unverified
                        } else {
                            self.deauthortizeClient()
                        }
                    }
                }
            case .Failure(_, let error):
                if (response?.statusCode == 401) {
                    self.deauthortizeClient()
                }
                DDLogError(String(format: "Error retriving access token: %@", error as NSError))
                let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                alert.show()
            }

        }
    }

    
    //
    // MARK: - OAuth Token Keychain Management
    // It is very important that actual keychain code occurs on the main thread.
    //
    
    private var rideKeychainUserName = "Ride Report Access Token"
    private var accessToken: String? = nil

    private var keychainItem: Keychain {
        get {
            let keychain = Keychain(service: "com.Knock.Ride")
            .synchronizable(true)
            .accessibility(.AfterFirstUnlock)
            
            return keychain
        }
    }

    private func saveAccessToken(token: String, expiresIn: String, completionHandler:(Bool) -> Void = {(_) in }) {
        let data = ["accessToken" : token, "expiresIn" : expiresIn]
        let encodedData = NSKeyedArchiver.archivedDataWithRootObject(data)

        self.deleteAccessToken() { (success) in
            if (success) {
                dispatch_barrier_async(dispatch_get_main_queue(), { () -> Void in
                    do {
                        try self.keychainItem.set(encodedData, key: self.rideKeychainUserName)
                        self.accessToken = token
                        
                        completionHandler(true)
                    } catch let error {
                        
                        DDLogError(String(format: "Error storing access token: %@", error as NSError))
                        completionHandler(false)
                    }
                })
            } else {
                completionHandler(false)
            }
        }
    }
    
    private func deleteAccessToken(completionHandler:(Bool) -> Void = {(_) in }) {
        dispatch_barrier_async(dispatch_get_main_queue(), { () -> Void in
            if (self.accessToken == nil) {
                completionHandler(true)
                return
            }
            
            do {
                try self.keychainItem.remove(self.rideKeychainUserName)
                // make sure any old access token isn't memoized
                self.accessToken = nil
                
                completionHandler(true)
            } catch let error {
                DDLogError(String(format: "Error deleting access token: %@", error as NSError))
                completionHandler(false)
            }
        })
    }
    
    private func getAccessToken(completionHandler:(Bool) -> Void = {(_) in }) {
        self.keychainDataIsInaccessible = false
        dispatch_barrier_async(dispatch_get_main_queue(), { () -> Void in
            do {
                if let data = try self.keychainItem.getData(self.rideKeychainUserName) {
                    if let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? NSDictionary {
                        // make sure any old access token isn't memoized
                        self.accessToken = dict["accessToken"] as? String
                    }
                }
                
                completionHandler(true)
            } catch let err {
                let error = err as NSError
                DDLogError(String(format: "Error accessing access token: %@", error))
                if (error.code == Int(-34018)) {
                    // this is a special case. if we get this error, it's due to an obscure keychain bug causing the keychain to be temporarily inaccessible
                    // https://forums.developer.apple.com/message/9225#9225
                    // we'll want to try again later.
                    self.keychainDataIsInaccessible = true
                } else if (error.code == Int(errSecInteractionNotAllowed)) {
                    // this is a special case. if we get this error, it's because the device isn't unlocked yet.
                    // we'll want to try again later.
                    self.keychainDataIsInaccessible = true
                }
                completionHandler(false)
            }
        })
    }
}
