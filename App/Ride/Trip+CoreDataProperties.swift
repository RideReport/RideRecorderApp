//
//  Trip+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension Trip {
    @NSManaged public var activityTypeInteger: Int16
    @NSManaged public var climacon: String?
    @NSManaged public var creationDate: Date
    @NSManaged public var endingPlacemarkName: String?
    @NSManaged public var hasSmoothed: Bool
    @NSManaged public var healthKitUuid: String?
    @NSManaged public var isSavedToHealthKit: Bool
    @NSManaged public var isSynced: Bool
    @NSManaged public var length: Float
    @NSManaged public var areLocationsSynced: Bool
    @NSManaged public var areLocationsNotYetDownloaded: Bool
    @NSManaged public var ratingInteger: Int16
    @NSManaged public var ratingVersion: Int16
    @NSManaged public var startingPlacemarkName: String?
    @NSManaged public var isSummarySynced: Bool
    @NSManaged public var temperature: NSNumber?
    @NSManaged public var uuid: String!
    @NSManaged internal var locations: Set<Location>
    @NSManaged public var predictionAggregators: Set<PredictionAggregator>
    @NSManaged internal var simplifiedLocations: Set<Location>
    @NSManaged public var tripRewards: NSOrderedSet

}
