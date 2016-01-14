//
//  UIView+HBadditions.swift
//  Ride Report
//
//  Created by William Henderson on 1/15/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

enum AnimationDirection {
    case Left
    case Right
    case Up
    case Down
}

extension UIView {
    
    func delay(delay: NSTimeInterval, completionHandler:() -> Void) -> Self {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
            completionHandler()
        })
        
        return self
    }
    
    func shake(completionHandler:() -> Void = {}) -> Self {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completionHandler()
        }
        
        
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        
        let bounceOffsets : [CGFloat] = [-13.0, 13.0, -10.0, 7.0, -5.0, 3.0, -2.0, 1.0, 0.0]
        
        shakeAnimation.values = bounceOffsets
        shakeAnimation.duration = 0.5
        shakeAnimation.keyTimes = [0, 0.1, 0.2, 0.35, 0.5, 0.75, 0.9, 1.0]
  
        self.layer.addAnimation(shakeAnimation, forKey:"transform.translation.x")
        
        CATransaction.commit()
        
        return self
    }
    
    func popIn(completionHandler:() -> Void = {}) -> Self {
        self.hidden = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            if self.layer.opacity == 1.0 {
                self.hidden = false
            }
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
            if self.layer.opacity == 1.0 {
                self.hidden = false
            }
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
            if self.layer.opacity == 0.0 {
                self.hidden = true
            }
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