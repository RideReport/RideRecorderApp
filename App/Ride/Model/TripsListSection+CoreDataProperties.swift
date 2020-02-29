//
//  TripsListSection+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 9/8/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension TripsListSection {
    @NSManaged var date: Date
    @NSManaged var rows: Set<TripsListRow>
    @NSManaged var otherTripsRow: TripsListRow?
}
