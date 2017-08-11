//
//  Rating.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

enum RatingChoice: Int16 {
    case notSet = 0
    case good
    case bad
    case mixed
    
    var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
    
    var notificationActionIdentifier: String {
        get {
            switch self {
            case .bad:
                return "BAD_RIDE_IDENTIFIER"
            case .good:
                return "GOOD_RIDE_IDENTIFIER"
            case .mixed:
                return "MIXED_RIDE_IDENTIFIER"
            case .notSet:
                return ""
            }
        }
    }
}

enum RatingVersion: Int16 {
    case v1 = 0
    case v2beta
    
    var availableRatings: [Rating] {
        switch self {
        case .v1:
            return [Rating.init(choice: .bad, version: .v1), Rating.init(choice: .good, version: .v1)]
        case .v2beta:
            return [Rating.init(choice: .bad, version: .v2beta), Rating.init(choice: .mixed, version: .v2beta), Rating.init(choice: .good, version: .v2beta)]
        }
    }
    
    var numberValue: NSNumber {
        return NSNumber(value: self.rawValue as Int16)
    }
}

extension Rating: Equatable {}
func ==(lhs: Rating, rhs: Rating) -> Bool {
    return lhs.choice == rhs.choice && lhs.version == rhs.version
}

struct Rating {
    private(set) var choice: RatingChoice
    private(set) var version: RatingVersion
    
    static func ratingWithCurrentVersion(_ choice: RatingChoice) -> Rating {
        return Rating(choice: choice, version: Profile.profile().ratingVersion)
    }
    
    init(choice: RatingChoice, version: RatingVersion) {
        self.choice = choice
        self.version = version
    }
    
    init(rating: Int16, version: Int16) {
        self.choice = RatingChoice(rawValue: rating) ?? RatingChoice.notSet
        self.version = RatingVersion(rawValue: version) ?? Profile.profile().ratingVersion
    }
    
    var emoji: String {
        get {
            switch self.choice {
            case .bad:
                return "😡"
            case .good:
                return "☺️"
            case .mixed:
                return "😕"
            case .notSet:
                return ""
            }
        }
    }
    
    var noun: String {
        get {
            switch self.version {
            case .v1:
                switch self.choice {
                case .bad:
                    return "Not Great"
                case .good:
                    return "Great"
                case .mixed:
                    return "Mixed"
                case .notSet:
                    return ""
                }
            case .v2beta:
                switch self.choice {
                case .bad:
                    return "Stressful"
                case .good:
                    return "Chill"
                case .mixed:
                    return "Mixed"
                case .notSet:
                    return ""
                }
            }
        }
    }
}
