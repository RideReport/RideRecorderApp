//
//  PopupView.swift
//  Ride
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
        arrowPath.lineCapStyle = kCGLineCapButt
        
        arrowPath.lineWidth = strokeWidth
        arrowPath.stroke()
        arrowPath.fillWithBlendMode(kCGBlendModeClear, alpha:1.0)
        arrowPath.fill()
        path.fillWithBlendMode(kCGBlendModeClear, alpha:1.0)
        path.fill()
    }

}
