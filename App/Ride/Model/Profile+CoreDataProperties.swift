//
//  Profile+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

extension Profile {
    @NSManaged public var currentRatingVersion: Int16
    @NSManaged public var dateOfBirth: Date?
    @NSManaged public var statusEmoji: String?
    @NSManaged public var statusText: String?
    @NSManaged public var supportId: String?
    @NSManaged public var uuid: String?
    @NSManaged public var connectedApps: Set<ConnectedApp>?
    @NSManaged public var promotions: NSOrderedSet
    @NSManaged internal var nextSyncURLString: String?
    @NSManaged internal var nextPageURLString: String?
}
