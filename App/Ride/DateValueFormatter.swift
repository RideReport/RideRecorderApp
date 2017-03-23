//
//  DateValueFormatter.swift
//  Ride
//
//  Created by William Henderson on 3/22/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Charts

class DateValueFormatter: NSObject, IAxisValueFormatter {
    private var dateFormatter: DateFormatter!
    
    init(showsDate: DarwinBoolean) {
        super.init()

        dateFormatter = DateFormatter()
        if (showsDate.boolValue) {
            dateFormatter.dateFormat = "MMM dd"
        } else {
            dateFormatter.dateFormat = "MMM"
        }
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSinceReferenceDate: value*24*3600)
        
        return dateFormatter.string(from: date)
    }
}
