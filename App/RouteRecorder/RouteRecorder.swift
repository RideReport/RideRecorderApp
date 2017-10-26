//
//  RouteRecorder.swift
//  Ride
//
//  Created by William Henderson on 5/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreMotion
import CoreData
import CocoaLumberjack

public protocol RouteRecorderDelegate: class {
    func didOpenRoute(route: Route)
    func didCloseRoute(route: Route)
    func didCancelRoute(withUUID uuid: String)
    func didUpdateInProgressRoute(route: Route)
}

public class RouteRecorder {
    weak open var delegate: RouteRecorderDelegate?

    public static private(set) var shared: RouteRecorder!
    
    public private(set) var locationManager: LocationManager!
    public private(set) var routeManager: RouteManager!
    public private(set) var classificationManager: ClassificationManager!
    public private(set) var randomForestManager: RandomForestManager!
    public private(set) var motionManager: CMMotionManager!
    
    fileprivate var didEncounterUnrecoverableErrorUploadingRoutes = false
    
    public class var isInjected: Bool {
        get {
            return shared != nil
        }
    }
    
    public class func inject(motionManager: CMMotionManager, locationManager: LocationManager, routeManager: RouteManager, randomForestManager: RandomForestManager, classificationManager: ClassificationManager) {
        shared = RouteRecorder(motionManager: motionManager, locationManager: locationManager, routeManager: routeManager, randomForestManager: randomForestManager, classificationManager: classificationManager)
    }
    
    private init(motionManager: CMMotionManager, locationManager: LocationManager, routeManager: RouteManager, randomForestManager: RandomForestManager, classificationManager: ClassificationManager) {
        self.motionManager = motionManager
        self.locationManager = locationManager
        
        self.randomForestManager = randomForestManager
        
        self.classificationManager = classificationManager
        self.classificationManager.routeRecorder = self
        self.routeManager = routeManager
        self.routeManager.routeRecorder = self
        
        startup()
    }
    
    public func logout() {
        RouteRecorder.shared.routeManager.abortRoute()
        RouteRecorderDatabaseManager.shared.resetDatabase()
        APIClient.shared.logout()
    }
    
    private func startup() {
        RouteRecorderDatabaseManager.startup()
        KeychainManager.startup()
        APIClient.startup()
                
        if (UIApplication.shared.applicationState == UIApplicationState.active) {
            self.syncUnsyncedRoutes()
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
                strongSelf.deleteUploadedRoutes()
            }
        } else {
            self.syncUnsyncedRoutes()
            self.deleteUploadedRoutes()
        }
    }
    
    private func deleteUploadedRoutes() {
        // Deletes routes with isUploaded=true or routes with isSummaryUploaded=true that are at least a week old
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Route")
        let uploadedRoutesPredicate = NSPredicate(format: "isSummaryUploaded == YES AND creationDate < %@", Date().daysFrom(-7) as CVarArg)
        fetchedRequest.predicate = uploadedRoutesPredicate
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let routes = results as? [Route], routes.count > 0 else {
            return
        }
        
        for route in routes {
            RouteRecorderDatabaseManager.shared.currentManagedObjectContext().delete(route)
        }
        RouteRecorderDatabaseManager.shared.saveContext()
    }
    
    private func syncUnsyncedRoutes() {
        if (UIApplication.shared.applicationState == UIApplicationState.active) {
            self.uploadRoutes(includeFullLocations: UIDevice.current.batteryState == UIDeviceBatteryState.charging || UIDevice.current.batteryState == UIDeviceBatteryState.full)
        }
    }
    
    public func uploadRoutes(includeFullLocations: Bool = false, completionBlock: @escaping ()->Void = {}) {
        self.didEncounterUnrecoverableErrorUploadingRoutes = false
        self.uploadNextRoute(includeFullLocations: includeFullLocations, completionBlock: completionBlock)
    }
    
    private func uploadNextRoute(includeFullLocations: Bool, completionBlock: @escaping ()->Void = {}) {
        if let route = (includeFullLocations ? Route.nextClosedUnuploadedRoute() : Route.nextUnuploadedSummaryRoute()), !self.didEncounterUnrecoverableErrorUploadingRoutes {
            APIClient.shared.uploadRoute(route, includeFullLocations: includeFullLocations).apiResponse({ (response) -> Void in
                switch response.result {
                case .success(_): break
                
                case .failure(let error):
                    DDLogWarn(String(format: "Error syncing route: %@", error as CVarArg))
                    
                    if let httpResponse = response.response, httpResponse.statusCode != 409 {
                        self.didEncounterUnrecoverableErrorUploadingRoutes = true
                        return
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.6 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                    self.uploadNextRoute(includeFullLocations: includeFullLocations, completionBlock: completionBlock)
                })
            })
        } else {
            completionBlock()
        }
    }
    

}
