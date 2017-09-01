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

class RouteRecorderDatabaseManager {
    var isStartingUp : Bool = true
    private var usesInMemoryStore: Bool

    static private(set) var shared : RouteRecorderDatabaseManager!
    
    class func startup(_ useInMemoryStore: Bool = false) {
        if (RouteRecorderDatabaseManager.shared == nil) {
            RouteRecorderDatabaseManager.shared = RouteRecorderDatabaseManager(useInMemoryStore: useInMemoryStore)
            DispatchQueue.main.async {
                // run async
                RouteRecorderDatabaseManager.shared.startup()
            }
        }
    }

    init (useInMemoryStore: Bool = false) {
        self.usesInMemoryStore = useInMemoryStore
    }
    
    private func startup () {
        // clean up open route
        for route in Route.openRoutes() {
            if (route.locationCount() <= 6) {
                // if it doesn't more than 6 points, toss it.
                route.cancel()
            } else if !route.isClosed {
                route.close()
            }
        }
        
        self.saveContext()
        self.isStartingUp = false
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RouteRecorderDatabaseManagerDidStartup"), object: nil)
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
        let modelURL = Bundle(for: RouteRecorderDatabaseManager.self).url(forResource: "RouteRecorder", withExtension: "mom")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    private func generatePSC()->NSPersistentStoreCoordinator? {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let options: [AnyHashable: Any]?  = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentStoreTimeoutOption: NSNumber(value: 15),
            NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        
        let url = self.applicationDocumentsDirectory.appendingPathComponent("RouteRecorder.sqlite")
        
        do {
            if (self.usesInMemoryStore) {
                // used for testing Core Data Stack
                try coordinator!.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            } else {
                if  let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url), let versions = metadata["NSStoreModelVersionIdentifiers"] as? NSArray, let firstVersionString = versions.firstObject as? String, let firstVersion = Int(firstVersionString), firstVersion >= 1 {
                    try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
                } else if !FileManager.default.fileExists(atPath: url.path) {
                    try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
                } else {
                    hardResetDatabase(url: url)
                    coordinator = self.persistentStoreCoordinator
                }
            }
        } catch let error {
            DDLogError("Error creating persistent store \(error as NSError), \((error as NSError).userInfo)")
            
            hardResetDatabase(url: url)
            coordinator = self.persistentStoreCoordinator
        }
        
        return coordinator
    }
    
    private func hardResetDatabase(url: URL) {
        DDLogInfo("Hard reseting database!")

        do {
            try FileManager.default.removeItem(at: url)
        }
        catch let error {
            DDLogError("Unresolved error reseting database! \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
        self.persistentStoreCoordinator = self.generatePSC()
        self.managedObjectContext = self.generateMOC()
    }

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = self.generatePSC()

    private func generateMOC()->NSManagedObjectContext? {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
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
