//
//  ColorPallete.swift
//  Ride Report
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
    
    var autoBrown: UIColor {
        get {
            return UIColor(red: 254/255, green: 191/255, blue: 51/255, alpha: 1.0)
        }
    }
    
    var transitBlue: UIColor {
        get {
            return UIColor(red: 39/255, green: 87/255, blue: 195/255, alpha: 1.0)
        }
    }
    
    var darkGreen: UIColor {
        get {
            return UIColor(red: 78/255, green: 142/255, blue: 66/255, alpha: 1.0)
        }
    }

    var goodGreen: UIColor {
        get {
            return UIColor(red: 132/255, green: 187/255, blue: 53/255, alpha: 1.0)
        }
    }
    
    var badRed: UIColor {
        get {
            return UIColor(red: 178/255, green: 51/255, blue: 108/255, alpha: 1.0)
        }
    }
    
    var unknownGrey: UIColor {
        get {
            return UIColor(red: 215/255, green: 223/255, blue: 202/255, alpha: 1.0)
        }
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
