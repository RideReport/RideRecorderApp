//
//  UIView+HBadditions.swift
//  HoneyBee
//
//  Created by William Henderson on 1/15/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

extension UIView {
    
    func popIn() {
        self.hidden = false
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform")
        scaleAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0, 1.01)
        scaleAnimation.duration = 0.3
        scaleAnimation.fromValue = NSValue(CATransform3D: CATransform3DMakeScale(0.3, 0.3, 1.0))
        scaleAnimation.toValue = NSValue(CATransform3D: CATransform3DIdentity)
        self.layer.addAnimation(scaleAnimation, forKey:"scaleAnimation")
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 0.3;
        opacityAnimation.fromValue = NSNumber(float: 0.0)
        opacityAnimation.toValue =   NSNumber(float: 1.0)
        self.layer.addAnimation(opacityAnimation, forKey:"opacity")
        
        self.layer.opacity = 1.0
    }
    
    func fadeOut() {
        CATransaction.begin()
        CATransaction.setCompletionBlock { () -> Void in
            self.hidden = true
        }
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 1.0;
        opacityAnimation.fromValue = NSNumber(float: 1.0)
        opacityAnimation.toValue =   NSNumber(float: 0.0)
        self.layer.addAnimation(opacityAnimation, forKey:"opacity")
        
        self.layer.opacity = 0.0
        
        CATransaction.commit()
    }

}