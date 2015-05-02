//
//  NetworkManager.swift
//  Ride
//
//  Created by William Henderson on 12/11/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Alamofire

#if (arch(i386) || arch(x86_64)) && os(iOS)
let serverAddress = "http://127.0.0.1:8080/"
#else
let serverAddress = "http://ride.report/"
#endif
    
class NetworkManager {
    private var jsonDateFormatter = NSDateFormatter()
    private var manager : Manager
        
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedManager : NetworkManager?
    }
    
    class var sharedManager:NetworkManager {
        dispatch_once(&Static.onceToken) {
            Static.sharedManager = NetworkManager()
        }
        
        return Static.sharedManager!
    }
    
    func startup() {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            for aTrip in Trip.openTrips()! {
                let trip = aTrip as! Trip
                
                if (trip.locations.count <= 6) {
                    // if it doesn't more than 6 points, toss it.
                    CoreDataManager.sharedCoreDataManager.currentManagedObjectContext().deleteObject(trip)
                    self.saveAndSyncTripIfNeeded(trip)
                } else {
                    trip.close() {
                        self.saveAndSyncTripIfNeeded(trip)
                    }
                }
            }
            
        })

    }
    
    func jsonify(date: NSDate) -> String {
        return self.jsonDateFormatter.stringFromDate(date)
    }
    
    init () {
        self.jsonDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.Knock.Ride.background")
        configuration.timeoutIntervalForRequest = 60
        self.manager = Alamofire.Manager(configuration: configuration)
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
        
        CoreDataManager.sharedCoreDataManager.saveContext()
        
        if (UIApplication.sharedApplication().applicationState == UIApplicationState.Active) {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.syncTrip(trip)
                })
        } else if (syncInBackground) {
            // run background task synchronously to avoid being suspended first
            self.syncTrip(trip)
        }
    }
    
    private func syncTrip(trip: Trip) {
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
            if !aLocation.isPrivate.boolValue {
                locations.append([
                    "course": aLocation.course!,
                    "date": self.jsonify(aLocation.date!),
                    "horizontalAccuracy": aLocation.horizontalAccuracy!,
                    "speed": aLocation.speed!,
                    "longitude": aLocation.longitude!,
                    "latitude": aLocation.latitude!
                    ])
            }
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
                DDLogWrapper.logError(String(format: "Response: %@", response!))
                CoreDataManager.sharedCoreDataManager.saveContext()
            } else {
                DDLogWrapper.logError(String(format: "Error: %@", error!))
            }
        }
    }
    
    func postRequest(route: String, parameters: [String: AnyObject!]) -> Request {
        return manager.request(.POST, serverAddress + route, parameters: parameters, encoding: .JSON)
    }
    
}
