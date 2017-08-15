//
//  Promotion+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension Promotion {
    @NSManaged public var bannerImageUrl: String?
    @NSManaged public var buttonTitle: String?
    @NSManaged public var endDate: Date?
    @NSManaged public var startDate: Date?
    @NSManaged public var text: String?
    @NSManaged public var isUserDismissed: Bool
    @NSManaged public var uuid: String?
    @NSManaged public var connectedApp: ConnectedApp?
    @NSManaged public var profile: Profile?

}
