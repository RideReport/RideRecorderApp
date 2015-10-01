//
//  NSDate+HBAdditions.swift
//  Ride Report
//
//  Created by William Henderson on 12/17/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation


extension NSDate {
    
    class func tomorrow() -> NSDate {
        return NSDate().beginingOfDay().daysFrom(1)
    }
    
    class func nextWeek() -> NSDate {
        let dayComponents = NSDateComponents()
        dayComponents.weekOfYear = 1
        
        return NSCalendar.currentCalendar().dateByAddingComponents(dayComponents, toDate:NSDate().beginingOfDay(), options: [])!
    }
    
    class func yesterday() -> NSDate {
        return NSDate().beginingOfDay().daysFrom(-1)
    }
    
    func hoursFrom(hoursFrom: Int) -> NSDate {
        let dayComponents = NSDateComponents()
        dayComponents.hour = hoursFrom
        
        return NSCalendar.currentCalendar().dateByAddingComponents(dayComponents, toDate:self, options: [])!
    }
    
    func daysFrom(daysFrom: Int) -> NSDate {
        let dayComponents = NSDateComponents()
        dayComponents.day = daysFrom
        
        return NSCalendar.currentCalendar().dateByAddingComponents(dayComponents, toDate:self, options: [])!
    }
    
    func beginingOfDay() -> NSDate {
        let dayComponents = NSCalendar.currentCalendar().components([.Year, .Month, .Day], fromDate: self)
        
        return NSCalendar.currentCalendar().dateFromComponents(dayComponents)!
    }
    
    func isEqualToDay(date:NSDate) -> Bool
    {
        let selfComponents = NSCalendar.autoupdatingCurrentCalendar().components([.Year, .Month, .Day], fromDate: self);
        let dateComponents = NSCalendar.autoupdatingCurrentCalendar().components([.Year, .Month, .Day], fromDate: date);
        
        return ((selfComponents.year == dateComponents.year) &&
                (selfComponents.month == dateComponents.month) &&
                (selfComponents.day == dateComponents.day))
    }
    
    func isThisWeek() -> Bool
    {
        let selfComponents = NSCalendar.autoupdatingCurrentCalendar().components([.Year, .WeekOfYear], fromDate: self);
        let dateComponents = NSCalendar.autoupdatingCurrentCalendar().components([.Year, .WeekOfYear], fromDate: NSDate());
        
        return ((selfComponents.year == dateComponents.year) && (selfComponents.weekOfYear == dateComponents.weekOfYear))
    }
    
    func isInLastWeek() -> Bool
    {
        return (self.compare(NSDate().daysFrom(-6)) == NSComparisonResult.OrderedDescending)
    }
    
    func weekDay() -> String {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "EEEE"
        
        return formatter.stringFromDate(self)
    }
    
    func isToday() -> Bool
    {
        return self.isEqualToDay(NSDate())
    }
    
    func isTomorrow() -> Bool
    {
        return self.isEqualToDay(NSDate.tomorrow())
    }
    
    func isYesterday() -> Bool
    {
        return self.isEqualToDay(NSDate.yesterday())
    }
}