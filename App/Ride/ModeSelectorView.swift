//
//  ModeSelectorView.swift
//  Ride
//
//  Created by William Henderson on 3/30/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@IBDesignable class ModeSelectorView : UISegmentedControl {
    private var feedbackGenerator: NSObject!
    
    private var shownModes: [ActivityType] = [.cycling, .walking, .running, .automotive, .bus, .rail] {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var fontSize: CGFloat = 40.0 {
        didSet {
            reloadUI()
        }
    }
    
    var selectedMode: ActivityType {
        get {
            let selectedIndex = self.selectedSegmentIndex
            guard selectedIndex != -1 else {
                return .unknown
            }
            
            guard let titleOfSelectedType = self.titleForSegment(at: selectedIndex) else {
                return .unknown
            }
            
            for i in 0...ActivityType.count {
                if let type = ActivityType(rawValue: Int16(i)), type.emoji == titleOfSelectedType {
                    return type
                }
            }
            
            return .unknown
        }
    }

    @IBInspectable var showsRunning: Bool {
        get {
            return (shownModes.index(of: .running) != nil)
        }
        set {
            if let index = shownModes.index(of: .running) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.running)
            }
        }
    }
    
    @IBInspectable var showsCycling: Bool {
        get {
            return (shownModes.index(of: .cycling) != nil)
        }
        set {
            if let index = shownModes.index(of: .cycling) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.cycling)
            }
        }
    }
    
    @IBInspectable var showsAutomotive: Bool {
        get {
            return (shownModes.index(of: .automotive) != nil)
        }
        set {
            if let index = shownModes.index(of: .automotive) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.automotive)
            }
        }
    }
    
    @IBInspectable var showsWalking: Bool {
        get {
            return (shownModes.index(of: .walking) != nil)
        }
        set {
            if let index = shownModes.index(of: .walking) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.walking)
            }
        }
    }
    
    @IBInspectable var showsBus: Bool {
        get {
            return (shownModes.index(of: .bus) != nil)
        }
        set {
            if let index = shownModes.index(of: .bus) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.bus)
            }
        }
    }
    
    @IBInspectable var showsRail: Bool {
        get {
            return (shownModes.index(of: .rail) != nil)
        }
        set {
            if let index = shownModes.index(of: .rail) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.rail)
            }
        }
    }
    
    @IBInspectable var showsStationary: Bool {
        get {
            return (shownModes.index(of: .stationary) != nil)
        }
        set {
            if let index = shownModes.index(of: .stationary) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.stationary)
            }
        }
    }
    
    @IBInspectable var showsAviation: Bool {
        get {
            return (shownModes.index(of: .aviation) != nil)
        }
        set {
            if let index = shownModes.index(of: .aviation) {
                self.shownModes.remove(at: index)
            }
            
            if newValue {
                self.shownModes.append(.aviation)
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
        self.backgroundColor = UIColor.clear
        self.setBackgroundImage(imageWithColor(UIColor.clear), for: UIControlState(), barMetrics: .default)
        self.setBackgroundImage(imageWithColor(ColorPallete.sharedPallete.unknownGrey), for: .selected, barMetrics: .default)
        self.setDividerImage(imageWithColor(UIColor.clear), forLeftSegmentState: UIControlState(), rightSegmentState: UIControlState(), barMetrics: .default)
        
        self.apportionsSegmentWidthsByContent = true
        
        if #available(iOS 9.0, *) {
            UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).adjustsFontSizeToFitWidth = true
            UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).minimumScaleFactor = 0.4
            UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).numberOfLines = 0
        } else {
            self.fontSize = 30
        }
        
        self.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: self.fontSize)], for: UIControlState())
        self.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: self.fontSize), NSForegroundColorAttributeName:UIColor.black], for: .selected)
        
        self.addTarget(self, action: #selector(ModeSelectorView.valueChanged(_:)), for: .valueChanged)
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.medium)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
        
        reloadUI()
    }
    
    func valueChanged(_ sender:UIButton)
    {
        if #available(iOS 10.0, *) {
            if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                feedbackGenerator.impactOccurred()
            }
        }
        
        // make the button "sticky"
        sender.isSelected = !sender.isSelected
    }
    
    private func imageWithColor(_ color: UIColor) -> UIImage {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    func reloadUI() {
        self.removeAllSegments()
        
        for (i, mode) in self.shownModes.enumerated() {
            self.insertSegment(withTitle: mode.emoji, at: i, animated: false)
        }
    }
}
