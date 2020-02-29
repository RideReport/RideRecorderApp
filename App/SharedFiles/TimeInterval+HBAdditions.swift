//
//  TimeInterval+HBAdditions.swift
//  Ride
//
//  Created by William Henderson on 8/14/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

extension TimeInterval {
    func debugDescription()->String {
        if self >=  TimeInterval.greatestFiniteMagnitude {
            return "Unlimited seconds"
        } else {
            return String(format: "%.0f seconds", self)
        }
    }
}
