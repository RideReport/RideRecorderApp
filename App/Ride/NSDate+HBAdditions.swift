//
//  NSDate+HBAdditions.swift
//  Ride
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
        
        return NSCalendar.currentCalendar().dateByAddingComponents(dayComponents, toDate:NSDate().beginingOfDay(), options: nil)!
    }
    
    class func yesterday() -> NSDate {
        return NSDate().beginingOfDay().daysFrom(-1)
    }
    
    func hoursFrom(hoursFrom: Int) -> NSDate {
        let dayComponents = NSDateComponents()
        dayComponents.hour = hoursFrom
        
        return NSCalendar.currentCalendar().dateByAddingComponents(dayComponents, toDate:self, options: nil)!
    }
    
    func daysFrom(daysFrom: Int) -> NSDate {
        let dayComponents = NSDateComponents()
        dayComponents.day = daysFrom
        
        return NSCalendar.currentCalendar().dateByAddingComponents(dayComponents, toDate:self, options: nil)!
    }
    
    func beginingOfDay() -> NSDate {
        let dayComponents = NSCalendar.currentCalendar().components(.YearCalendarUnit | .MonthCalendarUnit | .DayCalendarUnit, fromDate: self)
        
        return NSCalendar.currentCalendar().dateFromComponents(dayComponents)!
    }
    
    func isEqualToDay(date:NSDate) -> Bool
    {
        var selfComponents = NSCalendar.autoupdatingCurrentCalendar().components(.YearCalendarUnit | .MonthCalendarUnit | .DayCalendarUnit, fromDate: self);
        var dateComponents = NSCalendar.autoupdatingCurrentCalendar().components(.YearCalendarUnit | .MonthCalendarUnit | .DayCalendarUnit, fromDate: date);
        
        return ((selfComponents.year == dateComponents.year) &&
                (selfComponents.month == dateComponents.month) &&
                (selfComponents.day == dateComponents.day))
    }
    
    func isThisWeek() -> Bool
    {
        var selfComponents = NSCalendar.autoupdatingCurrentCalendar().components(.YearCalendarUnit | .WeekOfYearCalendarUnit, fromDate: self);
        var dateComponents = NSCalendar.autoupdatingCurrentCalendar().components(.YearCalendarUnit | .WeekOfYearCalendarUnit, fromDate: NSDate());
        
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