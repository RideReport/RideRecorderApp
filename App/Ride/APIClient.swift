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
import Mixpanel

public let AuthenticatedAPIRequestErrorDomain = "com.Knock.RideReport.error"
let APIRequestBaseHeaders = ["Content-Type": "application/json", "Accept": "application/json, text/plain"]

extension Request {
    public static func SwiftyJSONResponseSerializer(
        options options: NSJSONReadingOptions = .AllowFragments)
        -> ResponseSerializer<JSON, NSError>
    {
        return ResponseSerializer { _, _, data, error in
            if let theError = error {
                if let validData = data, jsonDict = SwiftyJSON.JSON(data: validData).dictionaryObject {
                    return .Failure(NSError(domain: theError.domain, code: theError.code, userInfo: jsonDict))
                } else {
                    return .Failure(theError)
                }
            }
            
            guard let validData = data where validData.length > 0 else {
                let failureReason = "JSON could not be serialized. Input data was nil or zero length."
                let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: failureReason)
                return .Failure(error)
            }
            
            let json:JSON = SwiftyJSON.JSON(data: validData)
            if let jsonError = json.error {
                return Result.Failure(jsonError)
            }
            
            return Result.Success(json)
        }
    }
    
    public func responseSwiftyJSON(
        options options: NSJSONReadingOptions = .AllowFragments,
        completionHandler: Response<JSON, NSError> -> Void)
        -> Self
    {
        return response(
            responseSerializer: Request.SwiftyJSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}

class AuthenticatedAPIRequest {
    typealias APIResponseBlock = Response<JSON, NSError> -> Void

    // a block that fires once at completion, unlike APIResponseBlocks which are appended
    var requestCompletetionBlock: ()->Void = {}
    
    var request: Request? = nil
    private var authToken: String?
    
    enum AuthenticatedAPIRequestErrorCode: Int {
        case Unauthenticated = 1
        case DuplicateRequest
        case ClientAborted
    }
    
    #if (arch(i386) || arch(x86_64)) && os(iOS)
    static var serverAddress = "https://api.ride.report/api/v2/"
    #else
    static var serverAddress = "https://api.ride.report/api/v2/"
    #endif
    
    class func unauthenticatedResponse() -> Response<JSON, NSError> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.Unauthenticated.rawValue, userInfo: nil)
        
        return Response(request: nil, response: nil, data: nil, result: .Failure(error))
    }
    
    class func duplicateRequestResponse() -> Response<JSON, NSError> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.DuplicateRequest.rawValue, userInfo: nil)
        
        return Response(request: nil, response: nil, data: nil, result: .Failure(error))
    }
    
    class func clientAbortedResponse() -> Response<JSON, NSError> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.ClientAborted.rawValue, userInfo: nil)
        
        return Response(request: nil, response: nil, data: nil, result: .Failure(error))
    }
    
    convenience init(clientAbortedWithResponse response: Response<JSON, NSError>, completionHandler: APIResponseBlock = {(_) in }) {
        self.init()

        completionHandler(response)
    }
    
    convenience init(client: APIClient, method: Alamofire.Method, route: String, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = ParameterEncoding.JSON.gzipped, idempotencyKey: String? = nil, authenticated: Bool = true, completionHandler: APIResponseBlock) {
        self.init()
        
        if (authenticated && !client.authenticated) {
            client.authenticateIfNeeded()
            completionHandler(AuthenticatedAPIRequest.unauthenticatedResponse())
            self.requestCompletetionBlock()
            return
        }
        
        var headers = APIRequestBaseHeaders
        
        // for some reason configuring headers on the session fails.
        for (key,value) in Manager.defaultHTTPHeaders {
            headers[key] = value
        }
        
        if let token = Profile.profile().accessToken where authenticated {
            self.authToken = token
            headers["Authorization"] =  "Bearer \(token)"
        }
        if let theIdempotencyKey = idempotencyKey {
            headers["Idempotence-Key"] = theIdempotencyKey
        }
        
        self.request = client.manager.request(method, AuthenticatedAPIRequest.serverAddress + route, parameters: parameters, encoding: encoding, headers: headers)
        
        let handleHTTPResonseErrors = { (response: NSHTTPURLResponse?) in
            if (response?.statusCode == 401) {
                dispatch_async(dispatch_get_main_queue(), {
                    if (self.authToken == Profile.profile().accessToken) {
                        // make sure the token that generated the 401 is still current
                        // since it is possible we've already reauthenciated
                        client.reauthenticate()
                    }
                })
            } else if (response?.statusCode == 500) {
                dispatch_async(dispatch_get_main_queue(), {
                    let alert = UIAlertView(title:nil, message: "OOps! Something is wrong on our end. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Trombone")
                    alert.show()
                })
            }
        }
        
        if (method == .DELETE) {
            // delete does not return JSON https://github.com/KnockSoftware/rideserver/issues/48
            request!.validate().responseString(encoding: NSASCIIStringEncoding, completionHandler: { (response) in
                let jsonResponse: Response<JSON, NSError> = Response(request: response.request, response: response.response, data: response.data, result: Result.Success(JSON("")))
                switch response.result {
                case .Success(_):
                    completionHandler(jsonResponse)
                case .Failure(_):
                    handleHTTPResonseErrors(response.response)
                    completionHandler(jsonResponse)
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            })
        } else {
            request!.validate().responseSwiftyJSON { (response) in
                switch response.result {
                case .Success(_):
                    completionHandler(response)
                case .Failure(_):
                    handleHTTPResonseErrors(response.response)
                    completionHandler(response)
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            }
        }
    }
    
    func apiResponse(completionHandler: APIResponseBlock)->AuthenticatedAPIRequest {
        if (self.request == nil) {
            completionHandler(AuthenticatedAPIRequest.unauthenticatedResponse())
            return self
        }
        
        self.request!.responseSwiftyJSON { (response) in
            switch response.result {
            case .Success(_):
                completionHandler(response)
            case .Failure(_):
                completionHandler(response)
            }
        }
        
        return self
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
    
    var hasRegisteredForRemoteNotifications: Bool = false
    var notificationDeviceToken: NSData?
    
    private var manager : Manager
    var isMigrating = false
    private var tripRequests : [Trip: AuthenticatedAPIRequest] = [:]
    private var didEncounterUnrecoverableErrorSyncronizingTrips = false
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
    
    class func startup(useDefaultConfiguration: Bool = false) {
        if (Static.sharedClient == nil) {
            Static.sharedClient = APIClient(useDefaultConfiguration: useDefaultConfiguration)
            dispatch_async(dispatch_get_main_queue()) {
                // run startup async
                Static.sharedClient?.startup()
            }
        }
    }
    
    private func startup() {
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NSNotificationCenter.defaultCenter().removeObserver(strongSelf, name: "CoreDataManagerDidStartup", object: nil)
                strongSelf.authenticateIfNeeded().apiResponse() { (_) -> Void in
                    strongSelf.syncStatusAndTripsInForeground()
                }
            }
        } else {
            self.authenticateIfNeeded().apiResponse() { (_) -> Void in
                self.syncStatusAndTripsInForeground()
            }
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(APIClient.appDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
        })
    }
    
    
    init (useDefaultConfiguration: Bool = false) {
        var configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.Knock.RideReport.background")
        
        if useDefaultConfiguration {
            // used for testing
            configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        }
        configuration.timeoutIntervalForRequest = 10
        let serverTrustPolicies : [String: ServerTrustPolicy] = [
            "api.ride.report": ServerTrustPolicy.PinPublicKeys(publicKeys: ServerTrustPolicy.publicKeysInBundle(), validateCertificateChain: true, validateHost: true)
        ]
        self.manager = Alamofire.Manager(configuration: configuration, serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //
    // MARK: - Setup
    //
    
    @objc func appDidBecomeActive() {
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NSNotificationCenter.defaultCenter().removeObserver(strongSelf, name: "CoreDataManagerDidStartup", object: nil)
                strongSelf.syncStatusAndTripsInForeground()
            }
        } else {
            self.syncStatusAndTripsInForeground()
        }
    }
    
    func appDidReceiveNotificationDeviceToken(token: NSData?) {
        self.hasRegisteredForRemoteNotifications = true
        self.notificationDeviceToken = token
        self.updateAccountStatus()
    }
    
    private func syncStatusAndTripsInForeground() {
        if (self.authenticated) {
            // do account status even in the background
            self.updateAccountStatus()

            if (UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
                self.runMigrations()
                
                self.syncUnsyncedTrips()
            }
        }

    }
    
    //
    // MARK: - Migrations
    //
    
    private func runMigrations() {
        let hasRunTripsListOnSummaryAPIAtLeastOnce = NSUserDefaults.standardUserDefaults().boolForKey("hasRunTripRewardToTripRewardsMigration")
        if (!hasRunTripsListOnSummaryAPIAtLeastOnce) {
            self.isMigrating = true

            let _ = AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "trips", completionHandler: { (response) -> Void in
                switch response.result {
                case .Success(let json):
                        for tripJson in json.array! {
                            // to make this not take forefver, only change the trips with rewards
                            if let uuid = tripJson["uuid"].string, summary = tripJson["summary"].dictionary where (summary["rewards"] != nil || (summary["rewardEmoji"] != nil && summary["rewardEmoji"]?.string != "")) {
                                if let trip = Trip.tripWithUUID(uuid) {
                                    trip.loadSummaryFromJSON(summary)
                                }
                            }
                        }
                        
                        CoreDataManager.sharedManager.saveContext()
                        
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasRunTripRewardToTripRewardsMigration")
                        NSUserDefaults.standardUserDefaults().synchronize()
                case .Failure(let error):
                    DDLogWarn(String(format: "Error retriving getting trip data: %@", error))
                }
                
                self.isMigrating = false
            })
        }
    }
    
    private func runDataMigration(dataMigrationName name: String, handler: ()->Void) {
        let migrationHasHappened = NSUserDefaults.standardUserDefaults().boolForKey(name)
        if (!migrationHasHappened) {
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: name)
            NSUserDefaults.standardUserDefaults().synchronize()
            
            handler()
        }
    }
    
    //
    // MARK: - Trip Synchronization
    //
    
    func getAllTrips()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "trips", completionHandler: { (response) -> Void in
            switch response.result {
            case .Success(let json):
                for tripJson in json.array! {
                    if let uuid = tripJson["uuid"].string, creationDateString = tripJson["creationDate"].string, creationDate = NSDate.dateFromJSONString(creationDateString) {
                        var trip = Trip.tripWithUUID(uuid)
                        if (trip == nil) {
                            trip = Trip()
                            trip.uuid = uuid
                            trip.locationsNotYetDownloaded = true
                        }
                        
                        trip.creationDate = creationDate
                        trip.isClosed = true
                        trip.isSynced = true
                        trip.locationsAreSynced = true
                        trip.summaryIsSynced = true
                        
                        if let activityTypeNumber = tripJson["activityType"].number,
                                rating = tripJson["rating"].number,
                                length = tripJson["length"].number,
                                activityType = ActivityType(rawValue: activityTypeNumber.shortValue) {
                            trip.activityType = activityType
                            trip.rating = rating
                            trip.length = length.floatValue
                        }
                        
                        if let summary = tripJson["summary"].dictionary {
                            trip.loadSummaryFromJSON(summary)
                        }
                    }
                }
                CoreDataManager.sharedManager.saveContext()
            case .Failure(let error):
                DDLogWarn(String(format: "Error retriving getting trip data: %@", error))
            }
        })
    }
    
    func getTrip(trip: Trip)->AuthenticatedAPIRequest {
        guard let uuid = trip.uuid else {
            // the server doesn't know about this trip yet
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "trips/" + uuid, completionHandler: { (response) -> Void in
            switch response.result {
            case .Success(let json):
                if trip.locationsNotYetDownloaded {
                    trip.locations = NSOrderedSet() // just in case
                    if let locations = json["locations"].array {
                        for locationJson in locations {
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
                                if let isGeofencedLocation = locationJson["isGeofencedLocation"].bool {
                                    loc.isGeofencedLocation = isGeofencedLocation
                                }
                            } else {
                                DDLogWarn("Error parsing location dictionary when fetched trip data!")
                            }
                        }
                    } else {
                        DDLogWarn("Error parsing location dictionary when fetched trip data, no locations found.")
                    }
                    
                    trip.locationsNotYetDownloaded = false
                }
                
                if let summary = json["summary"].dictionary {
                    trip.loadSummaryFromJSON(summary)
                }

                CoreDataManager.sharedManager.saveContext()
            case .Failure(let error):
                DDLogWarn(String(format: "Error retriving getting individual trip data: %@", error))
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
            
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.DELETE, route: "trips/" + uuid, completionHandler: { (response) -> Void in
            switch response.result {
            case .Success(_), .Failure(_) where response.response != nil && response.response!.statusCode == 404:
                // it's possible the server already deleted the object, in which case it will send a 404.
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    trip.managedObjectContext?.deleteObject(trip)
                    CoreDataManager.sharedManager.saveContext()
                })
            case .Failure(let error):
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    let alert = UIAlertView(title:nil, message: "There was an error deleting that trip. Please try again later.", delegate: nil, cancelButtonTitle:"Darn")
                    alert.show()
                })
                DDLogWarn(String(format: "Error deleting trip data: %@", error))
            }
        })
        
    }
    
    func syncUnsyncedTrips(syncInBackground: Bool = false, completionBlock: ()->Void = {}) {
        self.didEncounterUnrecoverableErrorSyncronizingTrips = false
        self.syncNextUnsyncedTrip(syncInBackground, completionBlock: completionBlock)
    }
    
    private func syncNextUnsyncedTrip(syncInBackground: Bool = false, completionBlock: ()->Void = {}) {
        if (syncInBackground || UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
            if let trip = Trip.nextClosedUnsyncedTrips() where !self.didEncounterUnrecoverableErrorSyncronizingTrips {
                self.syncTrip(trip).apiResponse({ (_) -> Void in
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.6 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                        self.syncNextUnsyncedTrip(syncInBackground, completionBlock: completionBlock)
                    })
                })
            } else {
                completionBlock()
            }
        }
    }
    
    func saveAndSyncTripIfNeeded(trip: Trip, syncInBackground: Bool = false, includeLocations: Bool = true)->AuthenticatedAPIRequest {
        for incident in trip.incidents {
            if ((incident as! Incident).hasChanges) {
                trip.isSynced = false
            }
        }
        trip.saveAndMarkDirty()
        
        if (!trip.isSynced.boolValue && (syncInBackground || UIApplication.sharedApplication().applicationState == UIApplicationState.Active)) {
            return self.syncTrip(trip, includeLocations: includeLocations)
        }
        
        return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
    }
    
    func uploadSensorData(trip: Trip, withMetadata metadataDict:[String: AnyObject] = [:]) {
        let routeURL = "trips/" + trip.uuid + "/sensor_data"
        
        var sensorDataJsonArray : [[String: AnyObject]] = []
        for sensorDataCollection in trip.sensorDataCollections {
            sensorDataJsonArray.append((sensorDataCollection as! SensorDataCollection).jsonDictionary())
        }
        
        var params = metadataDict
        params["data"] = sensorDataJsonArray
        
        _ = AuthenticatedAPIRequest(client: self, method: .POST, route: routeURL, parameters:params , authenticated: true) { (response) in
            switch response.result {
            case .Success(_):
                DDLogWarn("Yep")
            case .Failure(_):
                DDLogWarn("Nope!")
            }
        }
    }
    
    func uploadSensorDataCollection(sensorDataCollection: SensorDataCollection, withMetadata metadataDict:[String: AnyObject] = [:]) {
        let accelerometerRouteURL = "ios_accelerometer_data"
        var params = metadataDict
        params["data"] = sensorDataCollection.jsonDictionary()

        _ = AuthenticatedAPIRequest(client: self, method: .POST, route: accelerometerRouteURL, parameters:params , authenticated: false) { (response) in
            switch response.result {
            case .Success(_):
                DDLogWarn("Yep")
            case .Failure(_):
                DDLogWarn("Nope!")
            }
        }
    }
    
    func syncTrip(trip: Trip, includeLocations: Bool = true)->AuthenticatedAPIRequest {
        guard (trip.isClosed.boolValue) else {
            DDLogWarn("Tried to sync trip info on unclosed trip!")
            
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        if let existingRequest = self.tripRequests[trip] {
            // if an existing API request is in flight and we have local changes, wait to sync until after it completes
            
            if !trip.isSynced {
                existingRequest.requestCompletetionBlock = {
                    // we need to reset isSynced since the changes were made after the request went out.
                    trip.isSynced = false
                    self.syncTrip(trip, includeLocations: includeLocations)
                }
                return existingRequest
            } else {
                // if we dont have local changes, simply skip this
                return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
            }
        }
        
        let routeURL = "trips/" + trip.uuid
        
        var method = Alamofire.Method.PUT
        var tripDict = [
            "activityType": NSNumber(short: trip.activityType.rawValue),
            "creationDate": trip.creationDate.JSONString(),
            "rating": trip.rating
        ]

        if (!trip.locationsAreSynced.boolValue && !includeLocations) {
            // initial synchronization of trip data - the server does not know about the locations yet
            // so we provide them in order to get back summary information. record may or may not exist so we PUT.
            guard let startingLocation = trip.bestStartLocation(), endingLocation = trip.bestEndLocation() else {
                DDLogWarn("No starting and/or ending location found when syncing trip locations!")
                trip.locationsAreSynced = false
                CoreDataManager.sharedManager.saveContext()

                return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
            }
            
            tripDict["length"] = trip.length
            tripDict["startLocation"] = startingLocation.jsonDictionary()
            tripDict["endLocation"] = endingLocation.jsonDictionary()
        } else if (!trip.locationsAreSynced.boolValue) {
            // upload location data has not been synced, do it now.
            // record may or may not exist, so we PUT
            
            var locations : [AnyObject!] = []
            for location in trip.locations.array {
                locations.append((location as! Location).jsonDictionary())
            }
            tripDict["locations"] = locations
        } else {
            // location data has been synced. Record exists and we are not uploading everything, so we PATCH.
            method = Alamofire.Method.PATCH
        }
        
        self.tripRequests[trip] = AuthenticatedAPIRequest(client: self, method: method, route: routeURL, parameters: tripDict) { (response) in
            self.tripRequests[trip] = nil
            switch response.result {
            case .Success(let json):
                if let summary = json["summary"].dictionary {
                    trip.loadSummaryFromJSON(summary)
                }
                trip.isSynced = true
                if includeLocations {
                    trip.locationsAreSynced = true
                }
                
                if let accountStatus = json["accountStatus"].dictionary, statusText = accountStatus["status_text"]?.string, statusEmoji = accountStatus["status_emoji"]?.string {
                    Profile.profile().statusText = statusText
                    Profile.profile().statusEmoji = statusEmoji
                }
                
                CoreDataManager.sharedManager.saveContext()
            case .Failure(let error):
                DDLogWarn(String(format: "Error syncing trip: %@", error))

                if let httpResponse = response.response where httpResponse.statusCode == 409 {
                    // a trip with that UUID exists. retry.
                    trip.generateUUID()
                    self.saveAndSyncTripIfNeeded(trip, includeLocations: includeLocations)
                } else if let httpResponse = response.response where httpResponse.statusCode == 404 {
                    // server doesn't know about trip, reset locationsAreSynced
                    trip.locationsAreSynced = false
                    CoreDataManager.sharedManager.saveContext()
                } else {
                    self.didEncounterUnrecoverableErrorSyncronizingTrips = true
                }
            }
        }
        
        return self.tripRequests[trip]!
    }
    
    //
    // MARK: - Application API Methods
    //
    
    
    func getAllApplications()-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "applications") { (response) -> Void in
            switch response.result {
            case .Success(let json):
                if let apps = json.array {
                    var appsToDelete = ConnectedApp.allApps()
                    
                    for appDict in apps {
                        if let app = ConnectedApp.createOrUpdate(withJson: appDict), index = appsToDelete.indexOf(app) {
                            appsToDelete.removeAtIndex(index)
                        }
                    }
                    
                    for app in appsToDelete {
                        // delete any app objects we did not receive
                        if !app.isHiddenApp {
                            CoreDataManager.sharedManager.currentManagedObjectContext().deleteObject(app)
                        }
                    }
                    
                    CoreDataManager.sharedManager.saveContext()
                }
            case .Failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error))
            }
        }
    }
    
    func getApplication(app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "applications/" + app.uuid) { (response) -> Void in
            switch response.result {
            case .Success(let json):
                app.updateWithJson(withJson: json)
            case .Failure(let error):
                DDLogWarn(String(format: "Error getting third party app: %@", error))
            }
        }
    }
    
    func connectApplication(app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "applications/" + app.uuid + "/connect", parameters: app.json().dictionaryObject) { (response) -> Void in
            switch response.result {
            case .Success(let json):
                if let httpsResponse = response.response where httpsResponse.statusCode == 200 {
                    ConnectedApp.createOrUpdate(withJson: json)
                    app.profile = Profile.profile()
                    CoreDataManager.sharedManager.saveContext()
                }
            case .Failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error))
            }
        }
    }
    
    func disconnectApplication(app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "applications/" + app.uuid + "/disconnect") { (response) -> Void in
            switch response.result {
            case .Success(_):
                app.profile = nil
                CoreDataManager.sharedManager.saveContext()
            case .Failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error))
            }
        }
    }

    
    //
    // MARK: - Authenciatation API Methods
    //
    
    func updateAccountStatus()-> AuthenticatedAPIRequest {
        guard self.hasRegisteredForRemoteNotifications else {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        var parameters: [String: AnyObject] = [:]
        if let deviceToken = self.notificationDeviceToken {
            parameters["device_token"] = deviceToken.hexadecimalString()
            #if DEBUG
                parameters["is_development_client"] = true
            #endif
        }
        
        if (RouteManager.hasStarted()) {
            if let loc = RouteManager.sharedManager.location {
                parameters["lnglat"] = String(loc.coordinate.longitude) + "," + String(loc.coordinate.latitude)
            }
        }
            
        return AuthenticatedAPIRequest(client: self, method:Alamofire.Method.POST, route: "status", parameters: parameters) { (response) -> Void in
            switch response.result {
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
                
                
                if let statusText = json["status_text"].string, statusEmoji = json["status_emoji"].string {
                    Profile.profile().statusText = statusText
                    Profile.profile().statusEmoji = statusEmoji
                }
                
                if let connectedApps = json["connected_apps"].array {
                    var appsToDelete = ConnectedApp.allApps()
                    
                    for appDict in connectedApps {
                        if let app = ConnectedApp.createOrUpdate(withJson: appDict) {
                            if let index = appsToDelete.indexOf(app) {
                                appsToDelete.removeAtIndex(index)
                            }
                            app.profile = Profile.profile()
                        }
                    }
                    
                    for app in appsToDelete {
                        // delete any app objects we did not receive
                        app.profile = nil
                    }
                }
                
                CoreDataManager.sharedManager.saveContext()
                NSNotificationCenter.defaultCenter().postNotificationName("APIClientStatusTextDidChange", object: nil)
                
                if let mixPanelID = json["mixpanel_id"].string {
                    Mixpanel.sharedInstance().identify(mixPanelID)
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
            case .Failure(let error):
                DDLogWarn(String(format: "Error retriving account status: %@", error))
            }
        }
    }
    
    func logout()-> AuthenticatedAPIRequest {
        Profile.resetProfile()
        
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "logout") { (response) in
            switch response.result {
            case .Success(_):
                self.reauthenticate()
                DDLogInfo("Logged out!")
            case .Failure(let error):
                DDLogWarn(String(format: "Error logging out: %@", error))
                self.authenticateIfNeeded()
            }
        }
    }
    
    func sendVerificationTokenForEmail(email: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "send_email_code", parameters: ["email": email]) { (response) in
            switch response.result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .Failure(let error):
                DDLogWarn(String(format: "Error sending verification email: %@", error))
                
                if let httpResponse = response.response where httpResponse.statusCode == 400 {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        let alert = UIAlertView(title:nil, message: "That doesn't look like a valid email address. Please double-check your typing and try again.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    })
                }
            }
        }
    }
    
    func verifyToken(token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "verify_email_code", parameters: ["code": token]) { (response) in
            switch response.result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .Failure(let error):
                DDLogWarn(String(format: "Error verifying email token: %@", error))
            }
        }
    }
    
    func verifyFacebook(token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.POST, route: "verify_facebook_login", parameters: ["token": token]) { (response) in
            switch response.result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .Failure(let error):
                DDLogWarn(String(format: "Error verifying facebook token: %@", error))
                if let httpResponse = response.response where httpResponse.statusCode == 400 {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        let alert = UIAlertView(title:nil, message: "There was an error communicating with Facebook. Please try again later or use sign up using your email address instead.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    })
                }
            }
        }
    }
    
    func testAuthID()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "oauth_info") { (response) in
            switch response.result {
            case .Success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .Failure(let error):
                DDLogWarn(String(format: "Error retriving access token: %@", error))
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
    
    func authenticateIfNeeded()->AuthenticatedAPIRequest {
        if (self.authenticated || self.isRequestingAuthentication) {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        self.isRequestingAuthentication = true
        
        let parameters = ["client_id" : "1ARN1fJfH328K8XNWA48z6z5Ag09lWtSSVRHM9jw", "response_type" : "token"]
        
        return AuthenticatedAPIRequest(client: self, method: Alamofire.Method.GET, route: "oauth_token", parameters: parameters, encoding: .URL, authenticated: false) { (response) in
            self.isRequestingAuthentication = false
            
            switch response.result {
            case .Success(let json):
                if let accessToken = json["access_token"].string, expiresInString = json["expires_in"].string, expiresInInt = Int(expiresInString) {
                    let expiresIn = NSDate().secondsFrom(expiresInInt)
                    if (Profile.profile().accessToken == nil) {
                        Profile.profile().accessToken = accessToken
                        Profile.profile().accessTokenExpiresIn = expiresIn
                        CoreDataManager.sharedManager.saveContext()
                        self.updateAccountStatus()
                    } else {
                        DDLogWarn("Got a new access token when one was already set!")
                    }
                }
            case .Failure(let error):
                DDLogWarn(String(format: "Error retriving access token: %@", error))
                let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                alert.show()
            }
        }
    }
}
