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
    
    func queryCondition(date: NSDate, location: Location, handler: (CZWeatherData?)->Void) {
        let request = CZOpenWeatherMapRequest.newCurrentRequest()
        request.location = CZWeatherLocation(fromCoordinate: location.coordinate())
        
        request.sendWithCompletion { (data, error) -> Void in
            if (data != nil && error == nil) {
                handler(data)
            }
            
            handler(nil)
        }
    }
    
}
