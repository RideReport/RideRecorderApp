//
//  ColorPallete.swift
//  Ride
//
//  Created by William Henderson on 5/13/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class ColorPallete : NSObject {
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedPallete : ColorPallete?
    }
    
    class var sharedPallete: ColorPallete {
        dispatch_once(&Static.onceToken) {
            Static.sharedPallete = ColorPallete()
        }
        
        return Static.sharedPallete!
    }
    
    var notificationDestructiveActionRed: UIColor {
        get {
            return UIColor(red: 255.0/255.0, green: 59.0/255.0, blue: 48.0/255.0, alpha: 1.0)
        }
    }
    
    var notificationActionBlue: UIColor {
        get {
            return UIColor(red: 0.0/255.0, green: 122.0/255.0, blue: 255.0/255.0, alpha: 1.0)
        }
    }
    
    var notificationActionGrey: UIColor {
        get {
            return UIColor(red: 138.0/255.0, green: 140.0/255.0, blue: 148.0/255.0, alpha: 1.0)
        }
    }
    
}
