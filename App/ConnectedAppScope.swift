//
//  ConnectedAppScope.swift
//  
//
//  Created by William Henderson on 5/2/16.
//
//

import Foundation
import CoreData
import SwiftyJSON

class ConnectedAppScope: NSManagedObject {
    @NSManaged var descriptionText: String?
    @NSManaged var granted: Bool
    @NSManaged var machineName: String
    @NSManaged var optional: Bool
    @NSManaged var connectedApp: ConnectedApp
    
    class func createOrUpdate(withJson json: JSON, connectedApp: ConnectedApp)->ConnectedAppScope? {
        guard let machineName = json["machine_name"].string else {
            return nil
        }
        
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "ConnectedAppScope")
        fetchedRequest.predicate = NSPredicate(format: "connectedApp == %@ AND machineName == [c] %@", connectedApp, machineName)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        var connectedAppScope : ConnectedAppScope!
        if let result = results?.first as? ConnectedAppScope {
            connectedAppScope = result
        } else {
            connectedAppScope = ConnectedAppScope(entity: NSEntityDescription.entityForName("ConnectedAppScope", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
            connectedAppScope.machineName = machineName
            connectedAppScope.connectedApp = connectedApp
        }
        
        if let optional = json["name"].bool {
            connectedAppScope.optional = optional
        }
        if let descriptionText = json["description_text"].string {
            connectedAppScope.descriptionText = descriptionText
        }
        
        return connectedAppScope
    }
}
