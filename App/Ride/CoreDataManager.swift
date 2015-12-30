//
//  CoreDataManager.swift
//  k
//
//  Created by William Henderson on 8/4/14.
//  Copyright (c) 2014 Serious Software. All rights reserved.
//

import Foundation
import CoreData
import EventKit

class CoreDataManager {
    var isStartingUp : Bool = true

    struct Static {
        static var sharedManager : CoreDataManager?
    }

    
    class var sharedManager:CoreDataManager {
        return Static.sharedManager!
    }
    
    class func startup() {
        if (Static.sharedManager == nil) {
            Static.sharedManager = CoreDataManager()
            Static.sharedManager?.startup()
        }
    }

    init () {

    }
    
    private func startup () {
        dispatch_async(dispatch_get_main_queue(), {
            // clean up open trips
            for aTrip in Trip.openTrips() {
                let trip = aTrip as! Trip
                if (trip.locations.count <= 6) {
                    // if it doesn't more than 6 points, toss it.
                    trip.cancel()
                } else if !trip.isClosed {
                    trip.close()
                }
            }
            
            self.saveContext()
            self.isStartingUp = false
            NSNotificationCenter.defaultCenter().postNotificationName("CoreDataManagerDidStartup", object: nil)
        })
    }
    
    func currentManagedObjectContext () -> NSManagedObjectContext {
        return self.managedObjectContext!
    }
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "Serious.k" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] 
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle(forClass: self.dynamicType).URLForResource("Ride", withExtension: "momd")
        return NSManagedObjectModel(contentsOfURL: modelURL!)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var options: [NSObject : AnyObject]?  = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentStoreFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication]
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("HoneyBee.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options)
        } catch let error {
            coordinator = nil
            // Report any error we got.
            var dict : [String : AnyObject] = [:]
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error as NSError
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            DDLogError("Unresolved error \(error as NSError), \((error as NSError).userInfo)")
            abort()
        } catch {
            fatalError()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.mergePolicy = NSMergePolicy(mergeType: NSMergePolicyType.MergeByPropertyObjectTrumpMergePolicyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func rollback () {
        if let moc = self.managedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges {
                moc.rollback()
            }
        }
    }

    func saveContext () {
        if let moc = self.managedObjectContext {
            if moc.hasChanges {
                do {
                    try moc.save()
                } catch let error {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    DDLogError("Unresolved error \(error as NSError), \((error as NSError).userInfo)")
                    abort()
                }
            }
        }
    }
    
}