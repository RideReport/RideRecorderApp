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
import CocoaLumberjack

public class ConnectedApp: NSManagedObject {
    var authorizationCode: String?
    
    class func allApps(_ limit: Int = 0) -> [ConnectedApp] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ConnectedApp")
        if (limit != 0) {
            fetchedRequest.fetchLimit = limit
        }
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        guard let apps = results as? [ConnectedApp] else {
            return []
        }
        
        return apps
    }
    
    class func createOrUpdate(_ uuid: String)->ConnectedApp {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ConnectedApp")
        fetchedRequest.predicate = NSPredicate(format: "uuid == [c] %@", uuid)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if let result = results?.first as? ConnectedApp {
            return result
        }
        
        let app = ConnectedApp(entity: NSEntityDescription.entity(forEntityName: "ConnectedApp", in: context)!, insertInto: context)
        app.uuid = uuid
        
        return app
    }
    
    class func createOrUpdate(withJson json: JSON)->ConnectedApp? {
        guard let uuid = json["uuid"].string else {
            return nil
        }
        
        let connectedApp = ConnectedApp.createOrUpdate(uuid)
        connectedApp.updateWithJson(withJson: json)
        
        return connectedApp
    }
    
    func updateWithJson(withJson json: JSON) {
        self.baseImageUrl = json["base_image_url"].string
        self.appSettingsUrl = json["app_settings_url"].string
        self.appSettingsText = json["app_settings_text"].string
        self.name = json["name"].string
        self.descriptionText = json["description_text"].string
        self.connectButtonTitleText = json["connect_button_title_text"].string
        self.fieldsHeaderText = json["fields_header_text"].string
        self.scopesHeaderText = json["scope_header_text"].string
        self.webAuthorizeUrl = json["web_authorize_url"].string
        self.companyName = json["company_name"].string
        
        if let scopes = json["scopes"].array {
            var scopesToDelete = self.scopes.array as? [ConnectedAppScope] ?? []
            
            for scope in scopes {
                if let scope = ConnectedAppScope.createOrUpdate(withJson: scope, connectedApp: self), let index = scopesToDelete.index(of: scope) {
                    scopesToDelete.remove(at: index)
                }
            }
            
            for scope in scopesToDelete {
                // delete any app objects we did not receive
                CoreDataManager.shared.currentManagedObjectContext().delete(scope)
            }
        }
        
        if let fields = json["fields"].array {
            var fieldsToDelete = self.fields.array as? [ConnectedAppField] ?? []
            
            for field in fields {
                if let field = ConnectedAppField.createOrUpdate(withJson: field, connectedApp: self), let index = fieldsToDelete.index(of: field) {
                    fieldsToDelete.remove(at: index)
                }
            }
            
            for field in fieldsToDelete {
                // delete any app objects we did not receive
                CoreDataManager.shared.currentManagedObjectContext().delete(field)
            }
        }
    }
    
    func json()->JSON {
        var dict: JSON = ["uuid": self.uuid]
        if let code = self.authorizationCode {
            dict["code"].string = code
        }
        
        let scopes = self.scopes.array as? [ConnectedAppScope] ?? []
        
        let fields = self.fields.array as? [ConnectedAppField] ?? []

        
        dict["scopes"].arrayObject = scopes.map {return $0.json().object}
        dict["fields"].arrayObject = fields.map {return $0.json().object}
        
        return dict
    }
}
