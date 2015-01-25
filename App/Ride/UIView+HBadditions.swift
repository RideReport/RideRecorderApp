//
//  UIView+HBadditions.swift
//  Ride
//
//  Created by William Henderson on 1/15/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

extension UIView {
    
    func delay(delay: NSTimeInterval, completionHandler:() -> Void) -> Self {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
            completionHandler()
        })
        
        return self
    }
    
    func popIn(completionHandler:() -> Void = {}) -> Self {
        self.hidden = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completionHandler()
        }
        
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        scaleAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0, 1.01)
        scaleAnimation.duration = 0.8
        scaleAnimation.values = [NSValue(CATransform3D: CATransform3DMakeScale(0.3, 0.3, 1.0)),
                                NSValue(CATransform3D: CATransform3DMakeScale(1.5, 1.5, 1.0)),
                                NSValue(CATransform3D: CATransform3DIdentity)]
        self.layer.addAnimation(scaleAnimation, forKey:"scaleAnimation")
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 0.8;
        opacityAnimation.fromValue = NSNumber(float: 0.0)
        opacityAnimation.toValue =   NSNumber(float: 1.0)
        self.layer.addAnimation(opacityAnimation, forKey:"opacity")
        
        CATransaction.commit()
        
        self.layer.opacity = 1.0
        
        return self
    }
    
    func fadeIn(completionHandler: () -> Void = {}) -> Self {
        self.hidden = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completionHandler()
        }
        

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 1.0;
        opacityAnimation.fromValue = NSNumber(float: 0.0)
        opacityAnimation.toValue =   NSNumber(float: 1.0)
        self.layer.addAnimation(opacityAnimation, forKey:"opacity")
        CATransaction.commit()
        
        self.layer.opacity = 1.0
        
        return self
    }
    
    func fadeOut(completionHandler: () -> Void = {}) -> Self {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.hidden = true
            completionHandler()
        }
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 1.0;
        opacityAnimation.fromValue = NSNumber(float: 1.0)
        opacityAnimation.toValue =   NSNumber(float: 0.0)
        self.layer.addAnimation(opacityAnimation, forKey:"opacity")
        
        self.layer.opacity = 0.0
        
        CATransaction.commit()
        
        return self
    }

}