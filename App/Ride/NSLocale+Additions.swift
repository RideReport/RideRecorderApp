//
//  NSLocale+Additions.swift
//  Ride
//
//  Created by William Henderson on 10/5/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

extension Locale {
    static func isMetric() -> Bool {
        let locale = Locale.current
        return (locale as NSLocale).object(forKey: NSLocale.Key.usesMetricSystem) as! Bool
    }
    
    static func isGB()-> Bool {
        if let countryString = (Locale.current as NSLocale).object(forKey: NSLocale.Key.countryCode) as? String {
            return countryString == "GB"
        }
        
        return false
    }
}
