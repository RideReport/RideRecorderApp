//
//  UIView+HBadditions.swift
//  Ride Report
//
//  Created by William Henderson on 1/15/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UIKit

enum AnimationDirection {
    case left
    case right
    case up
    case down
}

extension UIView {
    
    @discardableResult func delay(_ delay: TimeInterval, completionHandler:@escaping () -> Void) -> Self {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            completionHandler()
        })
        
        return self
    }
    
    @discardableResult  func shake(_ completionHandler:@escaping () -> Void = {}) -> Self {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completionHandler()
        }
        
        
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        
        let bounceOffsets : [CGFloat] = [-13.0, 13.0, -10.0, 7.0, -5.0, 3.0, -2.0, 1.0, 0.0]
        
        shakeAnimation.values = bounceOffsets
        shakeAnimation.duration = 0.5
        shakeAnimation.keyTimes = [0, 0.1, 0.2, 0.35, 0.5, 0.75, 0.9, 1.0]
  
        self.layer.add(shakeAnimation, forKey:"transform.translation.x")
        
        CATransaction.commit()
        
        return self
    }
    
    @discardableResult func popIn(_ duration: TimeInterval = 0.8, completionHandler:@escaping () -> Void = {}) -> Self {
        self.isHidden = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            if self.layer.opacity == 1.0 {
                self.isHidden = false
            }
            completionHandler()
        }
        
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        scaleAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0, 1.01)
        scaleAnimation.duration = duration
        scaleAnimation.values = [NSValue(caTransform3D: CATransform3DMakeScale(0.3, 0.3, 1.0)),
                                NSValue(caTransform3D: CATransform3DMakeScale(1.5, 1.5, 1.0)),
                                NSValue(caTransform3D: CATransform3DIdentity)]
        self.layer.add(scaleAnimation, forKey:"scaleAnimation")
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = duration;
        opacityAnimation.fromValue = NSNumber(value: 0.0 as Float)
        opacityAnimation.toValue =   NSNumber(value: 1.0 as Float)
        self.layer.add(opacityAnimation, forKey:"opacity")
        
        CATransaction.commit()
        
        self.layer.opacity = 1.0
        
        return self
    }
    
    @discardableResult func sparkle(_ baseColor: UIColor, inRect rect: CGRect, completionHandler: @escaping () -> Void = {}) -> Self {
        let lifetime : TimeInterval = 1.0
        
        let emitterMaker = { (color: UIColor) -> CAEmitterCell in
            let cell = CAEmitterCell()
            cell.birthRate = 150
            cell.scale = 0.7 / UIScreen.main.scale
            cell.velocity = 40
            cell.lifetime = Float(lifetime)
            cell.lifetimeRange = 0.3
            cell.alphaRange = 0.8
            cell.alphaSpeed = -0.7
            cell.beginTime = 0
            cell.emissionRange = CGFloat(2.0 * CGFloat.pi)
            cell.scaleSpeed = -0.1
            cell.spin = 2

            cell.color = color.cgColor
            cell.greenRange = 0.2
            cell.greenSpeed = 0.1
            cell.contents = UIImage(named: "tspark.png")?.cgImage
            
            return cell
        }
        
        let particleEmitter = CAEmitterLayer()
        particleEmitter.renderMode = kCAEmitterLayerAdditive
        
        particleEmitter.emitterPosition = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
        particleEmitter.emitterShape = kCAEmitterLayerRectangle
        particleEmitter.emitterSize = CGSize(width: rect.size.width, height: rect.size.height/2)
        particleEmitter.emitterCells = [emitterMaker(baseColor)]
        
        self.layer.addSublayer(particleEmitter)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completionHandler()
            particleEmitter.birthRate = 0
            self.delay(lifetime) {
                particleEmitter.removeFromSuperlayer()
            }
        }
        
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 0.2;
        opacityAnimation.fromValue = NSNumber(value: 1.0 as Float)
        opacityAnimation.toValue =   NSNumber(value: 1.0 as Float)
        self.layer.add(opacityAnimation, forKey:"opacity")

        CATransaction.commit()
        
        return self
    }
    
    @discardableResult func fadeIn(_ completionHandler: @escaping () -> Void = {}) -> Self {
        self.isHidden = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            if self.layer.opacity == 1.0 {
                self.isHidden = false
            }
            completionHandler()
        }
        

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 1.0;
        opacityAnimation.fromValue = NSNumber(value: 0.0 as Float)
        opacityAnimation.toValue =   NSNumber(value: 1.0 as Float)
        self.layer.add(opacityAnimation, forKey:"opacity")
        CATransaction.commit()
        
        self.layer.opacity = 1.0
        
        return self
    }
    
    @discardableResult func fadeOut(_ completionHandler: @escaping () -> Void = {}) -> Self {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            if self.layer.opacity == 0.0 {
                self.isHidden = true
            }
            completionHandler()
        }
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = 1.0;
        opacityAnimation.fromValue = NSNumber(value: 1.0 as Float)
        opacityAnimation.toValue =   NSNumber(value: 0.0 as Float)
        self.layer.add(opacityAnimation, forKey:"opacity")
        
        self.layer.opacity = 0.0
        
        CATransaction.commit()
        
        return self
    }

}
