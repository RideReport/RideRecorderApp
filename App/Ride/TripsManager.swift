//
//  TripsManager.swift
//  Ride
//
//  Created by William Henderson on 8/31/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder

class TripsManager : NSObject, RouteRecorderDelegate {
    static private(set) var shared : TripsManager!
    
    struct Static {
        static var onceToken : Int = 0
        static var sharedManager : TripsManager?
    }
    
    class func startup() {
        if (TripsManager.shared == nil) {
            TripsManager.shared = TripsManager()
            TripsManager.shared.startup()
        }
    }
    
    override init () {
        super.init()
    }
    
    func didOpenRoute(route: Route) {
        
    }
    
    func didCloseRoute(route: Route) {
        let trip = Trip.findOrCreateTrip(withRoute: route)
        CoreDataManager.shared.saveContext()
        
        trip.sendTripCompletionNotificationLocally(secondsFromNow:15.0)
    }
    
    func didCancelRoute(route: Route) {
        
    }

    private func startup() {
        RouteRecorder.shared.delegate = self
    }
}
