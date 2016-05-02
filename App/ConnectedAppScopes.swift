//
//  ConnectedAppScopes.swift
//  
//
//  Created by William Henderson on 5/2/16.
//
//

import Foundation
import CoreData

class ConnectedAppScopes: NSManagedObject {
    @NSManaged var descriptionText: String?
    @NSManaged var granted: Bool
    @NSManaged var machineName: String
    @NSManaged var optional: Bool
    @NSManaged var connectedApp: ConnectedApp
}
