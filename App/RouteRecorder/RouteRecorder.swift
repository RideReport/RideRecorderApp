//
//  RouteRecorder.swift
//  Ride
//
//  Created by William Henderson on 5/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreMotion

public protocol RouteRecorderDelegate: class {
    func didOpenRoute(route: Route)
    func didCloseRoute(route: Route)
    func didCancelRoute(route: Route)
}

public class RouteRecorder {
    weak open var delegate: RouteRecorderDelegate?

    public static private(set) var shared: RouteRecorder!
    
    public private(set) var locationManager: LocationManager!
    public private(set) var routeManager: RouteManager!
    public private(set) var classificationManager: ClassificationManager!
    public private(set) var randomForestManager: RandomForestManager!
    public private(set) var motionManager: CMMotionManager!
    public private(set) var motionActivityManager: CMMotionActivityManager!
    
    fileprivate var didEncounterUnrecoverableErrorUploadingRoutes = false
    
    public class var isInjected: Bool {
        get {
            return shared != nil
        }
    }
    
    public class func inject(motionManager: CMMotionManager, motionActivityManager: CMMotionActivityManager, locationManager: LocationManager, routeManager: RouteManager, randomForestManager: RandomForestManager, classificationManager: ClassificationManager) {
        shared = RouteRecorder(motionManager: motionManager, motionActivityManager: motionActivityManager, locationManager: locationManager, routeManager: routeManager, randomForestManager: randomForestManager, classificationManager: classificationManager)
    }
    
    private init(motionManager: CMMotionManager, motionActivityManager: CMMotionActivityManager, locationManager: LocationManager, routeManager: RouteManager, randomForestManager: RandomForestManager, classificationManager: ClassificationManager) {
        self.motionManager = motionManager
        self.motionActivityManager = motionActivityManager
        self.locationManager = locationManager
        
        self.randomForestManager = randomForestManager
        
        self.classificationManager = classificationManager
        self.classificationManager.routeRecorder = self
        self.routeManager = routeManager
        self.routeManager.routeRecorder = self
        
        startup()
    }
    
    private func startup() {
        RouteRecorderDatabaseManager.startup()
        KeychainManager.startup()
        APIClient.startup()
        
        if (UIApplication.shared.applicationState == UIApplicationState.active) {
            self.uploadRoutes()
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(self, selector: #selector(RouteRecorder.appDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        })
    }
    
    @objc func appDidBecomeActive() {
        if (RouteRecorderDatabaseManager.shared.isStartingUp) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RouteRecorderDatabaseManagerDidStartup"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
                guard let strongSelf = self else {
                    return
                }
                NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "RouteRecorderDatabaseManagerDidStartup"), object: nil)
                strongSelf.syncUnsyncedRoutes()
            }
        } else {
            self.uploadRoutes()
        }
    }
    
    private func syncUnsyncedRoutes() {
        if (UIApplication.shared.applicationState == UIApplicationState.active) {
            self.uploadRoutes()
        }
    }
    
    public func uploadRoutes(_ syncInBackground: Bool = false, completionBlock: @escaping ()->Void = {}) {
        self.didEncounterUnrecoverableErrorUploadingRoutes = false
        self.uploadNextRoute(syncInBackground, completionBlock: completionBlock)
    }
    
    private func uploadNextRoute(_ includeFullLocations: Bool, completionBlock: @escaping ()->Void = {}) {
        if let route = Route.nextClosedUnuploadedRoute(), !self.didEncounterUnrecoverableErrorUploadingRoutes {
            APIClient.shared.uploadRoute(route, includeFullLocations: includeFullLocations).apiResponse({ (response) -> Void in
                switch response.result {
                case .success(let _): break
                    
                case .failure(let error):
                    DDLogWarn(String(format: "Error syncing route: %@", error as CVarArg))
                    
                    if let httpResponse = response.response, httpResponse.statusCode != 409 {
                        self.didEncounterUnrecoverableErrorUploadingRoutes = true
                        return
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.6 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                    self.uploadNextRoute(includeFullLocations, completionBlock: completionBlock)
                })
            })
        } else {
            completionBlock()
        }
    }
    

}
