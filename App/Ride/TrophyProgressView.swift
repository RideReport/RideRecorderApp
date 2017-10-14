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
    
    let countLabelSize: CGFloat = 16
    var badgeSize: CGFloat {
        get {
            return countLabelSize + 8
        }
    }
    
    @IBInspectable var emojiFontSize: CGFloat = 80  {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var emoji: String = "" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var count: Int = 0 {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var progress: CGFloat = 0 {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable public var drawsDottedOutline = false {
        didSet {
            self.setNeedsLayout()
        }
    }
    
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
        reloadUI()
    }
    
    func reloadUI() {
        let (saturated, desatured) = emojiImage()
        emojiProgressView.image = saturated
        emojiView.image = desatured
        countLabel.text = String(format: "%i", count)
        
        let imageWidth = self.emojiFontSize + 8
        let piePath = UIBezierPath()
        let centerPoint = CGPoint(x: imageWidth/2, y:imageWidth/2)
        piePath.move(to: centerPoint)
        piePath.addArc(withCenter: center, radius:imageWidth/2 + 10, startAngle:CGFloat(Double.pi/2), endAngle: CGFloat(0), clockwise:true)
        piePath.close()
        
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.bounds = emojiProgressView.layer.bounds
        maskLayer.position = emojiProgressView.layer.position
        maskLayer.path = piePath.cgPath
        emojiProgressView.layer.mask = maskLayer
        
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
        reloadUI()
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
        circleLayer.lineWidth = 3
        circleLayer.strokeColor = ColorPallete.shared.almostWhite.cgColor
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
        
        reloadUI()
    }
    
    public override func updateConstraints() {
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        defer {
            super.updateConstraints()
            NSLayoutConstraint.activate(currentConstraints)
        }
   
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.emojiFontSize + 10))
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: emojiView, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: emojiView, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: emojiView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.emojiFontSize))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: emojiView, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:0))
        
        currentConstraints.append(NSLayoutConstraint(item: emojiView, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: circleView, attribute: NSLayoutAttribute.top, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: emojiView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: circleView, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        
        currentConstraints.append(NSLayoutConstraint(item: countLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        currentConstraints.append(NSLayoutConstraint(item: countLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeSize))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: countLabel, attribute: NSLayoutAttribute.centerX, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: circleView, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: countLabel, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:0))
    }
    
    private func emojiImage() -> (UIImage?,UIImage?) {
        let emojiOffset: CGFloat = 4
        let imageWidth = self.emojiFontSize + emojiOffset * 2
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributedEmojiString = NSAttributedString(string: self.emoji, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: self.emojiFontSize), NSAttributedStringKey.foregroundColor: UIColor.black, NSAttributedStringKey.paragraphStyle: paragraphStyle])
        
        let emojiSize = attributedEmojiString.boundingRect(with: CGSize(width: self.emojiFontSize, height: CGFloat.greatestFiniteMagnitude), options:[NSStringDrawingOptions.usesLineFragmentOrigin, NSStringDrawingOptions.usesFontLeading], context:nil).size
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageWidth, height: imageWidth), false , 0.0)
        let emojiDrawRect = CGRect(x: emojiOffset, y: 0, width: emojiSize.width, height: emojiSize.height)
        
        attributedEmojiString.draw(in: emojiDrawRect)
        
        let saturatedImageOptional = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let saturatedImage = saturatedImageOptional else {
            return (nil, nil)
        }
        
        let context = CIContext(options: nil)
        let currentFilter = CIFilter(name: "CIPhotoEffectTonal")
        currentFilter!.setValue(CIImage(image: saturatedImage), forKey: kCIInputImageKey)
        let output = currentFilter!.outputImage
        
        let cgImage = context.createCGImage(output!,from:output!.extent)
        let desaturedImage = UIImage(cgImage: cgImage!, scale: UIScreen.main.scale, orientation: UIImageOrientation.up)
        
        return (saturatedImage.withRenderingMode(UIImageRenderingMode.alwaysOriginal), desaturedImage.withRenderingMode(UIImageRenderingMode.alwaysOriginal))
    }
}

