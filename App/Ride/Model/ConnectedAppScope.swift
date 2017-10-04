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

public class ConnectedAppScope: NSManagedObject {
    class func createOrUpdate(withJson json: JSON, connectedApp: ConnectedApp)->ConnectedAppScope? {
        guard let machineName = json["machine_name"].string, let type = json["type"].string else {
            return nil
        }
        
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ConnectedAppScope")
        fetchedRequest.predicate = NSPredicate(format: "connectedApp == %@ AND machineName == [c] %@", connectedApp, machineName)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        var connectedAppScope : ConnectedAppScope!
        if let result = results?.first as? ConnectedAppScope {
            connectedAppScope = result
        } else {
            connectedAppScope = ConnectedAppScope(entity: NSEntityDescription.entity(forEntityName: "ConnectedAppScope", in: context)!, insertInto: context)
            connectedAppScope.machineName = machineName
            connectedAppScope.connectedApp = connectedApp
        }
        
        connectedAppScope.type = type
        
        if let required = json["required"].bool {
            connectedAppScope.isRequired = required
        }
        if let descriptionText = json["description_text"].string {
            connectedAppScope.descriptionText = descriptionText
        }
        
        return connectedAppScope
    }
    
    func json()->JSON {
        var dict: JSON = ["machine_name": self.machineName ?? ""]
        dict["granted"].bool = self.isGranted
        
        return dict
    }
}
