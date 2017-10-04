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
    static private(set) var shared : WatchManager!
    
    let healthStore = HKHealthStore()

    var configuration : HKWorkoutConfiguration?
    var wcSessionActivationCompletion : ((WCSession)->Void)?
    
    static let sampleWindowSize: Int = 64
    static let updateInterval: TimeInterval = 50/1000
    
    private var isGatheringMotionData: Bool = false
    private var isQueryingMotionData: Bool = false
    
    struct Static {
        static var onceToken : Int = 0
        static var sharedManager : WatchManager?
    }
    
     class func startup() {
        if (WatchManager.shared == nil) {
            WatchManager.shared = WatchManager()
            DispatchQueue.main.async {
                // start async
                WatchManager.shared.startup()
            }
        }
    }
    
    override init () {
        super.init()
        
    }
    
    var paired: Bool {
        get {
            return WCSession.default.isPaired
        }
    }
    
    private func startup() {
        guard WCSession.isSupported() else { return }
        
        let wcSession = WCSession.default
        wcSession.delegate = self
        
        if wcSession.activationState != .activated {
            wcSession.activate()
        }
    }
    
    // MARK: WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        //
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        //
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        //
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        //
    }
}

