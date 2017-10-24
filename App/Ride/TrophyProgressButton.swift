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
import Kingfisher
import UIImageColors
import BadgeSwift

@IBDesignable public class TrophyProgressButton : UIButton {
    @IBInspectable var countLabelSize: CGFloat = 16
    @IBInspectable var emojiFontSize: CGFloat = 50
    @IBInspectable var badgeDimension: CGFloat = 78
    
    @IBInspectable var showsCount: Bool = true {
        didSet {
            reloadCountProgressUI()
        }
    }
    
    var trophyProgress: TrophyProgress? = nil {
        didSet {
            reloadCountProgressUI()
            reloadEmojiImages()
        }
    }
   
    @IBInspectable public var drawsDottedOutline = false {
        didSet {
            self.setNeedsLayout()
        }
    }

    private var emojiSaturatedCacheKey: String {
        get {
            guard let trophyProgress = self.trophyProgress else {
                return ""
            }
            
            return String(format: "%@-%.0f-%.0f", trophyProgress.emoji, self.countLabelSize, self.emojiFontSize)
        }
    }
    
    private var emojiDesaturatedCacheKey: String {
        get {
            return self.emojiSaturatedCacheKey + "-desaturated"
        }
    }
    
    private var emojiSaturated: UIImage?
    private var emojiDesaturated: UIImage?
    
    private var emojiView: UIImageView!
    private var emojiProgressView: UIImageView!
    private var badgeView: BadgeSwift!
    
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
        reloadCountProgressUI()
    }
    
    private func reloadCountProgressUI() {
        guard let trophyProgress = self.trophyProgress else {
            return
        }
        
        let progressToShow = trophyProgress.count >= 1 ? 1 : trophyProgress.progress // don't show the progress indicator if you've earned the trophy at least once
        
        let piePath = UIBezierPath()
        let centerPoint = CGPoint(x: self.badgeDimension/2, y:self.badgeDimension/2)
        piePath.move(to: centerPoint)
        piePath.addArc(withCenter: centerPoint, radius:self.badgeDimension/2 + 50, startAngle:CGFloat(-Double.pi/2), endAngle: CGFloat(-Double.pi/2 + Double.pi * 2 * progressToShow), clockwise:true)
        piePath.close()
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.bounds = emojiProgressView.layer.bounds
        maskLayer.position = emojiProgressView.center
        maskLayer.path = piePath.cgPath
        emojiProgressView.layer.mask = maskLayer
        
        badgeView.text = String(format: "%i", trophyProgress.count)
        badgeView.isHidden = (!showsCount || trophyProgress.count <= 1 || (trophyProgress.count == 1 && trophyProgress.progress > 0))
    }
    
    private func reloadEmojiUI() {
        guard let trophyProgress = self.trophyProgress else {
            return
        }
        
        guard trophyProgress.emoji != "" else {
            emojiProgressView.image = nil
            emojiView.image = nil
            badgeView.text = ""
            return
        }
        
        emojiProgressView.image = emojiSaturated
        emojiView.image = emojiDesaturated
        
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
    
    private func commonInit() {
        self.clipsToBounds = false
        self.translatesAutoresizingMaskIntoConstraints = false
        
        emojiView = UIImageView()
        emojiView.contentMode = .center
        emojiView.backgroundColor = UIColor.clear
        emojiView.clipsToBounds = false
        emojiView.alpha = 0.4
        emojiView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiView)
        
        emojiProgressView = UIImageView()
        emojiProgressView.contentMode = .center
        emojiProgressView.backgroundColor = UIColor.clear
        emojiProgressView.clipsToBounds = false
        emojiProgressView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiProgressView)
        
        badgeView = BadgeSwift()
        self.addSubview(badgeView)
        badgeView.insets = CGSize(width: 4, height: 4)
        badgeView.font = UIFont.boldSystemFont(ofSize: countLabelSize)
        badgeView.textColor = UIColor.white
        badgeView.badgeColor = ColorPallete.shared.badRed
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.shadowOpacityBadge = 0
        
        reloadCountProgressUI()
    }
    
    public override func updateConstraints() {
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        defer {
            super.updateConstraints()
            NSLayoutConstraint.activate(currentConstraints)
        }
   
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeDimension))
        
        for view in [emojiView, emojiProgressView] {
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant:0))
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant:0))
            currentConstraints.append(NSLayoutConstraint(item: view as Any, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.badgeDimension))
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:0))
        }
        
        currentConstraints.append(NSLayoutConstraint(item: emojiView, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: badgeView, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:-3))
        currentConstraints.append(NSLayoutConstraint(item: emojiView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: badgeView, attribute: NSLayoutAttribute.centerX, multiplier: 1.0, constant: 3))
    }
    
    private func reloadEmojiImages() {
        guard let _ = trophyProgress else {
            emojiSaturated = nil
            emojiDesaturated = nil
            return
        }
        
        if let cachedEmojiSatured = ImageCache.default.retrieveImageInDiskCache(forKey: self.emojiSaturatedCacheKey, options: [.scaleFactor(UIScreen.main.scale)]),
            let cachedEmojiDesatured = ImageCache.default.retrieveImageInDiskCache(forKey: self.emojiDesaturatedCacheKey, options: [.scaleFactor(UIScreen.main.scale)]) {
            self.emojiSaturated = cachedEmojiSatured
            self.emojiDesaturated = cachedEmojiDesatured
            self.reloadEmojiUI()
            return
        }
        
        // rendering the emoji can be slow, so perform in the background and then fade in
        emojiView.isHidden = true
        emojiProgressView.isHidden = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.renderEmojiImages()
            
            DispatchQueue.main.async {
                guard let reallyStrongSelf = self else {
                    return
                }
                
                reallyStrongSelf.reloadEmojiUI()
                reallyStrongSelf.emojiView.fadeIn()
                reallyStrongSelf.emojiProgressView.fadeIn()
            }
        }
    }
    
    private func renderEmojiImages() {
        guard let trophyProgress = trophyProgress else {
            return
        }
        
        let imageSize = CGSize(width: self.badgeDimension, height: self.badgeDimension)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributedEmojiString = NSAttributedString(string: trophyProgress.emoji, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: self.emojiFontSize), NSAttributedStringKey.foregroundColor: UIColor.black, NSAttributedStringKey.paragraphStyle: paragraphStyle])
        let boundingRect = attributedEmojiString.boundingRect(with: imageSize, options:[.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics], context: nil)
        
        let xOffset: CGFloat = 1 // dont know why, but emoji refuse to draw centered
        UIGraphicsBeginImageContextWithOptions(imageSize, false , 0.0)
        attributedEmojiString.draw(with: CGRect(x: (imageSize.width - boundingRect.width)/2 + xOffset, y: (imageSize.height - boundingRect.height)/2, width: boundingRect.width, height: boundingRect.height),  options:[.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics], context: nil)
        
        let emojiImageOptional = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let emojiImage = emojiImageOptional else {
            return
        }
        
        let ratio = emojiImage.size.width/emojiImage.size.height
        let downsampleDimension: CGFloat = 60
        let colors = emojiImage.getColors(scaleDownSize: CGSize(width: downsampleDimension, height: downsampleDimension/ratio))
        
        guard let saturatedGradientEmoji = gradientImage(withEmojiImage: emojiImage, color: colors.primary, secondaryColor: colors.secondary, backgroundColor: colors.background) else {
            return
        }
        
        self.emojiSaturated = saturatedGradientEmoji.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
        
        if trophyProgress.progress == 1 {
            return
        }
        
        let context = CIContext(options: nil)
        
        guard let pixellateFilter = CIFilter(name: "CIPixellate") else {
            return
        }
        pixellateFilter.setValue(CIImage(image:emojiImage), forKey: kCIInputImageKey)
        pixellateFilter.setValue(NSNumber(value: 8), forKey: kCIInputScaleKey)
        guard let pixellateOutput = pixellateFilter.outputImage, let pixellateCGImage = context.createCGImage(pixellateOutput, from:pixellateOutput.extent) else {
            return
        }
        let pixellateImage = UIImage(cgImage: pixellateCGImage, scale: UIScreen.main.scale, orientation: UIImageOrientation.up)
        
        guard let saturatedGradientPixellatedEmoji = gradientImage(withEmojiImage: pixellateImage, color: colors.primary, secondaryColor: colors.secondary, backgroundColor: colors.background) else {
            return
        }
        
        guard let desaturateFilter = CIFilter(name: "CIPhotoEffectTonal") else {
            return
        }
        desaturateFilter.setValue(CIImage(image: saturatedGradientPixellatedEmoji), forKey: kCIInputImageKey)
        guard let desaturateOutput = desaturateFilter.outputImage, let desaturateCGImage = context.createCGImage(desaturateOutput, from:desaturateOutput.extent) else {
            return
        }
        let desaturedImage = UIImage(cgImage: desaturateCGImage, scale: UIScreen.main.scale, orientation: UIImageOrientation.up)
        
        self.emojiSaturated = saturatedGradientEmoji.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
        self.emojiDesaturated = desaturedImage.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
        if let emojiSaturated = self.emojiSaturated, let emojiDesaturated = self.emojiDesaturated {
            ImageCache.default.store(emojiSaturated, forKey: self.emojiSaturatedCacheKey)
            ImageCache.default.store(emojiDesaturated, forKey: self.emojiDesaturatedCacheKey )
        }
    }
    
    private func gradientImage(withEmojiImage emojiImage: UIImage, color: UIColor, secondaryColor: UIColor, backgroundColor: UIColor)->UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: self.badgeDimension, height: self.badgeDimension), false , 0.0)
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [color.cgColor, secondaryColor.cgColor]
        gradientLayer.borderColor = backgroundColor.cgColor
        gradientLayer.borderWidth = 2.0
        gradientLayer.locations = [0.4, 1.0]
        gradientLayer.bounds = CGRect(x: 0, y: 0, width: self.badgeDimension, height: self.badgeDimension)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.cornerRadius = 8
        if let context = UIGraphicsGetCurrentContext() {
        gradientLayer.render(in: context)
        }
    
        let drawPointX = abs(self.badgeDimension - emojiImage.size.width)/2.0 * -1.0
        let drawPointY = abs(self.badgeDimension - emojiImage.size.height)/2.0 * -1.0
        emojiImage.draw(at: CGPoint(x: drawPointX, y: drawPointY))
    
        let gradientImageOptional = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return gradientImageOptional
    }
}

