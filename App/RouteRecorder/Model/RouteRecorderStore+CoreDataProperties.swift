//
//  Profile+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension RouteRecorderStore {
    @NSManaged public internal(set)var lastArrivalLocation: Location?
}
