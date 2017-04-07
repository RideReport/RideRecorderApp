//
//  ColorPallete.swift
//  Ride Report
//
//  Created by William Henderson on 5/13/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//
// http://paletton.com/palette.php?uid=72E0u0kmeu%2BcyLHhWBtrksVtxm-

import Foundation

class ColorPallete : NSObject {
    static let shared = ColorPallete()
    
    var autoBrown: UIColor {
        get {
            return UIColor(red: 254/255, green: 191/255, blue: 51/255, alpha: 1.0)
        }
    }
    
    var almostWhite: UIColor {
        get {
            return UIColor(red: 244/255, green: 255/255, blue: 236/255, alpha: 1.0)
        }
    }
    
    var transitBlue: UIColor {
        get {
            return UIColor(red: 39/255, green: 87/255, blue: 195/255, alpha: 1.0)
        }
    }
    
    var darkGrey: UIColor {
        get {
            return UIColor(red: 67/255, green: 67/255, blue: 67/255, alpha: 1.0)
        }
    }
    
    var primaryLight: UIColor {
        get {
            return UIColor(red: 123/255, green: 216/255, blue: 66/255, alpha: 1.0)
        }
    }
    
    var orange: UIColor {
        get {
            return UIColor(red: 247/255, green: 133/255, blue: 75/255, alpha: 1.0)
        }
    }
    
    var pink: UIColor {
        get {
            return UIColor(red: 227/255, green: 69/255, blue: 106/255, alpha: 1.0)
        }
    }
    
    var turquoise: UIColor {
        get {
            return UIColor(red: 50/255, green: 164/255, blue: 127/255, alpha: 1.0)
        }
    }
    
    var primary: UIColor {
        get {
            return UIColor(red: 71/255, green: 179/255, blue: 12/255, alpha: 1.0)
        }
    }
    
    var primaryDark: UIColor {
        get {
            return UIColor(red: 60/255, green: 154/255, blue: 17/255, alpha: 1.0)
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
    
    var brightBlue: UIColor {
        get {
            return UIColor(red: 0.0/255.0, green: 190.0/255.0, blue: 255.0/255.0, alpha: 1.0)
        }
    }
    
}
