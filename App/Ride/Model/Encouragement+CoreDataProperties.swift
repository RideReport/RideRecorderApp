//
//  Encouragement+CoreDataProperties.swift
//  Ride
//
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

extension Encouragement {
    @NSManaged public var descriptionText: String
    @NSManaged public var emoji: String
    @NSManaged public var profile: Profile
}
