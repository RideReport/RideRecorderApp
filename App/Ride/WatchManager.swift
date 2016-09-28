//
//  WatchManager.swift
//  Ride
//
//  Created by William Henderson on 8/1/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import HealthKit
import WatchConnectivity


@available(iOS 10.0, *)
class WatchManager : NSObject, WCSessionDelegate {
    let healthStore = HKHealthStore()

    var configuration : HKWorkoutConfiguration?
    var wcSessionActivationCompletion : ((WCSession)->Void)?
    
    static let sampleWindowSize: Int = 64
    static let updateInterval: NSTimeInterval = 50/1000
    
    private var isGatheringMotionData: Bool = false
    private var isQueryingMotionData: Bool = false
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedManager : WatchManager?
    }
    
    
    class var sharedManager:WatchManager {
        return Static.sharedManager!
    }
    
    class func startup() {
        if (Static.sharedManager == nil) {
            Static.sharedManager = WatchManager()
            dispatch_async(dispatch_get_main_queue()) {
                // start async
                Static.sharedManager?.startup()
            }
        }
    }
    
    override init () {
        super.init()
        
    }
    
    var paired: Bool {
        get {
            return WCSession.defaultSession().paired
        }
    }
    
    private func startup() {
        guard WCSession.isSupported() else { return }
        
        let wcSession = WCSession.defaultSession()
        wcSession.delegate = self
        
        if wcSession.activationState != .Activated {
            wcSession.activateSession()
        }
    }
    
    // MARK: WCSessionDelegate
    
    func session(session: WCSession, activationDidCompleteWithState activationState: WCSessionActivationState, error: NSError?) {
        //
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        //
    }
    
    func sessionDidBecomeInactive(session: WCSession) {
        //
    }
    
    func sessionDidDeactivate(session: WCSession) {
        //
    }
}

