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
import CZWeatherKit

#if (arch(i386) || arch(x86_64)) && os(iOS)
//let serverAddress = "https://localhost/api/v2/"
let serverAddress = "https://api.ride.report/api/v2/"
    #else
let serverAddress = "https://api.ride.report/api/v2/"
#endif

public let AuthenticatedAPIRequestErrorDomain = "com.Knock.RideReport.error"
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
    
    convenience init(client: APIClient, method: Alamofire.Method, route: String, parameters: [String: AnyObject]? = nil, idempotencyKey: String? = nil, completionHandler: APIResponseBlock) {
        self.init()
        
        if (!client.authenticated) {
            client.authenticateIfNeeded()
            completionHandler(nil, .Failure(nil, AuthenticatedAPIRequest.unauthenticatedError()))
            self.requestCompletetionBlock()
            return
        }
        
        var headers = APIRequestBaseHeaders
        if let token = Profile.profile().accessToken {
            self.authToken = token
            headers["Authorization"] =  "Bearer \(token)"
        }
        if let theIdempotencyKey = idempotencyKey {
            headers["Idempotence-Key"] = theIdempotencyKey
        }
        
        self.request = client.manager.request(method, serverAddress + route, parameters: parameters, encoding: ParameterEncoding.JSON.gzipped, headers: headers)
        
        let handleHTTPResonseErrors = { (response: NSHTTPURLResponse?) in
            if (response?.statusCode == 401) {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if (self.authToken == Profile.profile().accessToken) {
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
    
    private var manager : Manager
    private var tripRequests : [Trip: AuthenticatedAPIRequest] = [:]
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
        let startupBlock = {
            self.authenticateIfNeeded()
            if (self.authenticated) {
                self.updateAccountStatus()
                if (UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
                    self.syncTrips()
                    let hasRunTripUUIDMigrationUpload = NSUserDefaults.standardUserDefaults().boolForKey("HasRunTripUUIDMigrationUpload")
                    if (!hasRunTripUUIDMigrationUpload) {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.uploadTripUUIDs()
                        })
                    }
                }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                    // run after a second to avoid double-syncing.
                    NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
                })
            }
        }
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                NSNotificationCenter.defaultCenter().removeObserver(self, name: "CoreDataManagerDidStartup", object: nil)
                startupBlock()
            }
        } else {
            startupBlock()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func appDidBecomeActive() {
        self.authenticateIfNeeded()
        if (self.authenticated) {
            self.updateAccountStatus()
            self.syncTrips()
        }
    }
    
    init () {
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.Knock.RideReport.background")
        configuration.timeoutIntervalForRequest = 10
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
                    if let uuid = tripJson["uuid"].string, creationDateString = tripJson["creationDate"].string, creationDate = NSDate.dateFromJSONString(creationDateString) where Trip.tripWithUUID(uuid) == nil {
                        let trip = Trip()
                        trip.uuid = uuid
                        trip.activityType = tripJson["activityType"].number!
                        trip.rating = tripJson["rating"].number!
                        trip.isClosed = true
                        trip.isSynced = true
                        trip.locationsAreSynced = true
                        trip.length = tripJson["length"].number!
                        trip.creationDate = creationDate
                        trip.locationsNotYetDownloaded = true
                        
                        if let summary = json["summary"].dictionary {
                            trip.loadSummaryFromJSON(summary)
                        }
                    }
                }
                CoreDataManager.sharedManager.saveContext()
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error retriving getting trip data: %@", error as NSError))
            }
        })
    }
    
    func getTrip(trip: Trip)->AuthenticatedAPIRequest {
        guard let uuid = trip.uuid else {
            // the server doesn't know about this trip yet
            return AuthenticatedAPIRequest(requestError: AuthenticatedAPIRequest.clientAbortedError())
        }
        
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "trips/" + uuid, completionHandler: { (_, result) -> Void in
            switch result {
            case .Success(let json):
                trip.locations = NSOrderedSet() // just in case
                for locationJson in json["locations"].array! {
                    if let dateString = locationJson["date"].string, date = NSDate.dateFromJSONString(dateString),
                            latitude = locationJson["latitude"].number,
                            longitude = locationJson["longitude"].number,
                            course = locationJson["course"].number,
                            speed = locationJson["speed"].number,
                            horizontalAccuracy = locationJson["horizontalAccuracy"].number {
                        let loc = Location(trip: trip)
                        loc.date = date
                        loc.latitude = latitude
                        loc.longitude = longitude
                        loc.course = course
                        loc.speed = speed
                        loc.horizontalAccuracy = horizontalAccuracy
                    } else {
                        DDLogWarn("Error parsing location dictionary when fetched trip data!")
                    }
                }
                trip.locationsNotYetDownloaded = false

                CoreDataManager.sharedManager.saveContext()
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error retriving getting individual trip data: %@", error as NSError))
            }
        })
    }
    
    func deleteTrip(trip: Trip)->AuthenticatedAPIRequest {
        guard let uuid = trip.uuid else {
            // the server doesn't know about this trip yet
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                trip.managedObjectContext?.deleteObject(trip)
                CoreDataManager.sharedManager.saveContext()
            })
            
            return AuthenticatedAPIRequest(requestError: AuthenticatedAPIRequest.clientAbortedError())
        }
        
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.DELETE, route: "trips/" + uuid, completionHandler: { (response, result) -> Void in
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
                DDLogWarn(String(format: "Error deleting trip data: %@", error as NSError))
            }
        })
        
    }
    
    func uploadTripUUIDs()-> AuthenticatedAPIRequest {
        let uuids = Trip.allTripsWithUUIDs().map { trip in
            (trip as! Trip).uuid!
        }
        
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "uploadTripUUIDS", parameters: ["UUIDS": uuids]) { (response, result) in
            switch result {
            case .Success(_):
                NSUserDefaults.standardUserDefaults().setBool(true, forKey: "HasRunTripUUIDMigrationUpload")
                NSUserDefaults.standardUserDefaults().synchronize()

                DDLogInfo("Uploaded trip UUIDs!")
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error uploading uuids out: %@", error as NSError))
            }
        }
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
    
    func syncTripSummary(trip: Trip)->AuthenticatedAPIRequest {
        guard (trip.isClosed.boolValue) else {
            DDLogWarn("Tried to sync trip info on unclosed trip!")
            
            return AuthenticatedAPIRequest(requestError: AuthenticatedAPIRequest.clientAbortedError())
        }
        
        guard let startingLocation = trip.locations.firstObject as? Location, endingLocation = trip.locations.lastObject as? Location else {
            DDLogWarn("No starting and/or ending location found when syncing trip info!")

            return AuthenticatedAPIRequest(requestError: AuthenticatedAPIRequest.clientAbortedError())
        }
        
        guard self.tripRequests[trip] == nil else {
            // if an existing API request is in flight, simply skip this
            return AuthenticatedAPIRequest(requestError: AuthenticatedAPIRequest.clientAbortedError())
        }
        
        let tripDict = [
            "activityType": trip.activityType,
            "creationDate": trip.creationDate.JSONString(),
            "startLocation": startingLocation.jsonDictionary(),
            "endLocation": endingLocation.jsonDictionary()
        ]
        
        let routeURL = "trips"
        let method = Alamofire.Method.POST
        let idempotencyKey: String? = trip.creationDate.JSONString()
        
        self.tripRequests[trip] = AuthenticatedAPIRequest(client: self, method: method, route: routeURL, parameters: tripDict, idempotencyKey: idempotencyKey) { (response, result) in
            self.tripRequests[trip] = nil
            switch result {
            case .Success(let json):
                if trip.uuid == nil {
                    if let uuid = json["uuid"].string {
                        trip.uuid = uuid
                    } else {
                        DDLogWarn("Did not get a UUID back from server!")
                        return
                    }
                }
                
                if let summary = json["summary"].dictionary {
                    trip.loadSummaryFromJSON(summary)
                }
                    
                CoreDataManager.sharedManager.saveContext()
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error syncing trip: %@", error as NSError))
            }
        }
        
        return self.tripRequests[trip]!
    }
    
    private func syncTrip(trip: Trip) {
        guard (!trip.isSynced.boolValue && trip.isClosed.boolValue) else {
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
            "creationDate": trip.creationDate.JSONString(),
            "rating": trip.rating
        ]
        var routeURL = "trips"
        var method = Alamofire.Method.POST
        var idempotencyKey: String? = trip.creationDate.JSONString()

        if let uuid = trip.uuid {
            routeURL = "trips/" + uuid
            method = Alamofire.Method.PATCH
            
            // idempotence only applies to POST requests.
            idempotencyKey = nil
        }
        
        if (!trip.locationsAreSynced.boolValue) {
            var locations : [AnyObject!] = []
            for location in trip.locations.array {
                locations.append((location as! Location).jsonDictionary())
            }
            tripDict["locations"] = locations
        }
        
        self.tripRequests[trip] = AuthenticatedAPIRequest(client: self, method: method, route: routeURL, parameters: tripDict, idempotencyKey: idempotencyKey) { (response, result) in
            self.tripRequests[trip] = nil
            switch result {
            case .Success(let json):
                if trip.uuid == nil {
                    if let uuid = json["uuid"].string {
                        trip.uuid = uuid
                    } else {
                        DDLogWarn("Did not get a UUID back from server!")
                        return
                    }
                }
                trip.isSynced = true
                trip.locationsAreSynced = true
                CoreDataManager.sharedManager.saveContext()
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error syncing trip: %@", error as NSError))
            }
        }
        
        return
    }

    
    //
    // MARK: - Authenciatation API Methods
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
                DDLogWarn(String(format: "Error retriving account status: %@", error as NSError))
            }
        }
    }
    
    func logout()-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "logout") { (response, result) in
            switch result {
            case .Success(_):
                self.reauthenticate()
                DDLogInfo("Logged out!")
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error logging out: %@", error as NSError))
                self.authenticateIfNeeded()
            }
        }
    }
    
    func sendVerificationTokenForEmail(email: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "send_email_code", parameters: ["email": email]) { (response, result) in
            switch result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error sending verification email: %@", error as NSError))
                
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
                DDLogWarn(String(format: "Error verifying email token: %@", error as NSError))
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
                DDLogWarn(String(format: "Error verifying facebook token: %@", error as NSError))
                if let code = response?.statusCode where code == 400 {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        let alert = UIAlertView(title:nil, message: "There was an error communicating with Facebook. Please try again later or use sign up using your email address instead.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    })
                }
            }
        }
    }
    
    func testAuthID()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "oauth_info") { (response, result) in
            switch result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error retriving access token: %@", error as NSError))
            }
        }
    }
    
    //
    // MARK: - OAuth
    //
    
    var authenticated: Bool {
        return (Profile.profile().accessToken != nil)
    }
    
    func reauthenticate() {
        if (!self.authenticated) {
            // avoid duplicate reauthenticate requests
            return
        }
        
        Profile.profile().accessToken = nil
        Profile.profile().accessTokenExpiresIn = nil
        CoreDataManager.sharedManager.saveContext()
        
        self.authenticateIfNeeded()
    }
    
    func authenticateIfNeeded() {
        if (self.authenticated || self.isRequestingAuthentication) {
            return
        }
        
        self.isRequestingAuthentication = true
        
        let parameters = ["client_id" : "1ARN1fJfH328K8XNWA48z6z5Ag09lWtSSVRHM9jw", "response_type" : "token"]
        
        self.manager.request(.GET, serverAddress + "oauth_token", parameters: parameters, encoding: .URL, headers: APIRequestBaseHeaders).validate().responseJSON { (request, response, result) in
            self.isRequestingAuthentication = false

            switch result {
            case .Success(let jsonData):
                let json = JSON(jsonData)
                
                if let accessToken = json["access_token"].string, expiresInString = json["expires_in"].string, expiresIn = NSDate.dateFromJSONString(expiresInString) {
                    if (Profile.profile().accessToken == nil) {
                        Profile.profile().accessToken = accessToken
                        Profile.profile().accessTokenExpiresIn = expiresIn
                        CoreDataManager.sharedManager.saveContext()
                        self.updateAccountStatus()
                    } else {
                        DDLogWarn("Got a new access token when one was already set!")
                    }
                }
            case .Failure(_, let error):
                DDLogWarn(String(format: "Error retriving access token: %@", error as NSError))
                let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                alert.show()
            }

        }
    }
}
