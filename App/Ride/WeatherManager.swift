//
//  WeatherManager.swift
//  Ride
//
//  Created by William Henderson on 04/07/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CZWeatherKit

class WeatherManager {
    let openWeatherMapKey = "46cde0cc54593d8925337f942875ba7b"
    
    struct Static {
        static var sharedManager : WeatherManager?
    }
    
    class var sharedManager:WeatherManager {
        return Static.sharedManager!
    }
    
    class func startup() {
        Static.sharedManager = WeatherManager()
        Static.sharedManager?.startup()
    }
    
    func startup() {
    }
    
    func queryCondition(date: NSDate, location: Location, handler: (CZWeatherCondition?)->Void) {
        let request = CZWeatherRequest(type: CZWeatherRequestType.CurrentConditionsRequestType)
        request.location = CZWeatherLocation(CLLocationCoordinate2D: location.coordinate())
        request.service = CZOpenWeatherMapService(key: openWeatherMapKey)
        
        request.performRequestWithHandler { (data, error) -> Void in
            if (data != nil && error == nil) {
                let currentCondition = data as! CZWeatherCondition;
                handler(currentCondition)
            }
            
            handler(nil)
        }
    }
    
}
