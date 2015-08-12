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
let serverAddress = "http://192.168.1.32:8000/api/v2/"
#else
let serverAddress = "http://api.ride.report/api/v2/"
#endif
    
class APIClient {
    private var jsonDateFormatter = NSDateFormatter()
    private var manager : Manager
    private var rideKeychainUserName = "Ride Report Access Token"
    
    
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
        Static.sharedClient = APIClient()
        Static.sharedClient?.startup()
    }
    
    func startup() {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            if (!self.authenticated) {
                self.authenticate(successHandler: {
                    self.syncTrips(syncInBackground: false)
                })
            } else {
                self.syncOpenTrips()
            }
            
        })
        
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

        self.manager = Alamofire.Manager(configuration: configuration)
    }
    
    //
    // MARK: - Trip Synchronization
    //
    
    func syncOpenTrips(){
        for aTrip in Trip.openTrips()! {
            let trip = aTrip as! Trip
            
            if (trip.locations.count <= 6) {
                // if it doesn't more than 6 points, toss it.
                CoreDataManager.sharedManager.currentManagedObjectContext().deleteObject(trip)
                self.saveAndSyncTripIfNeeded(trip)
            } else {
                trip.close() {
                    self.saveAndSyncTripIfNeeded(trip)
                }
            }
        }
    }
    
    func syncTrips(syncInBackground: Bool = false) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            for trip in Trip.allTrips() {
                    self.saveAndSyncTripIfNeeded(trip as! Trip, syncInBackground: syncInBackground)
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
    
    private func syncTrip(trip: Trip) {
        if (!self.authenticated) {
            return
        }
        
        if (trip.isSynced.boolValue || !trip.isClosed.boolValue) {
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
                        let alert = UIAlertView(title:nil, message: "There was an authenication error talking to the server. Please report this issue to logs@ride.report!", delegate: nil, cancelButtonTitle:"Sad Panda")
                        alert.show()
                    }
                    self.reauthenticate()
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
            self.authenticate()
        }
    }
    
    func authenticate(successHandler: ()->Void = {}) {
        let uuid = Profile.profile().uuid
        var parameters = ["client_id" : "1ARN1fJfH328K8XNWA48z6z5Ag09lWtSSVRHM9jw", "response_type" : "token"]
        parameters["uuid"] = uuid
        self.makeAuthenticatedRequest(Alamofire.Method.GET, route: "oauth_token", parameters: parameters, encoding: .URL).validate().responseJSON(options: nil) { (request, response, jsonData, error) -> Void in
            if (error == nil) {
                // do stuff with the response
                let data = JSON(jsonData!)
                if let accessToken = data["access_token"].string, expiresIn = data["expires_in"].string {
                    if(self.saveAccessToken(accessToken, expiresIn: expiresIn)) {
                        successHandler()
                    }
                }
            } else {
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

            if (error != nil || dictionary == nil) {
                DDLogError(String(format: "Error accessing access token: %@", error!))
                if (error!.code == Int(errSecInteractionNotAllowed)) {
                    // this is a special case. if we get this error, it's because the device isn't unlocked yet.
                    // we'll want to try again later.
                    _hasLookedForAccessToken = false
                }
            } else {
                _accessToken = dictionary?["accessToken"] as? String
            }
        }
        
        return _accessToken
    }
}
