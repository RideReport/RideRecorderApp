//
//  ConnectedApp.swift
//  
//
//  Created by William Henderson on 5/2/16.
//
//

import Foundation
import CoreData
import SwiftyJSON

class ConnectedApp: NSManagedObject {
    @NSManaged var baseImageUrl: String?
    @NSManaged var descriptionText: String?
    @NSManaged var name: String?
    @NSManaged var uuid: String
    @NSManaged var profile: Profile?
    @NSManaged var scopes: NSOrderedSet?
    
    class func createOrUpdate(withJson json: JSON)->ConnectedApp? {
        guard let uuid = json["uuid"].string else {
            return nil
        }
        
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
                let fetchedRequest = NSFetchRequest(entityName: "ConnectedApp")
        fetchedRequest.predicate = NSPredicate(format: "uuid == [c] %@", uuid)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        var connectedApp : ConnectedApp!
        if let result = results?.first as? ConnectedApp {
            connectedApp = result
        } else {
            connectedApp = ConnectedApp(entity: NSEntityDescription.entityForName("ConnectedApp", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
            connectedApp.uuid = uuid
        }
        
        if let baseImageUrl = json["base_image_url"].string {
            connectedApp.baseImageUrl = baseImageUrl
        }
        if let name = json["name"].string {
            connectedApp.name = name
        }
        if let descriptionText = json["description_text"].string {
            connectedApp.descriptionText = descriptionText
        }

        if let scopes = json["scopes"].array {
            for scope in scopes {
                ConnectedAppScope.createOrUpdate(withJson: scope, connectedApp: connectedApp)
            }
        }
        
        return connectedApp
    }
}
