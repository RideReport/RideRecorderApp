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
    private var yearDateFormatter: DateFormatter!
    private var timeInterval: Double!
    
    init(timeInterval: Double, dateFormat: String) {
        super.init()
        
        self.timeInterval = timeInterval

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = dateFormat
        
        self.yearDateFormatter = DateFormatter()
        self.yearDateFormatter.dateFormat = dateFormat + " ''yy"
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSinceReferenceDate: value*self.timeInterval)
        
        if (date.isThisYear()) {
            return self.dateFormatter.string(from: date)
        } else {
            return self.yearDateFormatter.string(from: date)
        }
    }
}
