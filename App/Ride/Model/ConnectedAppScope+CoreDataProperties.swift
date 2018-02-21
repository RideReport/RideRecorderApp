//
//  ConnectedAppScope+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension ConnectedAppScope {
    @NSManaged public var descriptionText: String?
    @NSManaged public var isGranted: Bool
    @NSManaged public var machineName: String?
    @NSManaged public var isRequired: Bool
    @NSManaged public var type: String?
    @NSManaged public var connectedApp: ConnectedApp
}
