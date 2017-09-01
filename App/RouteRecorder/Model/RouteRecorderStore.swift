//
//  RouteRecorderStore
//  Ride
//
//  Created by William Henderson on 8/31/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

public class RouteRecorderStore: NSManagedObject {
    struct Static {
        static var onceToken : Int = 0
        static var store : RouteRecorderStore!
    }
    
    class func resetRouteRecorderStore() {
        Static.store = nil
    }
    
    class func store() -> RouteRecorderStore {
        if (Static.store == nil) {
            let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RouteRecorderStore")
            fetchedRequest.fetchLimit = 1
            
            let results: [AnyObject]?
            do {
                results = try context.fetch(fetchedRequest)
            } catch let error {
                DDLogWarn(String(format: "Error finding routeRecorderStore: %@", error as NSError))
                results = nil
            }
            
            if let results = results, let routeRecorderStoreResult = results.first as? RouteRecorderStore {
                Static.store = routeRecorderStoreResult
            } else {
                let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
                Static.store = RouteRecorderStore(entity: NSEntityDescription.entity(forEntityName: "RouteRecorderStore", in: context)!, insertInto:context)
                RouteRecorderDatabaseManager.shared.saveContext()
            }
        }
        
        return Static.store
    }

}
