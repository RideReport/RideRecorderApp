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
import CocoaLumberjack

public class ConnectedAppField: NSManagedObject {
    class func createOrUpdate(withJson json: JSON, connectedApp: ConnectedApp)->ConnectedAppField? {
        guard let machineName = json["machine_name"].string, let type = json["type"].string, let required = json["required"].bool,
        let descriptionText = json["description_text"].string else {
            return nil
        }
        
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ConnectedAppField")
        fetchedRequest.predicate = NSPredicate(format: "connectedApp == %@ AND machineName == [c] %@", connectedApp, machineName)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        var connectedAppfield : ConnectedAppField!
        if let result = results?.first as? ConnectedAppField {
            connectedAppfield = result
        } else {
            connectedAppfield = ConnectedAppField(entity: NSEntityDescription.entity(forEntityName: "ConnectedAppField", in: context)!, insertInto: context)
            connectedAppfield.machineName = machineName
            connectedAppfield.connectedApp = connectedApp
        }
        
        connectedAppfield.type = type
        connectedAppfield.isRequired = required
        connectedAppfield.descriptionText = descriptionText
        
        if let defaultText = json["default_text"].string {
            connectedAppfield.defaultText = defaultText
        }
        
        if let placeholderText = json["placeholder_text"].string {
            connectedAppfield.placeholderText = placeholderText
        }
        
        return connectedAppfield
    }
    
    func json()->JSON {
        var dict: JSON = ["machine_name": self.machineName]
        dict["value"].string = self.value ?? ""
        return dict
    }
}
