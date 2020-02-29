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
    
    private let emojiImageSize: CGFloat = 80
    
    var title: String? = "" {
        didSet {
            self.encouragementTitleLabel.text = title
        }
    }
    
    var subtitle: String? = "" {
        didSet {
            self.subtitleLabel.text = subtitle
        }
    }
    
    var header: String? = "" {
        didSet {
            self.headerLabel.text = header
        }
    }
    
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
    
    private var emojiImage: UIImage?
    
    private var emojiView: UIImageView!
    private var backgroundImageView: UIImageView!
    private var emojiImageData: ComputedImageData = ComputedImageData()
    
    private var gradientLayer: CAGradientLayer?
    private var headerShadowLayer: CALayer?
    
    private var encouragementTitleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var headerLabel: UILabel!
    
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
                borderLayer.lineJoin = CAShapeLayerLineJoin.round
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
        encouragementTitleLabel.numberOfLines = 2
        encouragementTitleLabel.adjustsFontSizeToFitWidth = true
        encouragementTitleLabel.minimumScaleFactor = 0.3
        encouragementTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(encouragementTitleLabel)
        
        subtitleLabel = UILabel()
        subtitleLabel.numberOfLines = 4
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.6
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(subtitleLabel)
        
        headerLabel = UILabel()
        headerLabel.numberOfLines = 1
        headerLabel.adjustsFontSizeToFitWidth = true
        headerLabel.minimumScaleFactor = 0.6
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(headerLabel)
    }
    
    public override func updateConstraints() {
        defer {
            super.updateConstraints()
        }
   
        self.reloadConstraints()
        
        self.reloadEmojiImagesAndThenGradientBackgroundAndLabelColors()
    }

    #if DEBUG
    @objc func injected() {
        reloadConstraints()
        refreshGradientBackgroundAndLabelColors(withColors: nil)
    }
    #endif
    
    func reloadConstraints() {
        defer {
            NSLayoutConstraint.activate(currentConstraints)
        }
        
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: self.frame.width))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: self.frame.height))
        
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: backgroundImageView, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: backgroundImageView, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant:0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: backgroundImageView, attribute: NSLayoutConstraint.Attribute.height, multiplier: 1.0, constant: 0))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: backgroundImageView, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1.0, constant:0))
        
        currentConstraints.append(NSLayoutConstraint(item: emojiView as Any, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: self.emojiImageSize))
        currentConstraints.append(NSLayoutConstraint(item: emojiView as Any, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: self.emojiImageSize))
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: emojiView, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1.0, constant:12))
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: emojiView, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: -10))
        
        let headerLabelBottomConstraint = NSLayoutConstraint(item: self.backgroundImageView, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: headerLabel, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1.0, constant:4)
        headerLabelBottomConstraint.priority = .required
        currentConstraints.append(headerLabelBottomConstraint)
        
        currentConstraints.append(NSLayoutConstraint(item: self.backgroundImageView, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: headerLabel, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: -10))
        
        currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1.0, constant:40))
        currentConstraints.append(NSLayoutConstraint(item: self.backgroundImageView, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant: 18))
        currentConstraints.append(NSLayoutConstraint(item: self.emojiView, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: -14))
        
        currentConstraints.append(NSLayoutConstraint(item: subtitleLabel, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: encouragementTitleLabel, attribute: NSLayoutConstraint.Attribute.lastBaseline, multiplier: 1.0, constant:0))
        
        let subtitleBottomConstraint = NSLayoutConstraint(item: headerLabel, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: subtitleLabel, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1.0, constant:8)
        subtitleBottomConstraint.priority = .required
        currentConstraints.append(subtitleBottomConstraint)
        
        currentConstraints.append(NSLayoutConstraint(item: headerLabel, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant:headerLabel.font.pointSize + 2))
        
         currentConstraints.append(NSLayoutConstraint(item: subtitleLabel, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: subtitleLabel.font.pointSize * CGFloat(subtitleLabel.numberOfLines) + 2))
        
        currentConstraints.append(NSLayoutConstraint(item: encouragementTitleLabel, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant:encouragementTitleLabel.font.pointSize * CGFloat(encouragementTitleLabel.numberOfLines)))
        
        currentConstraints.append(NSLayoutConstraint(item: self.backgroundImageView, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: subtitleLabel, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant: 18))
        currentConstraints.append(NSLayoutConstraint(item: self.encouragementTitleLabel, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: subtitleLabel, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: 0))
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        reloadConstraints()
        
        if self.frame.size.width > 300 {
            encouragementTitleLabel.font = UIFont.boldSystemFont(ofSize: 24)
            subtitleLabel.font = UIFont.systemFont(ofSize: 16)
            headerLabel.font = UIFont.boldSystemFont(ofSize: 16)
        } else {
            encouragementTitleLabel.font = UIFont.boldSystemFont(ofSize: 22)
            subtitleLabel.font = UIFont.systemFont(ofSize: 14)
            headerLabel.font = UIFont.boldSystemFont(ofSize: 14)
        }
        
        if let gradientLayer = self.gradientLayer {
            gradientLayer.frame = self.bounds
        }
    }
    
    private func reloadEmojiImagesAndThenGradientBackgroundAndLabelColors() {
        guard let trophyProgress = trophyProgress else {
            emojiImage = nil
            
            self.reloadEmojiUI()
            self.refreshGradientBackgroundAndLabelColors(withColors: nil)
            return
        }
        
        self.emojiImageData.imageSize = CGSize(width:self.emojiImageSize, height:self.emojiImageSize)
        self.emojiImageData.emoji = self.trophyProgress?.emoji
        self.emojiImageData.iconURL = self.trophyProgress?.iconURL
        self.emojiImageData.emojiFontSize = self.emojiImageSize - 10

        let iconCompletionHandler: (Image?, UIImageColors?) -> Void = {(image, colors) in
            
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.emojiView.image = image
                strongSelf.emojiImage = image
                strongSelf.reloadEmojiUI()
                if let gradientColors = colors {
                    strongSelf.refreshGradientBackgroundAndLabelColors(withColors: gradientColors)
                }
            })
        }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if trophyProgress.iconURL != nil {
                EmojiImageView.renderIconImage(withComputedData: strongSelf.emojiImageData, completionHandler: iconCompletionHandler)
            }
            else {
                EmojiImageView.renderEmojiImage(withComputedData: strongSelf.emojiImageData, completionHandler: iconCompletionHandler)
            }
        }
    }
    
    private func refreshGradientBackgroundAndLabelColors(withColors gradientColors: UIImageColors?) {
        guard let _ = trophyProgress, let colors = gradientColors else {
            return
        }
        
        self.encouragementTitleLabel.textColor = colors.background
        self.subtitleLabel.textColor = colors.background
        self.headerLabel.textColor = colors.background
        
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
        gradientLayer.masksToBounds = true
        gradientLayer.position = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height/2)
        gradientLayer.colors = [colors.secondary.cgColor, colors.primary.cgColor]
        
        let headerShadowHeight: CGFloat = 26

        var headerShadowLayer: CALayer! = self.headerShadowLayer
        if headerShadowLayer == nil {
            headerShadowLayer = CALayer()
            headerShadowLayer.masksToBounds = true
            gradientLayer.addSublayer(headerShadowLayer)
            self.headerShadowLayer = headerShadowLayer
        }
        
        headerShadowLayer.backgroundColor = colors.primary.withAlphaComponent(0.8).cgColor
        headerShadowLayer.bounds = CGRect(x: 0, y: 0, width: self.frame.size.width, height: headerShadowHeight)
        headerShadowLayer.position = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height - headerShadowHeight/2)
    }
}
