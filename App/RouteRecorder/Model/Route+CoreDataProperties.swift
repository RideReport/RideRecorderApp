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
    @NSManaged public var activityTypeInteger: Int16
    @NSManaged public var creationDate: Date
    @NSManaged public var isClosed: Bool
    @NSManaged public var isUploaded: Bool
    @NSManaged public var isSummaryUploaded: Bool
    @NSManaged public var length: Float
    @NSManaged public var ratingInteger: Int16
    @NSManaged public var ratingVersion: Int16
    @NSManaged public var uuid: String!
    @NSManaged internal var locations: Set<Location>
    @NSManaged public var predictionAggregators: Set<PredictionAggregator>
    @NSManaged internal var simplifiedLocations: Set<Location>
}
