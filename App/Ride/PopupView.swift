//
//  PopupView.swift
//  Ride Report
//
//  Created by William Henderson on 1/15/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@IBDesignable class PopupView : UIView {
    
    @IBInspectable var strokeWidth: CGFloat = 2
    @IBInspectable var arrowHeight: CGFloat = 10
    @IBInspectable var arrowBaseWidth: CGFloat = 10
    @IBInspectable var cornerRadius: CGFloat = 10
    @IBInspectable var arrowInset: CGFloat = 10
    @IBInspectable var strokeColor: UIColor = UIColor.darkGrayColor()
    @IBInspectable var fillColor: UIColor = UIColor.whiteColor()
    @IBInspectable var text: String = "Popupview Text" {
        didSet {
            self.reloadView()
        }
    }
    
    private var textLabel : UILabel! = nil
    private var widthConstraint : NSLayoutConstraint! = nil
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        self.textLabel = UILabel(frame: CGRectMake(7, 20, self.frame.size.width, self.frame.size.height - 20))
        self.textLabel.font = UIFont.systemFontOfSize(14)
        self.textLabel.textColor = UIColor.whiteColor()
        self.textLabel.numberOfLines = 1
        self.textLabel.lineBreakMode = NSLineBreakMode.ByTruncatingTail
        self.textLabel.adjustsFontSizeToFitWidth = true
        self.textLabel.minimumScaleFactor = 0.4
        self.reloadView()
        self.addSubview(self.textLabel)
    }
    
    private func reloadView() {
        let rightHandBefore = self.frame.origin.x + self.frame.width
        self.textLabel.text = self.text
        self.textLabel.sizeToFit()
        if (self.superview != nil && self.textLabel.frame.width > (self.superview!.frame.width - 30)) {
            self.textLabel.frame.size.width = self.textLabel.frame.width - 30
        }
        let newWidth = self.textLabel.frame.width + 20
        self.frame = CGRectMake(rightHandBefore - newWidth, self.frame.origin.y, newWidth, self.frame.height)
        
        if (self.widthConstraint != nil) {
            self.removeConstraint(self.widthConstraint)
        }
        self.widthConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1.0, constant: newWidth)
        self.addConstraint(self.widthConstraint)
        self.setNeedsDisplay()
    }
    
    override func didMoveToSuperview() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.reloadView()
        }
    }
    
    override func drawRect(rect: CGRect) {
        let smallerPath = CGRectMake(rect.origin.x + strokeWidth, arrowHeight + strokeWidth, rect.size.width - 2*strokeWidth, rect.size.height - arrowHeight - 2*strokeWidth)
        
        let path = UIBezierPath(roundedRect: smallerPath, cornerRadius: cornerRadius)
        
        fillColor.setFill()
        strokeColor.setStroke()
        
        path.lineWidth = strokeWidth
        path.stroke()
        
        let arrowPoint = CGPointMake(rect.size.width - arrowBaseWidth - arrowInset, arrowHeight + strokeWidth)
        let arrowPath = UIBezierPath()
        
        let halfArrowWidth = arrowBaseWidth / 2.0
        let tipPt = CGPointMake(arrowPoint.x + halfArrowWidth, strokeWidth)
        let endPt = CGPointMake(arrowPoint.x + arrowBaseWidth, arrowPoint.y)
        
        // Note: we always build the arrow path in a clockwise direction.
        // Arrow points towards top. We're starting from the left.
        
        arrowPath.moveToPoint(arrowPoint)
        arrowPath.addLineToPoint(tipPt)
        arrowPath.addLineToPoint(endPt)
        arrowPath.lineCapStyle = CGLineCap.Butt
        
        arrowPath.lineWidth = strokeWidth
        arrowPath.stroke()
        arrowPath.fillWithBlendMode(CGBlendMode.Clear, alpha:1.0)
        arrowPath.fill()
        path.fillWithBlendMode(CGBlendMode.Clear, alpha:1.0)
        path.fill()
    }

}
