//
//  NSDate+HBAdditions.swift
//  Ride Report
//
//  Created by William Henderson on 12/17/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation


extension Date {
    static func tomorrow() -> Date {
        return Date().beginingOfDay().daysFrom(1)
    }
    
    static func nextWeek() -> Date {
        var dayComponents = DateComponents()
        dayComponents.weekOfYear = 1
        
        return (Calendar.current as NSCalendar).date(byAdding: dayComponents, to:Date().beginingOfDay(), options: [])!
    }
    
    static func yesterday() -> Date {
        return Date().beginingOfDay().daysFrom(-1)
    }
    
    //
    // MARK: - Helpers
    //
    
    static var jsonDateFormatter: DateFormatter {
        get {
            let jsonDateFormatter = DateFormatter()
            jsonDateFormatter.locale = Locale(identifier: "en_US_POSIX")
            jsonDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZZZ"
            
            return jsonDateFormatter
        }
    }
    
    static var jsonMillisecondDateFormatter: DateFormatter {
        get {
            let jsonMillisecondDateFormatter = DateFormatter()
            jsonMillisecondDateFormatter.locale = Locale(identifier: "en_US_POSIX")
            jsonMillisecondDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZZZ"
        
            return jsonMillisecondDateFormatter
        }
    }
    
    static func dateFromJSONString(_ string: String)->Date? {
        return Date.jsonDateFormatter.date(from: string)
    }
    
    func JSONString() -> String {
        return Date.jsonDateFormatter.string(from: self)
    }
    
    func MillisecondJSONString() -> String {
        return Date.jsonMillisecondDateFormatter.string(from: self)
    }
    
    func isBeforeNoon()->Bool {
        return (self.compare(self.beginingOfDay().hoursFrom(12)) == ComparisonResult.orderedAscending)
    }
    
    func secondsFrom(_ secondsFrom: Int) -> Date {
        var secondComponents = DateComponents()
        secondComponents.second = secondsFrom
        
        return (Calendar.current as NSCalendar).date(byAdding: secondComponents, to:self, options: [])!
    }
    
    func hoursFrom(_ hoursFrom: Int) -> Date {
        var dayComponents = DateComponents()
        dayComponents.hour = hoursFrom
        
        return (Calendar.current as NSCalendar).date(byAdding: dayComponents, to:self, options: [])!
    }
    
    func countOfDaysSinceNow() -> Int {
        let calendar: Calendar = Calendar.current
        
        let date1 = calendar.startOfDay(for: self)
        let date2 = calendar.startOfDay(for: Date())
        
        let components = (calendar as NSCalendar).components(.day, from: date1, to: date2, options: [])
        return components.day!
    }
    
    func daysFrom(_ daysFrom: Int) -> Date {
        var dayComponents = DateComponents()
        dayComponents.day = daysFrom
        
        return (Calendar.current as NSCalendar).date(byAdding: dayComponents, to:self, options: [])!
    }
    
    func beginingOfDay() -> Date {
        let dayComponents = (Calendar.current as NSCalendar).components([.year, .month, .day], from: self)
        
        return Calendar.current.date(from: dayComponents)!
    }
    
    func isEqualToDay(_ date:Date) -> Bool
    {
        let selfComponents = (Calendar.autoupdatingCurrent as NSCalendar).components([.year, .month, .day], from: self);
        let dateComponents = (Calendar.autoupdatingCurrent as NSCalendar).components([.year, .month, .day], from: date);
        
        return ((selfComponents.year == dateComponents.year) &&
                (selfComponents.month == dateComponents.month) &&
                (selfComponents.day == dateComponents.day))
    }
    
    func isThisWeek() -> Bool
    {
        let selfComponents = (Calendar.autoupdatingCurrent as NSCalendar).components([.year, .weekOfYear], from: self);
        let dateComponents = (Calendar.autoupdatingCurrent as NSCalendar).components([.year, .weekOfYear], from: Date());
        
        return ((selfComponents.year == dateComponents.year) && (selfComponents.weekOfYear == dateComponents.weekOfYear))
    }
    
    func isInLastWeek() -> Bool
    {
        return (self.compare(Date().daysFrom(-6)) == ComparisonResult.orderedDescending)
    }
    
    func isThisYear() -> Bool
    {
        let selfComponents = (Calendar.autoupdatingCurrent as NSCalendar).components([.year], from: self);
        let dateComponents = (Calendar.autoupdatingCurrent as NSCalendar).components([.year], from: Date());
        
        return (selfComponents.year == dateComponents.year)
    }
    
    func weekDay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        
        return formatter.string(from: self)
    }
    
    func isToday() -> Bool
    {
        return self.isEqualToDay(Date())
    }
    
    func isTomorrow() -> Bool
    {
        return self.isEqualToDay(Date.tomorrow())
    }
    
    func isYesterday() -> Bool
    {
        return self.isEqualToDay(Date.yesterday())
    }
}

extension TimeInterval {
    var intervalString: String {
        let minutes = ceil((self / 60)).truncatingRemainder(dividingBy: 60)
        let hours = Int(self) / 3600
        return String(format: "%02d:%02.0f", hours, minutes)
    }
}
