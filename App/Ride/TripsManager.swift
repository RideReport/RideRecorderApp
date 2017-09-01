//
//  TripsManager.swift
//  Ride
//
//  Created by William Henderson on 8/31/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder

class TripsManager : NSObject {
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

    private func startup() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RouteRecorderDidCloseRoute"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                guard let route = notification.object as? Route else {
                    return
                }
                
                let trip = Trip(route: route)
                trip.sendTripCompletionNotificationLocally(secondsFromNow:15.0)
            })
        }
    }
}
