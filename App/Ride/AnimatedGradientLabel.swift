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
    case leftToRight = 1
    case rightToLeft
}

class AnimatedGradientLabel : UILabel {
    var direction = AnimatedGradientLabelDirection.rightToLeft {
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
    
    @IBInspectable var gradientColor: UIColor = UIColor.white {
        didSet {
            self.reloadAnimations()
        }
    }
    
    var locations: [Double] = [0.0, 0.45, 0.9] {
        didSet {
            self.reloadAnimations()
        }
    }
    
    @IBInspectable var duration: TimeInterval = 4.0 {
        didSet {
            self.reloadAnimations()
        }
    }
    
    var timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn) {
        didSet {
            self.reloadAnimations()
        }
    }
    
    override var isHidden: Bool {
        didSet {
            if self.isHidden {
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
        self.textColor = UIColor.clear
        
        self.maskinglabel = UILabel(frame: self.bounds)
        
        self.maskinglabel.attributedText = self.attributedText
        self.maskinglabel.textColor = textColor
        self.mask = self.maskinglabel
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
        DispatchQueue.main.async {
            let proposedRect = CGRect(x: 0.0, y: 0.0, width: self.lengthMultiplier*self.frame.size.width, height: self.frame.size.height)
            
            if self.gradientTile1 == nil {
                self.gradientTile1 = self.gradientLayer()
                self.gradientTile1.frame = proposedRect
                self.gradientTile1.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                self.layer.addSublayer(self.gradientTile1)
            }
            
            if self.gradientTile2 == nil {
                self.gradientTile2 = self.gradientLayer()
                self.gradientTile2.frame = proposedRect
                self.gradientTile2.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                self.layer.addSublayer(self.gradientTile2)
            }
            
            self.gradientTile1.removeAnimation(forKey: "position")
            self.gradientTile2.removeAnimation(forKey: "position")
            
            if self.isAnimating {
                let animation = CABasicAnimation(keyPath: "position")
                animation.timingFunction = self.timingFunction
                animation.duration = self.duration*2
                animation.isRemovedOnCompletion = false
                animation.repeatCount = Float.infinity
                
                if (self.direction == .leftToRight) {
                    animation.fromValue = NSValue(cgPoint:CGPoint(x: -0.5 * proposedRect.size.width, y: proposedRect.midY))
                    animation.toValue = NSValue(cgPoint:CGPoint(x: 1.5 * proposedRect.size.width, y: proposedRect.midY))
                } else {
                    animation.fromValue = NSValue(cgPoint:CGPoint(x: 1.5 * proposedRect.size.width, y: proposedRect.midY))
                    animation.toValue = NSValue(cgPoint:CGPoint(x: -0.5 * proposedRect.size.width, y: proposedRect.midY))
                }
                self.gradientTile1.add(animation, forKey: "position")
                
                animation.timeOffset = self.duration // the animation is copied in on addAnimation, so it is OK to re-use it
                self.gradientTile2.add(animation, forKey: "position")
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
        layer.colors = [UIColor.clear.cgColor, self.gradientColor.cgColor, UIColor.clear.cgColor]
        layer.locations = self.locations as [NSNumber]?
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        
        return layer
    }
}
