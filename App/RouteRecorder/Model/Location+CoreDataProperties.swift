//
//  Location+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension Location {
    @NSManaged public var altitude: Double
    @NSManaged public var course: Double
    @NSManaged public var date: Date
    @NSManaged public var horizontalAccuracy: Double
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var sourceInteger: Int16
    @NSManaged public var speed: Double
    @NSManaged public var verticalAccuracy: Double
    @NSManaged public var simplifiedInRoute: Route?
    @NSManaged public var route: Route?
    @NSManaged public var lastArrivalLocationOfRouteRecorderStore: RouteRecorderStore?
}
