//
//  ClearButton.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@IBDesignable class ClearButton : UIButton {
    var effectsView : UIView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        effectsView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.ExtraLight))
        let clearButtonRect = CGRectMake(0, 0, 18, 18)
        UIGraphicsBeginImageContextWithOptions(clearButtonRect.size, false, 0.0)
        let circle = UIBezierPath(ovalInRect: clearButtonRect)
        let line1 = UIBezierPath()
        line1.moveToPoint(CGPointMake(6, 6))
        line1.addLineToPoint(CGPointMake(12, 12))
        line1.lineWidth = 1
        let line2 = UIBezierPath()
        line2.moveToPoint(CGPointMake(6, 12))
        line2.addLineToPoint(CGPointMake(12, 6))
        line2.lineWidth = 1
        
        UIColor.blackColor().setFill()
        circle.fill()
        let ctx = UIGraphicsGetCurrentContext()
        CGContextSetBlendMode(ctx!, CGBlendMode.DestinationOut)
        line1.stroke()
        line2.stroke()
        let maskImage = UIGraphicsGetImageFromCurrentImageContext()!.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal)
        UIGraphicsEndImageContext()
        let maskLayer = CALayer()
        maskLayer.contentsScale = maskImage.scale
        maskLayer.frame = clearButtonRect
        maskLayer.contents = maskImage.CGImage
        effectsView.frame = clearButtonRect
        effectsView.layer.mask = maskLayer
        
        self.addSubview(effectsView)
    }
    
    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        if !self.hidden {
            return self
        }
        
        return super.hitTest(point, withEvent: event)
    }
    
}
