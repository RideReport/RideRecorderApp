//
//  TripsListRow+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 9/8/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension TripsListRow {
    @NSManaged var isOtherTripsRow: Bool
    @NSManaged var sortName: String
    @NSManaged var bikeTrip: Trip?
    @NSManaged var otherTrips: [Trip]
    @NSManaged var section: TripsListSection
}
