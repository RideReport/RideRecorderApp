//
//  ConnectedApp.swift
//  
//
//  Created by William Henderson on 5/2/16.
//
//

import Foundation
import CoreData

class ConnectedApp: NSManagedObject {
    @NSManaged var base_image_url: String?
    @NSManaged var name: String?
    @NSManaged var uuid: String
    @NSManaged var profile: Profile?
    @NSManaged var scopes: NSOrderedSet?
}
