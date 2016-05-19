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
    @NSManaged var webAuthorizeUrl: String?
    @NSManaged var name: String?
    @NSManaged var uuid: String
    @NSManaged var profile: Profile?
    @NSManaged var scopes: [ConnectedAppScope]
    
    var authorizationCode: String?
    
    class func allApps(limit: Int = 0) -> [ConnectedApp] {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "ConnectedApp")
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.executeFetchRequest(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        guard let apps = results as? [ConnectedApp] else {
            return []
        }
        
        return apps
    }
    
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
        
        if let authURL = json["web_authorize_url"].string {
            connectedApp.webAuthorizeUrl = authURL
        }

        if let scopes = json["scopes"].array {
            var scopesToDelete = connectedApp.scopes
            
            for scope in scopes {
                if let scope = ConnectedAppScope.createOrUpdate(withJson: scope, connectedApp: connectedApp), index = scopesToDelete.indexOf(scope) {
                    scopesToDelete.removeAtIndex(index)
                }
            }
            
            for scope in scopesToDelete {
                // delete any app objects we did not receive
                CoreDataManager.sharedManager.currentManagedObjectContext().deleteObject(scope)
            }
        }
        
        return connectedApp
    }
    
    func json()->JSON {
        var dict: JSON = ["uuid": self.uuid]
        if let code = self.authorizationCode {
            dict["code"].string = code
        }
        
        dict["scopes"].arrayObject = self.scopes.map {return $0.json().object}
        
        return dict
    }
}