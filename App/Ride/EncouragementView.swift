//
//  EncouragementView.swift
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

@IBDesignable public class EncouragementView : UIButton {
    private let minimumColorValue: CGFloat = 0.84
    public static var versionNumber = 1
    
    var emojiImageSize: CGFloat = 80
    
    var title: String? = "" {
        didSet {
            self.encouragementTitleLabel.text = title
        }
    }
    
    var subtitle: String? = ""
    var trophyProgress: TrophyProgress? = nil {
        didSet {
            self.reloadEmojiImagesAndThenGradientBackgroundAndLabelColors()
        }
    }
   
    @IBInspectable public var drawsDottedOutline = false {
        didSet {
            self.setNeedsLayout()
        }
    }

    private var emojiCacheKey: String {
        get {
            guard let trophyProgress = self.trophyProgress else {
                return ""
            }
            
            return String(format: "%@-%.0f-%.0f-%i", trophyProgress.emoji, self.frame.width, self.frame.height, EncouragementView.versionNumber)
        }
    }
    
    private var emojiImage: UIImage?
    
    private var emojiView: UIImageView!
    private var backgroundImageView: UIImageView!
    
    private var gradientLayer: CAGradientLayer?
    
    private var encouragementTitleLabel: UILabel!
    private var subtitleLabel: UILabel!
    
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
    
    private func reloadEmojiUI() {
        guard let trophyProgress = self.trophyProgress else {
            emojiView.image = nil
            backgroundImageView.image = nil
            
            return
        }
        
        guard trophyProgress.emoji != "" else {
            emojiView.image = nil
            backgroundImageView.image = nil
            encouragementTitleLabel.text = ""
            subtitleLabel.text = ""
            return
        }
        
        emojiView.image = emojiImage
        
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
        
        backgroundImageView = UIImageView()
        backgroundImageView.contentMode = .center
        backgroundImageView.backgroundColor = UIColor.clear
        backgroundImageView.clipsToBounds = false
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(backgroundImageView)
        
        emojiView = UIImageView()
        emojiView.contentMode = .center
        emojiView.backgroundColor = UIColor.clear
        emojiView.clipsToBounds = false
        emojiView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiView)
        
        encouragementTitleLabel = UILabel()
        encouragementTitleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        encouragementTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        encouragementTitleLabel.numberOfLines = 1
        encouragementTitleLabel.adjustsFontSizeToFitWidth = true
        encouragementTitleLabel.minimumScaleFactor = 0.6
        encouragementTitleLabel.clipsToBounds = false
        self.addSubview(encouragementTitleLabel)
        
        subtitleLabel = UILabel()
        subtitleLabel.font = UIFont.systemFont(ofSize: 18)
        subtitleLabel.numberOfLines = 3
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.6
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.clipsToBounds = false
        self.addSubview(subtitleLabel)
    }
    
    public override func updateConstraints() {
        defer {
            super.updateConstraints()
        }
   
        self.reloadConstraints()
        
        self.reloadEmojiImagesAndThenGradientBackgroundAndLabelColors()
    }
    
    func reloadConstraints() {
        defer {
            NSLayoutConstraint.activate(currentConstraints)
        }
        
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.frame.width))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.frame.height))
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: backgroundImageView, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: backgroundImageView, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: backgroundImageView, attribute: NSLayoutAttribute.height, multiplier: 1.0, constant: 0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: backgroundImageView, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:0))
        
        currentConstraints.append(NSLayoutConstraint(item: emojiView as Any, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.emojiImageSize))
        currentConstraints.append(NSLayoutConstraint(item: emojiView as Any, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: self.emojiImageSize))
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: emojiView, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: emojiView, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant: -10))
        
        currentConstraints.append(NSLayoutConstraint(item: encouragementTitleLabel as Any, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 24))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutAttribute.centerY, multiplier: 1.0, constant:30))
        currentConstraints.append(NSLayoutConstraint(item: self.backgroundImageView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant: 10))
        currentConstraints.append(NSLayoutConstraint(item: self.emojiView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant: -10))
        currentConstraints.append(NSLayoutConstraint(item: encouragementTitleLabel, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: subtitleLabel, attribute: NSLayoutAttribute.top, multiplier: 1.0, constant:-2))
        currentConstraints.append(NSLayoutConstraint(item: self.backgroundImageView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant: 10))
        
        currentConstraints.append(NSLayoutConstraint(item: subtitleLabel, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: subtitleLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1.0, constant:8))
        currentConstraints.append(NSLayoutConstraint(item: self.backgroundImageView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: subtitleLabel, attribute: NSLayoutAttribute.trailing, multiplier: 1.0, constant: 10))
        currentConstraints.append(NSLayoutConstraint(item: self.emojiView, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: subtitleLabel, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant: -10))
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        reloadConstraints()
        
        if let gradientLayer = self.gradientLayer {
            gradientLayer.frame = self.bounds
        }
    }
    
    private func reloadEmojiImagesAndThenGradientBackgroundAndLabelColors() {
        guard let _ = trophyProgress else {
            emojiImage = nil
            
            self.reloadEmojiUI()
            self.refreshGradientBackgroundAndLabelColors()
            return
        }
        
        if let cachedEmojiImage = ImageCache.default.retrieveImageInMemoryCache(forKey: self.emojiCacheKey, options: [.scaleFactor(UIScreen.main.scale)]) {
            self.emojiImage = cachedEmojiImage
            self.reloadEmojiUI()
            self.refreshGradientBackgroundAndLabelColors()
            return
        }
        
        
        if let cachedEmojiImage = ImageCache.default.retrieveImageInDiskCache(forKey: self.emojiCacheKey, options: [.scaleFactor(UIScreen.main.scale)]) {
            // cache the image to memory for next time
            ImageCache.default.store(cachedEmojiImage, original: nil, forKey: self.emojiCacheKey, processorIdentifier: "", cacheSerializer: DefaultCacheSerializer.default, toDisk: false, completionHandler:nil)

            self.emojiImage = cachedEmojiImage
            self.reloadEmojiUI()
            self.refreshGradientBackgroundAndLabelColors()
            return
        }
        
        // rendering the emoji can be slow, so perform in the background and then fade in
        emojiView.isHidden = true
        backgroundImageView.isHidden = true
        
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
                reallyStrongSelf.backgroundImageView.fadeIn()
                reallyStrongSelf.refreshGradientBackgroundAndLabelColors()
            }
        }
    }
    
    private func refreshGradientBackgroundAndLabelColors() {
        guard let emojiImage = emojiImage else {
            return
        }
        
        let ratio = emojiImage.size.width/emojiImage.size.height
        let downsampleDimension: CGFloat = 60
        let colors = emojiImage.getColors(scaleDownSize: CGSize(width: downsampleDimension, height: downsampleDimension/ratio))
        
        self.encouragementTitleLabel.textColor = colors.background
        self.subtitleLabel.textColor = colors.background
        
        var gradientLayer: CAGradientLayer! = self.gradientLayer
        if gradientLayer == nil {
            let cornerRadius: CGFloat = 10/57 * TrophyProgressButton.defaultBadgeDimension
            gradientLayer = CAGradientLayer()
            gradientLayer.locations = [0.4, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradientLayer.cornerRadius = cornerRadius
            self.backgroundImageView.layer.addSublayer(gradientLayer)
            self.gradientLayer = gradientLayer
        }
        
        var drawsBorder = false
        // draw a border for light background colors
        
        if let RGB = colors.primary.cgColor.components, RGB[0] > minimumColorValue && RGB[1] > minimumColorValue && RGB[2] > minimumColorValue {
            drawsBorder = true
        } else if let RGB = colors.secondary.cgColor.components, RGB[0] > minimumColorValue && RGB[1] > minimumColorValue && RGB[2] > minimumColorValue {
            drawsBorder = true
        }
        
        let borderColor = colors.background ?? UIColor.black
        
        let lineWidth: CGFloat = drawsBorder ? 4.0 : 0

        gradientLayer.borderWidth = lineWidth
        gradientLayer.borderColor = borderColor.cgColor
        gradientLayer.bounds = self.bounds
        gradientLayer.position = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height/2)
        gradientLayer.colors = [colors.secondary.cgColor, colors.primary.cgColor]
    }
    
    private func renderEmojiImages() {
        guard let trophyProgress = trophyProgress else {
            return
        }
        
        let imageSize = CGSize(width: self.emojiImageSize, height: self.emojiImageSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributedEmojiString = NSAttributedString(string: trophyProgress.emoji, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: self.emojiImageSize - 10), NSAttributedStringKey.foregroundColor: UIColor.black, NSAttributedStringKey.paragraphStyle: paragraphStyle])
        let boundingRect = attributedEmojiString.boundingRect(with: imageSize, options:[.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics], context: nil)
        
        let xOffset: CGFloat = 1 // dont know why, but emoji refuse to draw centered
        UIGraphicsBeginImageContextWithOptions(imageSize, false , 0.0)
        attributedEmojiString.draw(with: CGRect(x: (imageSize.width - boundingRect.width)/2 + xOffset, y: (imageSize.height - boundingRect.height)/2, width: imageSize.width, height: imageSize.height),  options:[.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics], context: nil)
        
        let emojiImageOptional = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let emojiImage = emojiImageOptional else {
            return
        }
        
        self.emojiImage = emojiImage
        
        if let emojiImage = self.emojiImage {
            ImageCache.default.store(emojiImage, forKey: self.emojiCacheKey)
        }
    }
}
