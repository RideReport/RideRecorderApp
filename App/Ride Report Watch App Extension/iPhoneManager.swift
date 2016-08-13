//
//  iPhoneManager.swift
//  Ride
//
//  Created by William Henderson on 8/1/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import WatchConnectivity

protocol iPhoneStateChangedDelegate {
    func stateDidChange()
}

class iPhoneManager : NSObject, WCSessionDelegate {
    enum TripState : Int16 {
        case Unknown = 0
        case InProgress
        case Stopped
    }
    var tripState: TripState = .Unknown
    var tripDistance: Meters = 0
    
    private var iPhoneStateChangedDelegates = [iPhoneStateChangedDelegate]()
    private var wcSession: WCSession?
    private var messagesToSend = [[String: String]]()
    
    struct Static {
        static var sharedManager : iPhoneManager?
    }
    
    
    class var sharedManager:iPhoneManager {
        return Static.sharedManager!
    }
    
    func addDelegate<T where T: iPhoneStateChangedDelegate>(delegate: T) {
        iPhoneStateChangedDelegates.append(delegate)
    }
    
    func removeDelegate<T where T: iPhoneStateChangedDelegate, T: Equatable>(delegateToRemove: T) {
        for (index, delegate) in iPhoneStateChangedDelegates.enumerate() {
            if let aDelegate = delegate as? T where aDelegate == delegateToRemove {
                iPhoneStateChangedDelegates.removeAtIndex(index)
                break
            }
        }
    }
    
    class func startup() {
        if (Static.sharedManager == nil) {
            Static.sharedManager = iPhoneManager()
            Static.sharedManager?.startup()
        }
    }
    
    override init () {
        super.init()
        
    }
    
    private func startup() {
        // send connected message?
    }
    
    func activate() {
        WCSession.defaultSession().delegate = self
        WCSession.defaultSession().activateSession()
    }
    
    
    // MARK: Utility methods
    
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        if let state = applicationContext["tripState"] as? String {
            if state == "ended" {
                tripState = .Stopped
            }
        } else if let distance = applicationContext["tripDistance"] as? Float {
            tripDistance = distance
            tripState = .InProgress
        }
        
        iPhoneStateChangedDelegates.forEach { $0.stateDidChange()}
    }
    
    func send(command: String) {
        let message = ["command": command]
        if let session = wcSession {
            if session.reachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: nil)
            }
        } else {
            activate()
            messagesToSend.append(message)
        }
    }
    
    func session(session: WCSession, activationDidCompleteWithState activationState: WCSessionActivationState, error: NSError?) {
        if activationState == .Activated {
            wcSession = session
            sendPending()
        }
    }
    
    private func sendPending() {
        if let session = wcSession {
            if session.reachable {
                for message in messagesToSend {
                    session.sendMessage(message, replyHandler: nil, errorHandler: nil)
                }
                messagesToSend.removeAll()
            }
        }
    }
}
