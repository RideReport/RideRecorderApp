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

    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var SharedInstance : CoreDataManager?
    }

    
    class var sharedCoreDataManager:CoreDataManager {
        dispatch_once(&Static.onceToken) {
            Static.SharedInstance = CoreDataManager()
        }
        
        return Static.SharedInstance!
    }

    
    init () {

    }
    
    func startup () {
        // clean up bad trips
        for trip in Trip.emptyTrips()! {
            (trip as! Trip).managedObjectContext?.deleteObject((trip as! Trip))
        }
        
        self.saveContext()
    }
    
    func currentManagedObjectContext () -> NSManagedObjectContext {
        return self.managedObjectContext!
    }
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "Serious.k" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as! NSURL
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("Ride", withExtension: "momd")
        return NSManagedObjectModel(contentsOfURL: modelURL!)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var options  = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("HoneyBee.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict as [NSObject : AnyObject])
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            DDLogWrapper.logError("Unresolved error \(error), \(error!.userInfo)")
            abort()
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
            var error: NSError? = nil
            if moc.hasChanges && !moc.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                DDLogWrapper.logError("Unresolved error \(error), \(error!.userInfo)")
                abort()
            }
        }
    }
    
}