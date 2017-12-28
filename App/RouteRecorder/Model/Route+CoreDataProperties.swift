//
//  Route+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension Route {
    @NSManaged public internal(set) var activityTypeInteger: Int16
    @NSManaged public internal(set) var creationDate: Date
    @NSManaged public internal(set) var closedDate: Date?
    @NSManaged public internal(set) var isClosed: Bool
    @NSManaged public internal(set) var isUploaded: Bool
    @NSManaged public internal(set) var isSummaryUploaded: Bool
    @NSManaged public internal(set) var length: Float
    @NSManaged public internal(set) var uuid: String!
    @NSManaged internal var locations: Set<Location>
    @NSManaged public internal(set) var predictionAggregators: Set<PredictionAggregator>
    @NSManaged internal var simplifiedLocations: Set<Location>
}
