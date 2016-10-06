//
//  NSLocale+Additions.swift
//  Ride
//
//  Created by William Henderson on 10/5/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

extension NSLocale {
    class func isMetric() -> Bool {
        let locale = NSLocale.currentLocale()
        return locale.objectForKey(NSLocaleUsesMetricSystem) as! Bool
    }
    
    class func isGB()-> Bool {
        if let countryString = NSLocale.currentLocale().objectForKey(NSLocaleCountryCode) as? String {
            return countryString == "GB"
        }
        
        return false
    }
}
