//
//  ModeSelectorView.swift
//  Ride
//
//  Created by William Henderson on 3/30/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@IBDesignable class ModeSelectorView : UISegmentedControl {
    private var shownModes: [ActivityType] = [.Cycling, .Walking, .Automotive, .Bus, .Rail] {
        didSet {
            reloadUI()
        }
    }
    
    var selectedMode: ActivityType {
        get {
            let selectedIndex = self.selectedSegmentIndex
            guard selectedIndex != -1 else {
                return .Unknown
            }
            
            guard let titleOfSelectedType = self.titleForSegmentAtIndex(selectedIndex) else {
                return .Unknown
            }
            
            for i in 0...ActivityType.count {
                if let type = ActivityType(rawValue: Int16(i)) where type.emoji == titleOfSelectedType {
                    return type
                }
            }
            
            return .Unknown
        }
    }
    
    @IBInspectable var fontSize: CGFloat = 50.0 {
        didSet {
            reloadUI()
        }
    }

    @IBInspectable var showsRunning: Bool {
        get {
            return (shownModes.indexOf(.Running) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Running) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Running)
            }
        }
    }
    
    @IBInspectable var showsCycling: Bool {
        get {
            return (shownModes.indexOf(.Cycling) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Cycling) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Cycling)
            }
        }
    }
    
    @IBInspectable var showsAutomotive: Bool {
        get {
            return (shownModes.indexOf(.Automotive) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Automotive) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Automotive)
            }
        }
    }
    
    @IBInspectable var showsWalking: Bool {
        get {
            return (shownModes.indexOf(.Walking) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Walking) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Walking)
            }
        }
    }
    
    @IBInspectable var showsBus: Bool {
        get {
            return (shownModes.indexOf(.Bus) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Bus) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Bus)
            }
        }
    }
    
    @IBInspectable var showsRail: Bool {
        get {
            return (shownModes.indexOf(.Rail) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Rail) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Rail)
            }
        }
    }
    
    @IBInspectable var showsStationary: Bool {
        get {
            return (shownModes.indexOf(.Stationary) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Stationary) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Stationary)
            }
        }
    }
    
    @IBInspectable var showsAviation: Bool {
        get {
            return (shownModes.indexOf(.Aviation) != nil)
        }
        set {
            if let index = shownModes.indexOf(.Aviation) {
                self.shownModes.removeAtIndex(index)
            }
            
            if newValue {
                self.shownModes.append(.Aviation)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        self.backgroundColor = UIColor.clearColor()
        self.setBackgroundImage(imageWithColor(UIColor.clearColor()), forState: .Normal, barMetrics: .Default)
        self.setBackgroundImage(imageWithColor(ColorPallete.sharedPallete.unknownGrey), forState: .Selected, barMetrics: .Default)
        self.setDividerImage(imageWithColor(UIColor.clearColor()), forLeftSegmentState: .Normal, rightSegmentState: .Normal, barMetrics: .Default)
        
        self.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFontOfSize(self.fontSize)], forState: .Normal)
        self.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFontOfSize(self.fontSize), NSForegroundColorAttributeName:UIColor.blackColor()], forState: .Selected)
        
        reloadUI()
    }
    
    private func imageWithColor(color: UIColor) -> UIImage {
        let rect = CGRectMake(0.0, 0.0, 1.0, 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillRect(context, rect);
        let image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image
    }
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    func reloadUI() {
        self.removeAllSegments()
        
        for (i, mode) in self.shownModes.enumerate() {
            self.insertSegmentWithTitle(mode.emoji, atIndex: i, animated: false)
        }
    }
}