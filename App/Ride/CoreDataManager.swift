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
    private var usesInMemoryStore: Bool

    static private(set) var shared : CoreDataManager!
    
    class func startup(_ useInMemoryStore: Bool = false) {
        if (CoreDataManager.shared == nil) {
            CoreDataManager.shared = CoreDataManager(useInMemoryStore: useInMemoryStore)
            DispatchQueue.main.async {
                // run async
                CoreDataManager.shared.startup()
            }
        }
    }

    init (useInMemoryStore: Bool = false) {
        self.usesInMemoryStore = useInMemoryStore
    }
    
    private func startup () {
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
        NotificationCenter.default.post(name: Notification.Name(rawValue: "CoreDataManagerDidStartup"), object: nil)
    }
    
    func resetDatabase() {
        guard let coordinator = self.persistentStoreCoordinator else {
            return
        }
        
        self.managedObjectContext?.reset()
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
                if let url = store.url {
                    try FileManager.default.removeItem(at: url)
                }
            }
            catch let error {
                DDLogError("Unresolved error reseting database! \(error as NSError), \((error as NSError).userInfo)")
                abort()
            }
        }
        
        self.persistentStoreCoordinator = self.generatePSC()
        self.managedObjectContext = self.generateMOC()
    }
    
    func currentManagedObjectContext () -> NSManagedObjectContext {
        return self.managedObjectContext!
    }
    
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1] 
    }()
    
    lazy var sharedGroupContainerDirectory: URL = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Knock.RideReport")!
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "Ride", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    private func generatePSC()->NSPersistentStoreCoordinator? {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let options: [AnyHashable: Any]?  = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        
        let url = self.applicationDocumentsDirectory.appendingPathComponent("HoneyBee.sqlite")
        
        let failureReason = "There was an error creating or loading the application's saved data."
        do {
            if (self.usesInMemoryStore) {
                // used for testing Core Data Stack
                try coordinator!.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            } else {
                try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
            }
        } catch let error {
            coordinator = nil
            // Report any error we got.
            var dict : [String : AnyObject] = [:]
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
            dict[NSUnderlyingErrorKey] = error as NSError
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            DDLogError("Unresolved error \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        
        return coordinator
    }

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = self.generatePSC()

    private func generateMOC()->NSManagedObjectContext? {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        let managedObjectContext = NSManagedObjectContext()
        managedObjectContext.mergePolicy = NSMergePolicy(merge: NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }
    
    lazy var managedObjectContext: NSManagedObjectContext? = self.generateMOC()

    // MARK: - Core Data Saving support

    func rollback () {
        if let moc = self.managedObjectContext {
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
