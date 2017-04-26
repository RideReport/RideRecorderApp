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

private enum HKBiologicalSex : Int {
    case notSet
    case female
    case male
    @available(iOS 8.2, *)
    case other
}

public let AuthenticatedAPIRequestErrorDomain = "com.Knock.RideReport.error"
let APIRequestBaseHeaders = ["Content-Type": "application/json", "Accept": "application/json, text/plain"]

extension DataRequest {
    
    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
    @discardableResult
    public func responseSwiftyJSON(
        queue: DispatchQueue? = nil,
        options: JSONSerialization.ReadingOptions = .allowFragments,
        completionHandler: @escaping (DataResponse<JSON>) -> Void) -> Self {
        return response(
            queue: queue,
            responseSerializer: DataRequest.swiftyJSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
    
    /// Creates a response serializer that returns a SwiftyJSON instance result type constructed from the response data using
    /// `JSONSerialization` with the specified reading options.
    ///
    /// - parameter options: The JSON serialization reading options. Defaults to `.allowFragments`.
    ///
    /// - returns: A SwiftyJSON response serializer.
    public static func swiftyJSONResponseSerializer(
        options: JSONSerialization.ReadingOptions = .allowFragments) -> DataResponseSerializer<JSON> {
        return DataResponseSerializer { _, response, data, error in
            let result = Request.serializeResponseJSON(options: options, response: response, data: data, error: error)
            switch result {
            case .success(let value):
                return .success(JSON(value))
            case .failure(let error):
                return .failure(error)
            }
        }
    }
}

class AuthenticatedAPIRequest {
    typealias APIResponseBlock = (DataResponse<JSON>) -> Void

    // a block that fires once at completion, unlike APIResponseBlocks which are appended
    var requestCompletetionBlock: ()->Void = {}
    
    var request: DataRequest? = nil
    private var authToken: String?
    
    enum AuthenticatedAPIRequestErrorCode: Int {
        case unauthenticated = 1
        case duplicateRequest
        case clientAborted
    }
    
    #if (arch(i386) || arch(x86_64)) && os(iOS)
    static var serverAddress = "https://api.ride.report/api/v2/"
    #else
    static var serverAddress = "https://api.ride.report/api/v2/"
    #endif
    
    class func unauthenticatedResponse() -> DataResponse<JSON> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.unauthenticated.rawValue, userInfo: nil)
        
        return DataResponse(request: nil, response: nil, data: nil, result: .failure(error))
    }
    
    class func duplicateRequestResponse() -> DataResponse<JSON> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.duplicateRequest.rawValue, userInfo: nil)
        
        return DataResponse(request: nil, response: nil, data: nil, result: .failure(error))
    }
    
    class func clientAbortedResponse() -> DataResponse<JSON> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.clientAborted.rawValue, userInfo: nil)
        
        return DataResponse(request: nil, response: nil, data: nil, result: .failure(error))
    }
    
    convenience init(clientAbortedWithResponse response: DataResponse<JSON>, completionHandler: APIResponseBlock = {(_) in }) {
        self.init()

        completionHandler(response)
    }
    
    convenience init(client: APIClient, method: Alamofire.HTTPMethod, route: String, parameters: [String: Any]? = nil, encoding: ParameterEncoding = GZipEncoding.default, idempotencyKey: String? = nil, authenticated: Bool = true, completionHandler: @escaping APIResponseBlock) {
        self.init()
        
        if (authenticated && !client.authenticated) {
            client.authenticateIfNeeded()
            completionHandler(AuthenticatedAPIRequest.unauthenticatedResponse())
            self.requestCompletetionBlock()
            return
        }
        
        var headers = APIRequestBaseHeaders
        
        // for some reason configuring headers on the session fails.
        for (key,value) in SessionManager.defaultHTTPHeaders {
            headers[key] = value
        }
        
        if let token = Profile.profile().accessToken, authenticated {
            self.authToken = token
            headers["Authorization"] =  "Bearer \(token)"
        }
        if let theIdempotencyKey = idempotencyKey {
            headers["Idempotence-Key"] = theIdempotencyKey
        }

        self.request = client.sessionManager.request(AuthenticatedAPIRequest.serverAddress + route, method: method, parameters: parameters, encoding: encoding, headers: headers)
        
        let handleHTTPResonseErrors = { (response: HTTPURLResponse?) in
            if (response?.statusCode == 401) {
                DispatchQueue.main.async {
                    if (self.authToken == Profile.profile().accessToken) {
                        // make sure the token that generated the 401 is still current
                        // since it is possible we've already reauthenciated
                        client.reauthenticate()
                    }
                }
            } else if (response?.statusCode == 500) {
                DispatchQueue.main.async {
                    let alert = UIAlertView(title:nil, message: "OOps! Something is wrong on our end. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Trombone")
                    alert.show()
                }
            }
        }
        
        if (method == .delete) {
            // delete does not return JSON https://github.com/KnockSoftware/rideserver/issues/48
            request!.validate().responseString(encoding: String.Encoding.ascii, completionHandler: { (response) in
                let jsonResponse: DataResponse<JSON> = DataResponse(request: response.request, response: response.response, data: response.data, result: Result.success(JSON("")))
                switch response.result {
                case .success(_):
                    completionHandler(jsonResponse)
                case .failure(_):
                    handleHTTPResonseErrors(response.response)
                    completionHandler(jsonResponse)
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            })
        } else {
            request!.validate().responseSwiftyJSON { (response) in
                switch response.result {
                case .success(_):
                    completionHandler(response)
                case .failure(_):
                    handleHTTPResonseErrors(response.response)
                    completionHandler(response)
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            }
        }
    }
    
    @discardableResult func apiResponse(_ completionHandler: @escaping APIResponseBlock)->AuthenticatedAPIRequest {
        if (self.request == nil) {
            completionHandler(AuthenticatedAPIRequest.unauthenticatedResponse())
            return self
        }
        
        self.request!.responseSwiftyJSON { (response) in
            switch response.result {
            case .success(_):
                completionHandler(response)
            case .failure(_):
                completionHandler(response)
            }
        }
        
        return self
    }
}

class APIClient {
    enum AccountVerificationStatus : Int16 { // has the user linked and verified an email to the account?
        case unknown = 0
        case unverified
        case verified
    }

    enum Area {
        case unknown
        case area(name: String, count: UInt, countRatePerHour: UInt, launched: Bool)
        case nonArea
    }
    
    var area : Area = .unknown
    
    // Status
    var accountVerificationStatus = AccountVerificationStatus.unknown {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "APIClientAccountStatusDidChange"), object: nil)
        }
    }
    
    var hasRegisteredForRemoteNotifications: Bool = false
    var notificationDeviceToken: Data?
    
    var isMigrating = false
    fileprivate var sessionManager : SessionManager
    fileprivate var tripRequests : [Trip: AuthenticatedAPIRequest] = [:]
    fileprivate var didEncounterUnrecoverableErrorSyncronizingTrips = false
    fileprivate var isRequestingAuthentication = false
    
    static private(set) var shared : APIClient!
    
    //
    // MARK: - Initializers
    //
    
    class func startup(_ useDefaultConfiguration: Bool = false) {
        if (APIClient.shared == nil) {
            APIClient.shared = APIClient(useDefaultConfiguration: useDefaultConfiguration)
            DispatchQueue.main.async {
                // run startup async
                APIClient.shared.startup()
            }
        }
    }
    
    private func startup() {
        if (CoreDataManager.shared.isStartingUp) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil)
                strongSelf.authenticateIfNeeded().apiResponse() { (_) -> Void in
                    strongSelf.syncStatusAndTripsInForeground()
                }
            }
        } else {
            self.authenticateIfNeeded().apiResponse() { (_) -> Void in
                self.syncStatusAndTripsInForeground()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(self, selector: #selector(APIClient.appDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        })
    }
    
    
    init (useDefaultConfiguration: Bool = false) {
        var configuration = URLSessionConfiguration.background(withIdentifier: "com.Knock.RideReport.background")
        
        if useDefaultConfiguration {
            // used for testing
            configuration = URLSessionConfiguration.default
        }
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 60
    
        let serverTrustPolicies : [String: ServerTrustPolicy] = [
            "api.ride.report": ServerTrustPolicy.pinPublicKeys(publicKeys: ServerTrustPolicy.publicKeys(), validateCertificateChain: true, validateHost: true)
        ]
        self.sessionManager = Alamofire.SessionManager(configuration: configuration, serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    //
    // MARK: - Setup
    //
    
    @objc func appDidBecomeActive() {
        if (CoreDataManager.shared.isStartingUp) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil)
                strongSelf.syncStatusAndTripsInForeground()
            }
        } else {
            self.syncStatusAndTripsInForeground()
        }
    }
    
    func appDidReceiveNotificationDeviceToken(_ token: Data?) {
        let oldToken = self.notificationDeviceToken
        self.hasRegisteredForRemoteNotifications = true
        self.notificationDeviceToken = token
        if (oldToken != token) {
            self.updateAccountStatus()
        }
    }
    
    private func syncStatusAndTripsInForeground() {
        if (self.authenticated) {
            // do account status even in the background
            self.updateAccountStatus()

            if (UIApplication.shared.applicationState == UIApplicationState.active) {
                self.runMigrations()
                
                self.syncUnsyncedTrips()
            }
        }

    }
    
    //
    // MARK: - Migrations
    //
    
    private func runMigrations() {
        let hasRunTripsListOnSummaryAPIAtLeastOnce = UserDefaults.standard.bool(forKey: "hasRunTripRewardToTripRewardsMigration")
        if (!hasRunTripsListOnSummaryAPIAtLeastOnce) {
            self.isMigrating = true

            let _ = AuthenticatedAPIRequest(client: self, method: .get, route: "trips", completionHandler: { (response) -> Void in
                switch response.result {
                case .success(let json):
                        for tripJson in json.array! {
                            // to make this not take forefver, only change the trips with rewards
                            if let uuid = tripJson["uuid"].string, let summary = tripJson["summary"].dictionary, (summary["rewards"] != nil || (summary["rewardEmoji"] != nil && summary["rewardEmoji"]?.string != "")) {
                                if let trip = Trip.tripWithUUID(uuid) {
                                    trip.loadSummaryFromJSON(summary)
                                }
                            }
                        }
                        
                        CoreDataManager.shared.saveContext()
                        
                        UserDefaults.standard.set(true, forKey: "hasRunTripRewardToTripRewardsMigration")
                        UserDefaults.standard.synchronize()
                case .failure(let error):
                    DDLogWarn(String(format: "Error retriving getting trip data: %@", error as CVarArg))
                }
                
                self.isMigrating = false
            })
        }
    }
    
    private func runDataMigration(dataMigrationName name: String, handler: ()->Void) {
        let migrationHasHappened = UserDefaults.standard.bool(forKey: name)
        if (!migrationHasHappened) {
            UserDefaults.standard.set(true, forKey: name)
            UserDefaults.standard.synchronize()
            
            handler()
        }
    }
    
    //
    // MARK: - Trip Synchronization
    //
    
    @discardableResult func getAllTrips()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .get, route: "trips", completionHandler: { (response) -> Void in
            switch response.result {
            case .success(let json):
                for tripJson in json.array! {
                    if let uuid = tripJson["uuid"].string, let creationDateString = tripJson["creationDate"].string, let creationDate = Date.dateFromJSONString(creationDateString) {
                        var trip: Trip! = Trip.tripWithUUID(uuid)
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
                                let ratingChoiceNumber = tripJson["rating"].number,
                                let length = tripJson["length"].number,
                                let activityType = ActivityType(rawValue: activityTypeNumber.int16Value) {
                            let ratingVersionNumber = tripJson["ratingVersion"].number ?? RatingVersion.v1.numberValue // if not given, the server is speaking the old version-less API
                            trip.rating = Rating(rating: ratingChoiceNumber.int16Value, version: ratingVersionNumber.int16Value)
                            trip.activityType = activityType
                            trip.length = length.floatValue
                        }
                        
                        if let summary = tripJson["summary"].dictionary {
                            trip.loadSummaryFromJSON(summary)
                        }
                    }
                }
                CoreDataManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving getting trip data: %@", error as CVarArg))
            }
        })
    }
    
    @discardableResult func getTrip(_ trip: Trip)->AuthenticatedAPIRequest {
        guard let uuid = trip.uuid else {
            // the server doesn't know about this trip yet
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        return AuthenticatedAPIRequest(client: self, method: .get, route: "trips/" + uuid, completionHandler: { (response) -> Void in
            switch response.result {
            case .success(let json):
                if trip.locationsNotYetDownloaded {
                    trip.locations = NSOrderedSet() // just in case
                    if let locations = json["locations"].array {
                        for locationJson in locations {
                            if let dateString = locationJson["date"].string, let date = Date.dateFromJSONString(dateString),
                                    let latitude = locationJson["latitude"].number,
                                    let longitude = locationJson["longitude"].number,
                                    let course = locationJson["course"].number,
                                    let speed = locationJson["speed"].number,
                                    let horizontalAccuracy = locationJson["horizontalAccuracy"].number {
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

                CoreDataManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving getting individual trip data: %@", error as CVarArg))
                
                if let httpResponse = response.response, httpResponse.statusCode == 404 {
                    // unclear what to do in this case (probably we should try to upload the trip again?), but at a minimum we should never try to sync the summary again.
                    trip.summaryIsSynced = true
                    CoreDataManager.shared.saveContext()
                }
            }
        })
    }
    
    @discardableResult func deleteTrip(_ trip: Trip)->AuthenticatedAPIRequest {
        guard let uuid = trip.uuid else {
            // the server doesn't know about this trip yet
            DispatchQueue.main.async(execute: { () -> Void in
                trip.managedObjectContext?.delete(trip)
                CoreDataManager.shared.saveContext()
            })
            
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        return AuthenticatedAPIRequest(client: self, method: .delete, route: "trips/" + uuid, completionHandler: { (response) -> Void in
            switch response.result {
            case .success(_), 
                 .failure(_) where response.response != nil && response.response!.statusCode == 404:
                // it's possible the server already deleted the object, in which case it will send a 404.
                DispatchQueue.main.async {
                    trip.managedObjectContext?.delete(trip)
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alert = UIAlertView(title:nil, message: "There was an error deleting that trip. Please try again later.", delegate: nil, cancelButtonTitle:"Darn")
                    alert.show()
                }
                DDLogWarn(String(format: "Error deleting trip data: %@", error as CVarArg))
            }
        })
        
    }
    
    func syncUnsyncedTrips(_ syncInBackground: Bool = false, completionBlock: @escaping ()->Void = {}) {
        self.didEncounterUnrecoverableErrorSyncronizingTrips = false
        self.syncNextUnsyncedTrip(syncInBackground, completionBlock: completionBlock)
    }
    
    private func syncNextUnsyncedTrip(_ syncInBackground: Bool = false, completionBlock: @escaping ()->Void = {}) {
        if (syncInBackground || UIApplication.shared.applicationState == UIApplicationState.active) {
            if let trip = Trip.nextClosedUnsyncedTrips(), !self.didEncounterUnrecoverableErrorSyncronizingTrips {
                self.syncTrip(trip).apiResponse({ (_) -> Void in
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.6 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                        self.syncNextUnsyncedTrip(syncInBackground, completionBlock: completionBlock)
                    })
                })
            } else if let trip = Trip.nextUnsyncedSummaryTrip() {
                self.getTrip(trip).apiResponse({ (_) in
                    self.syncNextUnsyncedTrip(syncInBackground, completionBlock: completionBlock)
                })
            } else {
                completionBlock()
            }
        }
    }
    
    @discardableResult func saveAndSyncTripIfNeeded(_ trip: Trip, syncInBackground: Bool = false, includeLocations: Bool = true)->AuthenticatedAPIRequest {
        for incident in trip.incidents {
            if ((incident as! Incident).hasChanges) {
                trip.isSynced = false
            }
        }
        trip.saveAndMarkDirty()
        
        if (!trip.isSynced && (syncInBackground || UIApplication.shared.applicationState == UIApplicationState.active)) {
            return self.syncTrip(trip, includeLocations: includeLocations)
        }
        
        return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
    }
    
    @discardableResult func getReward(uuid: String, completionHandler: @escaping AuthenticatedAPIRequest.APIResponseBlock)->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .get, route: "rewards/" + uuid, completionHandler: completionHandler)
    }
    
    @discardableResult func getStatistics()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .get, route: "statistics", completionHandler: { (response) -> Void in
            switch response.result {
            case .success(let json):
                let url = CoreDataManager.shared.applicationDocumentsDirectory.appendingPathComponent("stats.json")
                if let data = try? json.rawData() {
                    try? data.write(to: url)
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving getting individual trip data: %@", error as CVarArg))
            }
        })
    }
    
    func uploadSensorData(_ trip: Trip, withMetadata metadataDict:[String: Any] = [:]) {
        let routeURL = "trips/" + trip.uuid + "/sensor_data"
        
        var sensorDataJsonArray : [[String: Any]] = []
        for sensorDataCollection in trip.sensorDataCollections {
            sensorDataJsonArray.append((sensorDataCollection as! SensorDataCollection).jsonDictionary())
        }
        
        var params = metadataDict
        params["data"] = sensorDataJsonArray
        
        _ = AuthenticatedAPIRequest(client: self, method: .post, route: routeURL, parameters:params , authenticated: true) { (response) in
            switch response.result {
            case .success(_):
                DDLogWarn("Yep")
            case .failure(_):
                DDLogWarn("Nope!")
            }
        }
    }
    
    func uploadSensorDataCollection(_ sensorDataCollection: SensorDataCollection, withMetadata metadataDict:[String: Any] = [:]) {
        let accelerometerRouteURL = "ios_accelerometer_data"
        var params = metadataDict
        params["data"] = sensorDataCollection.jsonDictionary() as Any?

        _ = AuthenticatedAPIRequest(client: self, method: .post, route: accelerometerRouteURL, parameters:params , authenticated: false) { (response) in
            switch response.result {
            case .success(_):
                DDLogWarn("Yep")
            case .failure(_):
                DDLogWarn("Nope!")
            }
        }
    }
    
    @discardableResult func syncTrip(_ trip: Trip, includeLocations: Bool = true)->AuthenticatedAPIRequest {
        guard (trip.isClosed) else {
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
        
        var method = Alamofire.HTTPMethod.put
        var tripDict = [
            "activityType": trip.activityType.numberValue,
            "creationDate": trip.creationDate.JSONString(),
            "rating": trip.rating.choice.numberValue,
            "ratingVersion": trip.rating.version.numberValue
        ] as [String : Any]

        if (!trip.locationsAreSynced && !includeLocations) {
            // initial synchronization of trip data - the server does not know about the locations yet
            // so we provide them in order to get back summary information. record may or may not exist so we PUT.
            guard let startingLocation = trip.bestStartLocation(), let endingLocation = trip.bestEndLocation() else {
                DDLogWarn("No starting and/or ending location found when syncing trip locations!")
                trip.locationsAreSynced = false
                CoreDataManager.shared.saveContext()

                return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
            }
            
            tripDict["length"] = trip.length
            tripDict["startLocation"] = startingLocation.jsonDictionary()
            tripDict["endLocation"] = endingLocation.jsonDictionary()
        } else if (!trip.locationsAreSynced) {
            // upload location data has not been synced, do it now.
            // record may or may not exist, so we PUT
            
            var locations : [Any?] = []
            for location in trip.locations.array {
                locations.append((location as! Location).jsonDictionary())
            }
            tripDict["locations"] = locations
        } else {
            // location data has been synced. Record exists and we are not uploading everything, so we PATCH.
            method = .patch
        }
        
        self.tripRequests[trip] = AuthenticatedAPIRequest(client: self, method: method, route: routeURL, parameters: tripDict as [String : Any]?) { (response) in
            self.tripRequests[trip] = nil
            switch response.result {
            case .success(let json):
                if let summary = json["summary"].dictionary {
                    trip.loadSummaryFromJSON(summary)
                }
                trip.isSynced = true
                if includeLocations {
                    trip.locationsAreSynced = true
                }
                
                if let accountStatus = json["accountStatus"].dictionary, let statusText = accountStatus["status_text"]?.string, let statusEmoji = accountStatus["status_emoji"]?.string {
                    Profile.profile().statusText = statusText
                    Profile.profile().statusEmoji = statusEmoji
                    CoreDataManager.shared.saveContext()
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "APIClientStatusTextDidChange"), object: nil)
                } else {
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error syncing trip: %@", error as CVarArg))

                if let httpResponse = response.response, httpResponse.statusCode == 409 {
                    // a trip with that UUID exists. retry.
                    trip.generateUUID()
                    self.saveAndSyncTripIfNeeded(trip, includeLocations: includeLocations)
                } else if let httpResponse = response.response, httpResponse.statusCode == 404 {
                    // server doesn't know about trip, reset locationsAreSynced
                    trip.locationsAreSynced = false
                    CoreDataManager.shared.saveContext()
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
        return AuthenticatedAPIRequest(client: self, method: .get, route: "applications") { (response) -> Void in
            switch response.result {
            case .success(let json):
                if let apps = json.array {
                    var appsToDelete = ConnectedApp.allApps()
                    
                    for appDict in apps {
                        if let app = ConnectedApp.createOrUpdate(withJson: appDict), let index = appsToDelete.index(of: app) {
                            appsToDelete.remove(at: index)
                        }
                    }
                    
                    for app in appsToDelete {
                        // delete any app objects we did not receive
                        if !app.isHiddenApp {
                            CoreDataManager.shared.currentManagedObjectContext().delete(app)
                        }
                    }
                    
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error as CVarArg))
            }
        }
    }
    
    @discardableResult func getApplication(_ app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .get, route: "applications/" + app.uuid) { (response) -> Void in
            switch response.result {
            case .success(let json):
                app.updateWithJson(withJson: json)
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party app: %@", error as CVarArg))
            }
        }
    }
    
    func connectApplication(_ app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .post, route: "applications/" + app.uuid + "/connect", parameters: app.json().dictionaryObject as [String : Any]?) { (response) -> Void in
            switch response.result {
            case .success(let json):
                if let httpsResponse = response.response, httpsResponse.statusCode == 200 {
                    _ = ConnectedApp.createOrUpdate(withJson: json)
                    app.profile = Profile.profile()
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error as CVarArg))
            }
        }
    }
    
    func disconnectApplication(_ app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .post, route: "applications/" + app.uuid + "/disconnect") { (response) -> Void in
            switch response.result {
            case .success(_):
                app.profile = nil
                CoreDataManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error as CVarArg))
            }
        }
    }

    
    //
    // MARK: - Authenciatation API Methods
    //
    
    func profileDictionary() -> [String: Any] {
        var profileDictionary = [String: Any]()
        
        // iOS Data
        var iosDictionary = [String: Any]()
        if let preferredLanguage = (Locale.current as NSLocale).object(forKey: NSLocale.Key.languageCode) as? String {
            iosDictionary["preferred_language"] = preferredLanguage
        }
        
        if let model = UIDevice.current.deviceModel() {
            iosDictionary["device_model"] = model
        }
        
        if !iosDictionary.isEmpty {
            profileDictionary["ios"] = iosDictionary
        }
        
        // Health Kit Data
        var healthKitDictionary = [String: Any]()
        if let dob = Profile.profile().dateOfBirth {
            healthKitDictionary["date_of_birth"] = dob.JSONString()
        }
        
        if let weight = Profile.profile().weightKilograms, weight.int32Value > 0 {
            healthKitDictionary["weight_kilograms"] = weight
        }
        
        let gender = Profile.profile().gender
        if  gender.intValue != HKBiologicalSex.notSet.rawValue {
            healthKitDictionary["gender"] = gender
        }
        
        if !healthKitDictionary.isEmpty {
            profileDictionary["healthkit"] = healthKitDictionary
        }

        return profileDictionary
    }
    
    @discardableResult func updateAccountStatus()-> AuthenticatedAPIRequest {
        guard self.hasRegisteredForRemoteNotifications else {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        var parameters: [String: Any] = [:]
        if let deviceToken = self.notificationDeviceToken {
            parameters["device_token"] = deviceToken.hexadecimalString()
            #if DEBUG
                parameters["is_development_client"] = true
            #endif
        }
        
        parameters["profile"] = self.profileDictionary()
        
        
        if (RouteManager.hasStarted) {
            if let loc = RouteManager.shared.location {
                parameters["lnglat"] = String(loc.coordinate.longitude) + "," + String(loc.coordinate.latitude)
            }
        }
            
        return AuthenticatedAPIRequest(client: self, method:.post, route: "status", parameters: parameters) { (response) -> Void in
            switch response.result {
            case .success(let json):
                if let areaJson = json["area"].dictionary {
                    if let name = areaJson["name"]?.string, let count = areaJson["count_info"]?["count"].uInt, let countRatePerHour = areaJson["count_info"]?["per_hour"].uInt, let launched = areaJson["launched"]?.bool {
                        self.area = .area(name: name, count: count, countRatePerHour: countRatePerHour, launched: launched)
                    } else {
                        self.area = .nonArea
                    }
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "APIClientAccountStatusDidGetArea"), object: nil)
                } else {
                    self.area = .unknown
                }
                
                if let featureFlags = json["feature_flags"].array?.map({$0.string}) as? [String] {
                    Profile.profile().featureFlags = featureFlags
                } else {
                    Profile.profile().featureFlags = []
                }
                
                if let statusText = json["status_text"].string, let statusEmoji = json["status_emoji"].string {
                    Profile.profile().statusText = statusText
                    Profile.profile().statusEmoji = statusEmoji
                }
                
                if let supportId = json["support_id"].string {
                    Profile.profile().supportId = supportId
                }
                
                if let promotions = json["promotions"].array {
                    var newPromotions: [Promotion] = []
                    
                    for promotionsDict in promotions {
                        if let promo = Promotion.createOrUpdate(withJson: promotionsDict) {
                            newPromotions.append(promo)
                            promo.profile = Profile.profile()
                        }
                    }
                    
                    for promo in Profile.profile().promotions {
                        let promotion = promo as! Promotion
                        if !newPromotions.contains(promotion) {
                            promotion.profile = nil
                        }
                    }
                }
                
                if let connectedApps = json["connected_apps"].array {
                    var appsToDelete = ConnectedApp.allApps()
                    
                    for appDict in connectedApps {
                        if let app = ConnectedApp.createOrUpdate(withJson: appDict) {
                            if let index = appsToDelete.index(of: app) {
                                appsToDelete.remove(at: index)
                            }
                            app.profile = Profile.profile()
                        }
                    }
                    
                    for app in appsToDelete {
                        // delete any app objects we did not receive
                        app.profile = nil
                    }
                }
                
                CoreDataManager.shared.saveContext()
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "APIClientStatusTextDidChange"), object: nil)
                
                if let mixPanelID = json["mixpanel_id"].string {
                    Mixpanel.sharedInstance().identify(mixPanelID)
                }
                
                if let account_verified = json["account_verified"].bool {
                    if (account_verified) {
                        if (self.accountVerificationStatus == .unverified) {
                            // if we are just moved to an authenticated account, get any trips on the server
                            self.getAllTrips()
                        }
                        self.accountVerificationStatus = .verified
                    } else {
                        self.accountVerificationStatus = .unverified
                    }
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving account status: %@", error as CVarArg))
            }
        }
    }
    
    func logout()-> AuthenticatedAPIRequest {
        Profile.resetProfile()
        
        return AuthenticatedAPIRequest(client: self, method: .post, route: "logout") { (response) in
            switch response.result {
            case .success(_):
                self.reauthenticate()
                DDLogInfo("Logged out!")
            case .failure(let error):
                DDLogWarn(String(format: "Error logging out: %@", error as CVarArg))
                self.authenticateIfNeeded()
            }
        }
    }
    
    func sendVerificationTokenForEmail(_ email: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .post, route: "send_email_code", parameters: ["email": email]) { (response) in
            switch response.result {
            case .success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .failure(let error):
                DDLogWarn(String(format: "Error sending verification email: %@", error as CVarArg))
                
                if let httpResponse = response.response, httpResponse.statusCode == 400 {
                    DispatchQueue.main.async {
                        let alert = UIAlertView(title:nil, message: "That doesn't look like a valid email address. Please double-check your typing and try again.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    }
                }
            }
        }
    }
    
    func verifyToken(_ token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .post, route: "verify_email_code", parameters: ["code": token]) { (response) in
            switch response.result {
            case .success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .failure(let error):
                DDLogWarn(String(format: "Error verifying email token: %@", error as CVarArg))
            }
        }
    }
    
    func verifyFacebook(_ token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .post, route: "verify_facebook_login", parameters: ["token": token]) { (response) in
            switch response.result {
            case .success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .failure(let error):
                DDLogWarn(String(format: "Error verifying facebook token: %@", error as CVarArg))
                if let httpResponse = response.response, httpResponse.statusCode == 400 {
                    DispatchQueue.main.async {
                        let alert = UIAlertView(title:nil, message: "There was an error communicating with Facebook. Please try again later or use sign up using your email address instead.", delegate: nil, cancelButtonTitle:"On it")
                        alert.show()
                    }
                }
            }
        }
    }
    
    @discardableResult func testAuthID()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .get, route: "oauth_info") { (response) in
            switch response.result {
            case .success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving access token: %@", error as CVarArg))
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
        CoreDataManager.shared.saveContext()
        
        self.authenticateIfNeeded()
    }
    
    @discardableResult func authenticateIfNeeded()->AuthenticatedAPIRequest {
        if (self.authenticated || self.isRequestingAuthentication) {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        self.isRequestingAuthentication = true
        
        let parameters = ["client_id" : "1ARN1fJfH328K8XNWA48z6z5Ag09lWtSSVRHM9jw", "response_type" : "token"]
        
        return AuthenticatedAPIRequest(client: self, method: .get, route: "oauth_token", parameters: parameters as [String : Any]?, encoding: URLEncoding.default, authenticated: false) { (response) in
            self.isRequestingAuthentication = false
            
            switch response.result {
            case .success(let json):
                if let accessToken = json["access_token"].string, let expiresInString = json["expires_in"].string, let expiresInInt = Int(expiresInString) {
                    let expiresIn = Date().secondsFrom(expiresInInt)
                    if (Profile.profile().accessToken == nil) {
                        Profile.profile().accessToken = accessToken
                        Profile.profile().accessTokenExpiresIn = expiresIn
                        CoreDataManager.shared.saveContext()
                        self.updateAccountStatus()
                    } else {
                        DDLogWarn("Got a new access token when one was already set!")
                    }
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving access token: %@", error as CVarArg))
                let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to bugs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                alert.show()
            }
        }
    }
}
