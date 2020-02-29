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
    
    private var style: UIBlurEffect.Style = UIBlurEffect.Style.extraLight
    @IBInspectable var effectsStyle: NSInteger = UIBlurEffect.Style.extraLight.rawValue {
        didSet {
            if let newStyle = UIBlurEffect.Style(rawValue: self.effectsStyle) {
                self.style = newStyle
                reloadUI()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        reloadUI()
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        reloadUI()
    }
    
    func reloadUI() {
        if let oldView = effectsView {
            oldView.removeFromSuperview()
        }
        
        let rect = CGRect(x: 0, y: 0, width: 18, height: 18)
        effectsView = UIVisualEffectView(effect: UIBlurEffect(style: style))
        effectsView.frame = rect
        let clearButtonRect = rect
        UIGraphicsBeginImageContextWithOptions(clearButtonRect.size, false, 0.0)
        let circle = UIBezierPath(ovalIn: clearButtonRect)
        let line1 = UIBezierPath()
        line1.move(to: CGPoint(x: 6, y: 6))
        line1.addLine(to: CGPoint(x: 12, y: 12))
        line1.lineWidth = 1
        let line2 = UIBezierPath()
        line2.move(to: CGPoint(x: 6, y: 12))
        line2.addLine(to: CGPoint(x: 12, y: 6))
        line2.lineWidth = 1
        
        UIColor.black.setFill()
        circle.fill()
        let ctx = UIGraphicsGetCurrentContext()
        ctx!.setBlendMode(CGBlendMode.destinationOut)
        line1.stroke()
        line2.stroke()
        let maskImage = UIGraphicsGetImageFromCurrentImageContext()!.withRenderingMode(UIImage.RenderingMode.alwaysOriginal)
        UIGraphicsEndImageContext()
        let maskLayer = CALayer()
        maskLayer.contentsScale = maskImage.scale
        maskLayer.frame = clearButtonRect
        maskLayer.contents = maskImage.cgImage
        effectsView.frame = clearButtonRect
        effectsView.layer.mask = maskLayer
        
        self.addSubview(effectsView)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isHidden && self.frame.insetBy(dx: -10, dy: -10).contains(point) {
            // enlarge the hit target a bit.
            return self
        }
        
        return super.hitTest(point, with: event)
    }
    
}
