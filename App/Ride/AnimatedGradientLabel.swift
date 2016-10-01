//
//  AnimatedGradientLabel.swift
//  Ride
//
//  Created by William Henderson on 4/19/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UIKit

enum AnimatedGradientLabelDirection: NSInteger {
    case LeftToRight = 1
    case RightToLeft
}

class AnimatedGradientLabel : UILabel {
    var direction = AnimatedGradientLabelDirection.RightToLeft {
        didSet {
            self.reloadAnimations()
        }
    }
    
    @IBInspectable var interfaceDirection: NSInteger = 1 {
        didSet {
            if let newDirection = AnimatedGradientLabelDirection(rawValue: self.interfaceDirection) {
                self.direction = newDirection
            }
        }
    }
    
    @IBInspectable var gradientColor: UIColor = UIColor.whiteColor() {
        didSet {
            self.reloadAnimations()
        }
    }
    
    var locations: [Double] = [0.0, 0.45, 0.9] {
        didSet {
            self.reloadAnimations()
        }
    }
    
    @IBInspectable var duration: NSTimeInterval = 4.0 {
        didSet {
            self.reloadAnimations()
        }
    }
    
    var timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn) {
        didSet {
            self.reloadAnimations()
        }
    }
    
    override var hidden: Bool {
        didSet {
            if self.hidden {
                self.stopAnimating()
            } else {
                self.animate()
            }
        }
    }
    
    override var text: String? {
        didSet {
            self.maskinglabel.text = self.text
            self.reloadAnimations()
        }
    }
    
    override var attributedText: NSAttributedString? {
        didSet {
            self.maskinglabel.attributedText = self.attributedText
        }
    }
    
    private var isAnimating = false
    private var maskinglabel: UILabel!
    private var gradientTile1: CALayer!
    private var gradientTile2: CALayer!
    private let lengthMultiplier: CGFloat = 2
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        self.reloadAnimations()
        
        let textColor = self.textColor
        self.backgroundColor = textColor
        self.textColor = UIColor.clearColor()
        
        self.maskinglabel = UILabel(frame: self.bounds)
        
        self.maskinglabel.attributedText = self.attributedText
        self.maskinglabel.textColor = textColor
        self.maskView = self.maskinglabel
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.maskinglabel.frame = self.bounds
    }
    
    override func didMoveToWindow() {
        if let _ = self.window {
            self.animate()
        } else {
            self.stopAnimating()
        }
    }
    
    func reloadAnimations() {
        dispatch_async(dispatch_get_main_queue()) {
            let proposedRect = CGRectMake(0.0, 0.0, self.lengthMultiplier*self.frame.size.width, self.frame.size.height)
            
            if self.gradientTile1 == nil {
                self.gradientTile1 = self.gradientLayer()
                self.gradientTile1.frame = proposedRect
                self.gradientTile1.anchorPoint = CGPointMake(0.5, 0.5)
                self.layer.addSublayer(self.gradientTile1)
            }
            
            if self.gradientTile2 == nil {
                self.gradientTile2 = self.gradientLayer()
                self.gradientTile2.frame = proposedRect
                self.gradientTile2.anchorPoint = CGPointMake(0.5, 0.5)
                self.layer.addSublayer(self.gradientTile2)
            }
            
            self.gradientTile1.removeAnimationForKey("position")
            self.gradientTile2.removeAnimationForKey("position")
            
            if self.isAnimating {
                let animation = CABasicAnimation(keyPath: "position")
                animation.timingFunction = self.timingFunction
                animation.duration = self.duration*2
                animation.removedOnCompletion = false
                animation.repeatCount = Float.infinity
                
                if (self.direction == .LeftToRight) {
                    animation.fromValue = NSValue(CGPoint:CGPointMake(-0.5 * proposedRect.size.width, CGRectGetMidY(proposedRect)))
                    animation.toValue = NSValue(CGPoint:CGPointMake(1.5 * proposedRect.size.width, CGRectGetMidY(proposedRect)))
                } else {
                    animation.fromValue = NSValue(CGPoint:CGPointMake(1.5 * proposedRect.size.width, CGRectGetMidY(proposedRect)))
                    animation.toValue = NSValue(CGPoint:CGPointMake(-0.5 * proposedRect.size.width, CGRectGetMidY(proposedRect)))
                }
                self.gradientTile1.addAnimation(animation, forKey: "position")
                
                animation.timeOffset = self.duration // the animation is copied in on addAnimation, so it is OK to re-use it
                self.gradientTile2.addAnimation(animation, forKey: "position")
            }
        }
    }

    func animate() {
        self.isAnimating = true
        self.reloadAnimations()
    }
    
    func stopAnimating() {
        self.isAnimating = false
        self.reloadAnimations()
    }
    
    private func gradientLayer()->CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = [UIColor.clearColor().CGColor, self.gradientColor.CGColor, UIColor.clearColor().CGColor]
        layer.locations = self.locations
        layer.startPoint = CGPointMake(0, 0.5)
        layer.endPoint = CGPointMake(1, 0.5)
        
        return layer
    }
}
