//
//  TrophyProgressView.swift
//  Ride Report
//
//  Created by William Henderson on 10/11/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

@IBDesignable public class TrophyProgressView : UIView {
    public var associatedObject: Any?
    
    private var hasLayedOutSubviews = false
    
    let countLabelSize: CGFloat = 16
    var badgeSize: CGFloat {
        get {
            return countLabelSize + 8
        }
    }
    
    @IBInspectable var emojiFontSize: CGFloat = 70  {
        didSet {
            reloadEmojiUI()
        }
    }
    
    @IBInspectable var emoji: String = "" {
        didSet {
            reloadEmojiImages()
            reloadEmojiUI()
        }
    }
    
    @IBInspectable var count: Int = 0 {
        didSet {
            reloadEmojiUI()
        }
    }
    
    @IBInspectable var progress: CGFloat = 0 {
        didSet {
            reloadProgressUI()
        }
    }
    
    @IBInspectable public var drawsDottedOutline = false {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    private var emojiSaturated: UIImage?
    private var emojiDesaturated: UIImage?
    
    private var emojiView: UIImageView!
    private var emojiProgressView: UIImageView!
    private var countLabel: UILabel!
    private var circleView: UIView!
    
    private var currentConstraints: [NSLayoutConstraint]! = []
    private var borderLayer: CAShapeLayer?
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInit()
    }
    
    public override func prepareForInterfaceBuilder() {
        reloadEmojiUI()
        reloadProgressUI()
    }
    
    func reloadProgressUI() {
        guard hasLayedOutSubviews else {
            return
        }
        
        let imageWidth = self.emojiFontSize + 8
        let piePath = UIBezierPath()
        let centerPoint = CGPoint(x: imageWidth/2, y:imageWidth/2)
        piePath.move(to: centerPoint)
        piePath.addArc(withCenter: centerPoint, radius:imageWidth/2 + 50, startAngle:CGFloat(-Double.pi/2), endAngle: CGFloat(Double.pi * 2) * progress, clockwise:true)
        piePath.close()
        NSLog("%@", piePath)
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.bounds = emojiProgressView.layer.bounds
        maskLayer.path = piePath.cgPath
        emojiProgressView.layer.mask = maskLayer
    }
    
    func reloadEmojiUI() {
        guard hasLayedOutSubviews else {
            return
        }
        
        guard emoji != "" else {
            emojiProgressView.image = nil
            emojiView.image = nil
            countLabel.text = ""
            return
        }
        
        emojiProgressView.image = emojiSaturated
        emojiView.image = emojiDesaturated
        countLabel.text = String(format: "%i", count)
        countLabel.isHidden = count <= 0
        circleView.isHidden = count <= 0
        
        if (drawsDottedOutline) {
            self.backgroundColor = ColorPallete.shared.almostWhite
            let borderWidth: CGFloat = 2
            
            if self.borderLayer == nil {
                let borderLayer = CAShapeLayer()
                borderLayer.fillColor = UIColor.clear.cgColor
                borderLayer.strokeColor = ColorPallete.shared.goodGreen.cgColor
                borderLayer.lineWidth = borderWidth
                borderLayer.lineJoin = kCALineJoinRound
                borderLayer.lineDashPattern = [6,3]
                
                self.layer.addSublayer(borderLayer)
                self.borderLayer = borderLayer
            }
            if let layer = self.borderLayer {
                let frameSize = self.frame.size
                let borderRect = CGRect(x: 0, y: 0, width: frameSize.width + 4, height: frameSize.height + 4)
                
                layer.bounds = borderRect
                layer.position = CGPoint(x: frameSize.width/2, y: frameSize.height/2)
                layer.path = UIBezierPath(roundedRect: borderRect, cornerRadius: 5).cgPath
            }
        } else {
            self.backgroundColor = UIColor.clear
            
            if let layer = self.borderLayer {
                layer.removeFromSuperlayer()
                self.borderLayer = nil
            }
        }
    }
    
    override public func layoutSubviews() {
        self.hasLayedOutSubviews = true
        reloadEmojiUI()
        reloadProgressUI()
    }
    
    func commonInit() {
        self.clipsToBounds = false
        self.translatesAutoresizingMaskIntoConstraints = false
        
        emojiView = UIImageView()
        emojiView.contentMode = .center
        emojiView.backgroundColor = UIColor.clear
        emojiView.clipsToBounds = false
        emojiView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiView)
        
        emojiProgressView = UIImageView()
        emojiProgressView.contentMode = .center
        emojiProgressView.backgroundColor = UIColor.clear
        emojiProgressView.clipsToBounds = false
        emojiProgressView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiProgressView)
        
        circleView = UIView(frame: CGRect(x: 0, y: 0, width: badgeSize, height: badgeSize))
        self.addSubview(circleView)
        let borderFrame = CGRect(x: 0, y: 0, width: badgeSize, height: badgeSize)
        let circleLayer = CAShapeLayer()
        circleLayer.fillColor = ColorPallete.shared.badRed.cgColor
        circleLayer.contentsScale = UIScreen.main.scale
        circleLayer.bounds = borderFrame
        circleLayer.position = circleView.layer.position
        circleLayer.path = UIBezierPath(ovalIn: borderFrame).cgPath
        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.layer.addSublayer(circleLayer)
        
        countLabel = UILabel()
        countLabel.textColor = UIColor.white
        countLabel.textAlignment = .center
        countLabel.font = UIFont.boldSystemFont(ofSize: countLabelSize)
        countLabel.minimumScaleFactor = 0.4
        countLabel.backgroundColor = UIColor.clear
        countLabel.lineBreakMode = .byWordWrapping
        countLabel.numberOfLines = 0
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        circleView.addSubview(countLabel)
        
        reloadEmojiUI()
        reloadProgressUI()
    }
    
    public override func updateConstraints() {
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        defer {
            super.updateConstraints()
            NSLayoutConstraint.activate(currentConstraints)
        }
   
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.emojiFontSize + 10))
        
        for view in [emojiView, emojiProgressView] {
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant:0))
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant:0))
            currentConstraints.append(NSLayoutConstraint(item: view, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.emojiFontSize))
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:0))
        }
        
        currentConstraints.append(NSLayoutConstraint(item: emojiView, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: circleView, attribute: NSLayoutAttribute.top, multiplier: 1.0, constant:self.badgeSize/2))
        currentConstraints.append(NSLayoutConstraint(item: emojiView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: circleView, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant:-self.badgeSize/2))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        
        currentConstraints.append(NSLayoutConstraint(item: countLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        currentConstraints.append(NSLayoutConstraint(item: countLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: countLabel, attribute: NSLayoutAttribute.centerX, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: countLabel, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:0))
    }
    
    private func reloadEmojiImages() {
        guard emoji != "" else {
            emojiSaturated = nil
            emojiDesaturated = nil
            return
        }
        
        let emojiOffset: CGFloat = 4
        let imageWidth = self.emojiFontSize + emojiOffset * 2
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributedEmojiString = NSAttributedString(string: self.emoji, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: self.emojiFontSize), NSAttributedStringKey.foregroundColor: UIColor.black, NSAttributedStringKey.paragraphStyle: paragraphStyle])
        
        let emojiSize = attributedEmojiString.boundingRect(with: CGSize(width: self.emojiFontSize, height: CGFloat.greatestFiniteMagnitude), options:[NSStringDrawingOptions.usesLineFragmentOrigin, NSStringDrawingOptions.usesFontLeading], context:nil).size
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageWidth, height: imageWidth), false , 0.0)
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [ColorPallete.shared.goodGreen.cgColor, ColorPallete.shared.primaryDark.cgColor]
        gradientLayer.locations = [0.6, 1.0]
        gradientLayer.bounds = CGRect(x: 0, y: 0, width: imageWidth, height: imageWidth)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.cornerRadius = 8
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        
        let emojiDrawRect = CGRect(x: 0, y: -emojiOffset, width: emojiSize.width, height: emojiSize.height)
        attributedEmojiString.draw(in: emojiDrawRect)
        
        let saturatedImageOptional = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let saturatedImage = saturatedImageOptional else {
            self.emojiSaturated = nil
            self.emojiDesaturated = nil
            return
        }
        
        let context = CIContext(options: nil)
        let currentFilter = CIFilter(name: "CIPhotoEffectTonal")
        currentFilter!.setValue(CIImage(image: saturatedImage), forKey: kCIInputImageKey)
        let output = currentFilter!.outputImage
        
        let cgImage = context.createCGImage(output!,from:output!.extent)
        let desaturedImage = UIImage(cgImage: cgImage!, scale: UIScreen.main.scale, orientation: UIImageOrientation.up)
        
        self.emojiSaturated = saturatedImage.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
        self.emojiDesaturated = desaturedImage.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
    }
}

