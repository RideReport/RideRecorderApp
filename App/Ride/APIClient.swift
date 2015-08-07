//
//  APIClient.swift
//  Ride
//
//  Created by William Henderson on 12/11/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Alamofire
import OAuthSwift
import Locksmith

#if (arch(i386) || arch(x86_64)) && os(iOS)
let serverAddress = "http://127.0.0.1:8080/api/"
#else
let serverAddress = "http://ride.report/api/"
#endif
    
class APIClient {
    private var jsonDateFormatter = NSDateFormatter()
    private var manager : Manager
    
    
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
            "ownerId": Profile.profile().uuid
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
        
        var incidents : [AnyObject!] = []
        for incident in trip.incidents.array {
            let anIncident = incident as! Incident
            var incDict = [
                "creationDate": self.jsonify(anIncident.creationDate!),
                "incidentType": anIncident.type,
                "uuid": anIncident.uuid,
                "longitude": anIncident.location.longitude!,
                "latitude": anIncident.location.latitude!
            ]
            if (anIncident.body != nil) {
                incDict["incidentBody"] = anIncident.body!
            }
            incidents.append(incDict)
        }
        tripDict["incidents"] = incidents
        self.postRequest("trips/save", parameters: tripDict).response { (request, response, data, error) in
            if (error == nil) {
                trip.isSynced = true
                DDLogError(String(format: "Response: %@", response!))
                CoreDataManager.sharedManager.saveContext()
            } else {
                DDLogError(String(format: "Error: %@", error!))
            }
        }
    }
    
    //
    // MARK: - Helpers
    //
    
    private func jsonify(date: NSDate) -> String {
        return self.jsonDateFormatter.stringFromDate(date)
    }
    
    
    private func postRequest(route: String, parameters: [String: AnyObject!]) -> Request {
        return manager.request(.POST, serverAddress + route, parameters: parameters, encoding: .JSON)
    }
    
    //
    // MARK: - OAuth
    //
    
    var authenticated: Bool {
        return (self.accessToken != nil)
    }
    
    func authenticate(uuid: String? = nil) {
        var parameters = ["client_id" : "someclientid", "response_type" : "token"]
        if (uuid != nil) {
            parameters["uuid"] = uuid
        }
    
        manager.request(.POST, serverAddress + "/oauth_token", parameters: parameters, encoding: .JSON).response { (request, response, data, error)in
            if (error == nil) {
                // do stuff with the response
            } else {
                DDLogError(String(format: "Error retriving authentication token: %@", error!))
            }
        }
    }
    
    private func saveAccessToken(token: String) {
        let saveTokenRequest = LocksmithRequest(userAccount: "mainUser", requestType: RequestType.Create, data: ["token" : token])
        saveTokenRequest.synchronizable = true
        Locksmith.performRequest(saveTokenRequest)
    }
    
    private var accessToken: String? {
        let (dictionary, error) = Locksmith.loadDataForUserAccount("mainUser")
        if (error != nil || dictionary == nil) {
            return nil
        }
        
        return dictionary?["token"] as? String
    }
    
    private func setupAuthenciatedSessionConfiguration() {
        let (dictionary, error) = Locksmith.loadDataForUserAccount("mainUser")
        
        var headers = self.manager.session.configuration.HTTPAdditionalHeaders ?? [:]
        // set the authentication headers
        let token = "foo"
        headers["Authorization"] =  "token \(token)"
        
        self.manager.session.configuration.HTTPAdditionalHeaders = headers
    }
}
