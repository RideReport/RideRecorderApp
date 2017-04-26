//
//  RideSummaryView.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable class RideRewardView : UIView {
}

@IBDesignable public class RideSummaryView : UIView {
    var textColor = UIColor.black //ColorPallete.shared.darkGrey
    var marginTop : CGFloat = 8
    var marginLeft : CGFloat = 8
    
    var weatherEmojiLabel : UILabel!
    var tripBodyLabel : UILabel!
    var rewardViews : RideRewardView!
    
    private var heightConstraint : NSLayoutConstraint! = nil
    
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        weatherEmojiLabel = UILabel(frame: CGRect(x: marginTop, y: marginLeft, width: 44, height: 44))
        weatherEmojiLabel.textColor = textColor
        weatherEmojiLabel.font = UIFont.systemFont(ofSize: 40)
        self.addSubview(weatherEmojiLabel)
        
        tripBodyLabel = UILabel(frame: CGRect(x: weatherEmojiLabel.frame.maxX + marginLeft, y: marginTop, width: 0, height: 0))
        tripBodyLabel.textColor = textColor
        tripBodyLabel.font = UIFont.systemFont(ofSize: 18)
        self.addSubview(tripBodyLabel)
        reloadUI()
    }
    
    override public func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    override public  func didMoveToSuperview() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.reloadUI()
        }
    }
    
    func reloadUI() {
        weatherEmojiLabel.text = "🌦"
        tripBodyLabel.text = "1.3m to Downtown nowhere."
    
        if (self.heightConstraint != nil) {
            self.removeConstraint(self.heightConstraint)
            self.tripBodyLabel.sizeToFit()
        }
        
        let newHeight = self.tripBodyLabel.frame.height + self.tripBodyLabel.frame.origin.y + 5
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width, height: newHeight)
        
        self.heightConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: newHeight)
        self.addConstraint(self.heightConstraint)
        self.setNeedsDisplay()
    }

}
