//
//  NetworkMachine.swift
//  Ride
//
//  Created by William Henderson on 12/11/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Alamofire

//let serverAddress = "http://10.0.1.78:8080/"
let serverAddress = "http://54.148.164.222/"

class NetworkMachine {
    private var jsonDateFormatter = NSDateFormatter()
    private var manager : Manager
        
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedMachine : NetworkMachine?
    }
    
    class var sharedMachine:NetworkMachine {
        dispatch_once(&Static.onceToken) {
            Static.sharedMachine = NetworkMachine()
        }
        
        return Static.sharedMachine!
    }
    
    func startup() {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            for aTrip in Trip.openTrips()! {
                let trip = aTrip as Trip
                
                if (trip.locations.count <= 6) {
                    // if it doesn't more than 6 points, toss it.
                    CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(trip)
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
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 60
        self.manager = Alamofire.Manager(configuration: config)
    }
    
    func syncTrips() {
        for trip in Trip.allTrips()! {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.syncTrip(trip as Trip)
            })
        }
    }
    
    
    func saveAndSyncTripIfNeeded(trip: Trip, syncInBackground: Bool = false) {
        if (trip.isSynced.boolValue) {
            trip.isSynced = false
        }
        
        CoreDataController.sharedCoreDataController.saveContext()
        
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
            "rating": trip.rating
        ]
        var locations : [AnyObject!] = []
        for location in trip.locations.array {
            let aLocation = location as Location
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
        self.postRequest("trips/save", parameters: tripDict).response { (request, response, data, error) in
            if (error == nil) {
                trip.isSynced = true
                DDLogWrapper.logError(NSString(format: "Response: %@", response!))
                CoreDataController.sharedCoreDataController.saveContext()
            } else {
                DDLogWrapper.logError(NSString(format: "Error: %@", error!))
            }
        }
    }
    
    func postRequest(route: String, parameters: [String: AnyObject!]) -> Request {
        return manager.request(.POST, serverAddress + route, parameters: parameters, encoding: .JSON)
    }
    
}
