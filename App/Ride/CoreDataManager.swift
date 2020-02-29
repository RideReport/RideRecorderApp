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
import RouteRecorder
import CocoaLumberjack

class CoreDataManager {
    var isStartingUp : Bool = true
    private var usesInMemoryStore: Bool

    static private(set) var shared : CoreDataManager!
    
    class func startup(_ useInMemoryStore: Bool = false) {
        if (CoreDataManager.shared == nil) {
            CoreDataManager.shared = CoreDataManager(useInMemoryStore: useInMemoryStore)
            if CoreDataManager.shared.managedObjectContext == nil {
                CoreDataManager.shared.persistentStoreCoordinator = CoreDataManager.shared.generatePSC()
                CoreDataManager.shared.managedObjectContext = CoreDataManager.shared.generateMOC()
            }
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
        isStartingUp = false
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
        let modelURL = Bundle(for: CoreDataManager.self).url(forResource: "RideReport", withExtension: "momd")!
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
        
        let url = self.applicationDocumentsDirectory.appendingPathComponent("HoneyBee.sqlite")
        
        do {
            if (self.usesInMemoryStore) {
                // used for testing Core Data Stack
                try coordinator!.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            } else {
                if  let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url), let versions = metadata["NSStoreModelVersionIdentifiers"] as? NSArray, let firstVersionString = versions.firstObject as? String, let firstVersion = Int(firstVersionString), firstVersion >= 24 {
                    try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
                } else if !FileManager.default.fileExists(atPath: url.path) {
                    try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
                } else {
                    attemptProfileRecoveryAndResetDatabase(atURL: url)
                    coordinator = self.persistentStoreCoordinator
                }
            }
        } catch let error {
            DDLogError("Error creating persistent store \(error as NSError), \((error as NSError).userInfo)")
            
            attemptProfileRecoveryAndResetDatabase(atURL: url)
            coordinator = self.persistentStoreCoordinator
        }
        
        return coordinator
    }
    
    private func attemptProfileRecoveryAndResetDatabase(atURL url: URL) {
        if let accessToken = KeychainManager.shared.accessToken, !accessToken.isEmpty {
            DDLogInfo("Found access token in keychain.")
            hardResetDatabase(url: url)
        } else if let (accessToken, accessTokenExpiresIn) = recoverAccessToken(fromDatabaseAtURL: url) {
            DDLogInfo("Recovered access token.")
            
            hardResetDatabase(url: url)
            
            KeychainManager.shared.accessToken = accessToken
            KeychainManager.shared.accessTokenExpiresIn = accessTokenExpiresIn
            self.saveContext()
        } else {
            DDLogInfo("Failed to recover access token!")
            hardResetDatabase(url: url)
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: "CoreDataManagerDidHardResetWithReadError"), object: nil)
        }
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
        Profile.resetProfile()
    }
    
    private func recoverAccessToken(fromDatabaseAtURL url: URL)->(String, Date)? {
        var db: OpaquePointer? = nil
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            DDLogWarn("error opening database")
        } else {
            sqlite3_exec(db, "PRAGMA writable_schema=ON", nil, nil, nil)
            
            var statement: OpaquePointer? = nil
            
            sqlite3_prepare_v2(db, "select ZACCESSTOKEN, ZACCESSTOKENEXPIRESIN from ZPROFILE;", -1, &statement, nil)
            
            defer {
                sqlite3_finalize(statement)
                sqlite3_exec(db, "PRAGMA writable_schema=OFF;", nil, nil, nil)
                sqlite3_close(db)
            }
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let tokenChars = sqlite3_column_text(statement, 0), let expiresInChars = sqlite3_column_text(statement, 1) {
                    let tokenString = String(cString: tokenChars)
                    let expiresInString = String(cString: expiresInChars)
                    var expiresDate: Date = Date(timeIntervalSinceNow: 365*24*60*60) // if we can't extract the expires in, just use a year in the future
        
                    if let expiresInTimeInterval = Double(expiresInString) {
                        expiresDate = Date(timeIntervalSinceReferenceDate: expiresInTimeInterval)
                    }
                    return (tokenString, expiresDate)
                } else {
                    DDLogWarn("Access token not found in results")
                }
            }
            
        }
        
        DDLogWarn("Failed to recover access token!")
        return nil
    }

    var persistentStoreCoordinator: NSPersistentStoreCoordinator?

    private func generateMOC()->NSManagedObjectContext? {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        if self.persistentStoreCoordinator == nil {
            self.persistentStoreCoordinator = self.generatePSC()
            guard self.persistentStoreCoordinator != nil else {
                return nil
            }
        }
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergePolicy(merge: NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType)
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        return managedObjectContext
    }
    
    var managedObjectContext: NSManagedObjectContext?

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
