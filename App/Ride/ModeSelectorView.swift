//
//  ModeSelectorView.swift
//  Ride
//
//  Created by William Henderson on 3/30/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder

@IBDesignable class ModeSelectorView : UISegmentedControl {
    private var feedbackGenerator: NSObject!
    
    public let shownModes: [ActivityType] = [.cycling, .walking, .automotive, .bus, .rail]
    
    private var fontSize: CGFloat = 40.0
    
    public var selectedMode: ActivityType = .unknown
    
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
        self.setBackgroundImage(imageWithColor(ColorPallete.shared.unknownGrey), for: .selected, barMetrics: .default)
        self.setDividerImage(imageWithColor(UIColor.clear), forLeftSegmentState: UIControlState(), rightSegmentState: UIControlState(), barMetrics: .default)
        self.isMomentary = true
        self.apportionsSegmentWidthsByContent = true
        
        if #available(iOS 9.0, *) {
            UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).adjustsFontSizeToFitWidth = true
            UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).minimumScaleFactor = 0.4
            UILabel.appearance(whenContainedInInstancesOf: [UISegmentedControl.self]).numberOfLines = 0
        }
        
        self.addTarget(self, action: #selector(ModeSelectorView.valueChanged(_:)), for: .valueChanged)
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.medium)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
        
        reloadUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.fontSize = self.frame.width / CGFloat(self.shownModes.count) - 26.0
        
        self.setTitleTextAttributes([NSAttributedStringKey.font: UIFont.systemFont(ofSize: self.fontSize)], for: UIControlState())
        self.setTitleTextAttributes([NSAttributedStringKey.font: UIFont.systemFont(ofSize: self.fontSize), NSAttributedStringKey.foregroundColor:UIColor.black], for: .selected)
    }
    
    @objc func valueChanged(_ sender:UIButton)
    {
        if self.selectedSegmentIndex == self.numberOfSegments - 1 {
            // if they select the other segment, nothing has been selected
            self.selectedSegmentIndex = UISegmentedControlNoSegment
            self.selectedMode = .unknown
        } else {
            if #available(iOS 10.0, *) {
                if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                    feedbackGenerator.impactOccurred()
                }
            }
            
            let selectedIndex = self.selectedSegmentIndex
            guard selectedIndex != -1 else {
                self.selectedMode = .unknown
                return
            }
            
            guard let titleOfSelectedType = self.titleForSegment(at: selectedIndex) else {
                self.selectedMode = .unknown
                return
            }
            
            for type in ActivityType.userSelectableValues {
                if type.emoji == titleOfSelectedType {
                    self.selectedMode = type
                }
            }
        }
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
        let selectedMode = self.selectedMode
        
        for (i, mode) in self.shownModes.enumerated() {
            self.insertSegment(withTitle: mode.emoji, at: i, animated: false)
        }
        
        self.insertSegment(withTitle: "…", at: self.numberOfSegments, animated: false)
    }
}
