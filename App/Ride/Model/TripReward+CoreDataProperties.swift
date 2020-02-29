//
//  TripReward+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension TripReward {
    @NSManaged public var descriptionText: String
    @NSManaged public var emoji: String
    @NSManaged public var rewardUUID: String?
    @NSManaged public var iconURLString: String?
    @NSManaged public var trip: Trip
    @NSManaged public var earnedAtLatitude: Double
    @NSManaged public var earnedAtLongitude: Double
}
