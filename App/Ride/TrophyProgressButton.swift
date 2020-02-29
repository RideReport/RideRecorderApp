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

public protocol TrophyProgressButtonDelegate: class {
    func didFinishInitialRendering(color: UIColor?)
}

@IBDesignable public class TrophyProgressButton : UIButton {
    weak open var delegate: TrophyProgressButtonDelegate?
    
    public static var versionNumber = 1
    public static var defaultBadgeDimension: CGFloat = 78
    
    @IBInspectable var countLabelSize: CGFloat = 16
    @IBInspectable var emojiFontSize: CGFloat = 50
    @IBInspectable var badgeDimension: CGFloat = TrophyProgressButton.defaultBadgeDimension
    
    private var didCallDidFinishInitialRendering = false
    
    private var cornerRadius: CGFloat {
        get {
            let magicCornerRadiusRatio: CGFloat = 10/57 // https://hicksdesign.co.uk/journal/ios-icon-corner-radii
            return CGFloat(self.badgeDimension * magicCornerRadiusRatio)
        }
    }
    
    private var borderWidth: CGFloat {
        get {
            return self.badgeDimension/35.0
        }
    }
    
    private var rewardBorderWidth: CGFloat {
        get {
            return self.borderWidth * 1.5
        }
    }
        
    @IBInspectable var showsRewardsBorder: Bool = true {
        didSet {
            reloadCountProgressUI()
        }
    }
    
    @IBInspectable var showsCount: Bool = true {
        didSet {
            reloadCountProgressUI()
        }
    }
    
    var trophyProgress: TrophyProgress? = nil {
        didSet {
            reloadCountProgressUI()
            reloadImageViews()
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
            
            if let iconURL = trophyProgress.iconURL {
                return String(format: "%@-%.0f-%.0f-%i", iconURL.lastPathComponent, self.countLabelSize, self.emojiFontSize, TrophyProgressButton.versionNumber)
            }
            
            return String(format: "%@-%.0f-%.0f-%i", trophyProgress.emoji, self.countLabelSize, self.emojiFontSize, TrophyProgressButton.versionNumber)
        }
    }
    
    private var emojiDesaturatedCacheKey: String {
        get {
            return self.emojiSaturatedCacheKey + "-desaturated"
        }
    }
    
    private var emojiSaturated: UIImage?
    private var emojiDesaturated: UIImage?
    
    private var badgeView: BadgeSwift!
    private var emojiImageView: EmojiImageView!
    private var emojiProgressImageView: EmojiImageView!
    
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
            badgeView.isHidden = true
            return
        }
        
        let progressToShow = trophyProgress.count >= 1 ? 1 : trophyProgress.progress // don't show the progress indicator if you've earned the trophy at least once
        
        let piePath = UIBezierPath()
        let centerPoint = CGPoint(x: badgeDimension/2, y:badgeDimension/2)
        piePath.move(to: centerPoint)
        piePath.addArc(withCenter: centerPoint, radius:badgeDimension/2 + 50, startAngle:CGFloat(-Double.pi/2), endAngle: CGFloat(-Double.pi/2 + Double.pi * 2 * progressToShow), clockwise:true)
        piePath.close()
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = UIColor.black.cgColor
        maskLayer.bounds = CGRect(x: 0, y: 0, width: 0, height: 0)
        maskLayer.position = CGPoint(x: 0, y: 0)
        maskLayer.path = piePath.cgPath
        emojiImageView.layer.mask = maskLayer

        
        badgeView.text = String(format: "%i", trophyProgress.count)
        badgeView.isHidden = (!showsCount || trophyProgress.count <= 1 || (trophyProgress.count == 1 && trophyProgress.progress > 0))
    }
    
    private func reloadEmojiUI() {
        guard let trophyProgress = self.trophyProgress else {
            emojiProgressImageView.image = nil
            emojiImageView.image = nil
            badgeView.text = ""
            
            return
        }
        
        guard trophyProgress.emoji != "" else {
            emojiProgressImageView.image = nil
            emojiImageView.image = nil
            badgeView.text = ""
            return
        }
        
        if !didCallDidFinishInitialRendering, let saturatedImage = emojiImageView.image {
            didCallDidFinishInitialRendering = true
            if let delegate = self.delegate {
                delegate.didFinishInitialRendering(color: saturatedImage.getPixelColor(point: CGPoint(x:saturatedImage.size.width / 2, y: 0)))
            }
        }
        
        if (self.showsRewardsBorder && self.trophyProgress?.reward != nil) {
            if self.borderLayer == nil {
                let borderLayer = CAShapeLayer()
                borderLayer.fillColor = UIColor.clear.cgColor
                borderLayer.strokeColor = ColorPallete.shared.goodGreen.cgColor
                borderLayer.lineWidth = self.rewardBorderWidth
                borderLayer.lineJoin = CAShapeLayerLineJoin.round
                borderLayer.lineDashPattern = [8,5]
                
                self.layer.addSublayer(borderLayer)
                self.borderLayer = borderLayer
            }
            self.repostionBorderLayer()
            self.bringSubviewToFront(self.badgeView)
        } else {
            if let layer = self.borderLayer {
                layer.removeFromSuperlayer()
                self.borderLayer = nil
            }
        }
    }
    
    private func repostionBorderLayer() {
        if let layer = self.borderLayer {
            let frameSize = self.frame.size
            let borderRect = CGRect(x: 0, y: 0, width: frameSize.width - self.rewardBorderWidth/2, height: frameSize.height - self.rewardBorderWidth/2)
            
            layer.bounds = borderRect
            layer.position = CGPoint(x: frameSize.width/2, y: frameSize.height/2)
            layer.path = UIBezierPath(roundedRect: borderRect, cornerRadius: self.cornerRadius).cgPath
        }
    }
    
    override public func layoutSubviews() {
        self.repostionBorderLayer()
    }
    
    private func commonInit() {
        self.clipsToBounds = false
        self.translatesAutoresizingMaskIntoConstraints = false
        
        emojiProgressImageView = EmojiImageView(frame: CGRect.zero)
        self.addSubview(emojiProgressImageView)
        
        emojiImageView = EmojiImageView(frame: CGRect.zero)
        self.addSubview(emojiImageView)
        
        badgeView = BadgeSwift()
        self.addSubview(badgeView)
        badgeView.insets = CGSize(width: 4, height: 4)
        badgeView.font = UIFont.boldSystemFont(ofSize: countLabelSize)
        badgeView.textColor = UIColor.white
        badgeView.badgeColor = ColorPallete.shared.badRed
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.shadowOpacityBadge = 0
    }
    
    public override func updateConstraints() {
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        defer {
            super.updateConstraints()
            NSLayoutConstraint.activate(currentConstraints)
        }
        let widthConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: self.badgeDimension)
        widthConstraint.priority = .required
        currentConstraints.append(widthConstraint)
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: self.badgeDimension))
        self.setContentHuggingPriority(.defaultHigh, for: NSLayoutConstraint.Axis.horizontal)

        for view in [emojiImageView, emojiProgressImageView] {
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant:0))
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant:0))
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant:0))
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.bottom, multiplier:   1.0, constant:0))
        }
        
        currentConstraints.append(NSLayoutConstraint(item: emojiImageView, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: badgeView, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1.0, constant:-3))
        currentConstraints.append(NSLayoutConstraint(item: emojiImageView, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: badgeView, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1.0, constant: 3))
        
        
        // re-center the progress wheel
        reloadCountProgressUI()
    }
    
    private func reloadImageViews() {
        
        guard self.emojiSaturatedCacheKey.count > 0, self.emojiDesaturatedCacheKey.count > 0 else {
            self.emojiImageView.image = nil
            self.emojiProgressImageView.image = nil
            return
        }
    
        var saturatedImageData = ComputedImageData()
        saturatedImageData.imageSize = CGSize(width: self.badgeDimension, height: self.badgeDimension)
        saturatedImageData.emoji = self.trophyProgress?.emoji
        saturatedImageData.iconURL = self.trophyProgress?.iconURL
        saturatedImageData.saturated = true
        saturatedImageData.identifier = self.emojiSaturatedCacheKey
        saturatedImageData.emojiFontSize = self.emojiFontSize
        
        var desaturatedImageData = ComputedImageData()
        desaturatedImageData.imageSize = CGSize(width: self.badgeDimension, height: self.badgeDimension)
        desaturatedImageData.emoji = self.trophyProgress?.emoji
        desaturatedImageData.iconURL = self.trophyProgress?.iconURL
        desaturatedImageData.saturated = false
        desaturatedImageData.identifier = self.emojiDesaturatedCacheKey
        desaturatedImageData.emojiFontSize = self.emojiFontSize
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.emojiImageView.setImage(with: saturatedImageData, completionHandler: {
                strongSelf.reloadEmojiUI()
            })
            
            strongSelf.emojiProgressImageView.setImage(with: desaturatedImageData, completionHandler: {
                strongSelf.reloadEmojiUI()
            })
        }
    }
}

