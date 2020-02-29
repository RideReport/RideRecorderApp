//
//  RideSummaryView.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UIKit

protocol RideSummaryViewDelegate: class {
    func didTapReward(withAssociatedObject: Any)
}

@IBDesignable public class RideSummaryView : UIView {
    weak var delegate : RideSummaryViewDelegate? = nil

    static fileprivate var textColor = ColorPallete.shared.darkGrey
    static fileprivate var marginX: CGFloat = 8
    
    var currentConstraints: [NSLayoutConstraint]! = []

    private var chevronImageView: UIImageView?
    private var tripSummaryView: RideSummaryComponentView?
    private var rewardViews: [TrophyView]!
    public var tripLength: Float = -1.0
    
    var chevronImage: UIImage? = nil {
        didSet {
            self.setNeedsUpdateConstraints()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = UIColor.clear
        
        rewardViews = []
    }
    
    public override func updateConstraints() {
        if (currentConstraints != nil ) {
            NSLayoutConstraint.deactivate(currentConstraints)
        }
        currentConstraints = []
        
        defer {
            super.updateConstraints()
            NSLayoutConstraint.activate(currentConstraints)
        }
        
        guard let summaryView = tripSummaryView else {
            if chevronImageView != nil {
                chevronImageView?.removeFromSuperview()
                chevronImageView = nil
            }
            
            return
        }
        
        if let chevron = self.chevronImage {
            if chevronImageView == nil {
                let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: chevron.size.width, height: chevron.size.height))
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.tintColor = ColorPallete.shared.goodGreen
                imageView.tag = 31231
                imageView.image = chevron
                self.addSubview(imageView)
                self.chevronImageView = imageView
            }
            
            let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: String(format: "H:|-[tripSummaryView]-[chevronImageView(%f)]-12-|", chevron.size.width), options: [.alignAllCenterY], metrics: nil, views: ["tripSummaryView": summaryView, "chevronImageView": chevronImageView!])
            currentConstraints.append(contentsOf: widthConstraints)
        } else {
            if chevronImageView != nil {
                chevronImageView?.removeFromSuperview()
                chevronImageView = nil
            }
            
            let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-[tripSummaryView]-|", options: [], metrics: nil, views: ["tripSummaryView": summaryView])
            currentConstraints.append(contentsOf: widthConstraints)
        }
        
        var viewDict: [String: Any] = ["tripSummaryView": summaryView]
        var visualFormat = "V:|-[tripSummaryView]"
        var i = 0
        for componentView in rewardViews {
            let stringI = "comp" + String(i)
            viewDict[stringI] = componentView
            if i == 0 {
                visualFormat += String(format: "-6-[%@]", stringI)
            } else {
                visualFormat += String(format: "-(-6)-[%@]", stringI)
            }
            i += 1
            
            let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-4-[componentView]-12-|", options: [], metrics: nil, views: ["componentView": componentView])
            currentConstraints.append(contentsOf: widthConstraints)
        }
        visualFormat += "-|"
        let heightConstraints = NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: [], metrics: nil, views: viewDict)
        currentConstraints.append(contentsOf: heightConstraints)
    }

    public func setTripSummary(tripLength: Float, description: String) {
        guard description != "" else {
            if let summaryView = tripSummaryView {
                summaryView.removeFromSuperview()
                self.tripSummaryView = nil
                self.tripLength = 0
                self.setNeedsUpdateConstraints()
            }

            return
        }
        
        if tripSummaryView == nil {
            tripSummaryView = RideSummaryComponentView()
            self.addSubview(tripSummaryView!)
            self.setNeedsUpdateConstraints()

        }
        
        self.tripLength = tripLength
        tripSummaryView?.length = tripLength
        tripSummaryView?.bodyLabel.text = description
    }
    
    public func setRewards(_ rewards: [[String: Any]], animated: Bool = false) {
        if let oldRewardViews = rewardViews {
            rewardViews = []
            
            for rewardView in oldRewardViews {
                rewardView.removeFromSuperview()
            }
        } else {
            rewardViews = []
        }

        defer {
            self.setNeedsUpdateConstraints()
        }
    
        var i: Int = 0
        var colors = [ColorPallete.shared.notificationActionBlue, ColorPallete.shared.pink, ColorPallete.shared.primary, ColorPallete.shared.orange, ColorPallete.shared.turquoise, ColorPallete.shared.badRed, ColorPallete.shared.brightBlue]
        
        for rewardDict in rewards {
            if let displaySafeEmoji = rewardDict["emoji"] as? String,
                let descriptionText = rewardDict["description"] as? String {
                let rewardView = TrophyView()
                if let object = rewardDict["object"] {
                    rewardView.associatedObject = object
                }
                
                if let rewardUUID = rewardDict["reward_uuid"] as? String, !rewardUUID.isEmpty {
                    rewardView.drawsDottedOutline = true
                    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RideSummaryView.didTapReward(sender:)))
                    rewardView.addGestureRecognizer(tapRecognizer)
                }
               
                if (animated) {
                    rewardView.isHidden = true
                    let v = i // capture state in delayed scope
                    self.delay(0.3 + Double(i) * 0.5, completionHandler: {
                        let animationRect = CGRect(x: rewardView.frame.origin.x - 8, y: rewardView.frame.origin.y, width: rewardView.frame.size.width + 10, height: rewardView.frame.size.height)
                        let color = colors[v%colors.count]
                        self.sparkle(color, inRect: animationRect)
                        if v > 0 {
                            // badges for combos!
                            self.animateMultiplierBonusBadge(multiplier: v, color: color, inRect: animationRect)
                        }
                        rewardView.fadeIn()
                    })
                    i += 1
                }
                
                self.addSubview(rewardView)
                
                rewardView.emoji = displaySafeEmoji
                rewardView.body = descriptionText
                
                if let iconURLString = rewardDict["icon_url_string"] as? String {
                    rewardView.iconURLString = iconURLString
                }
                
                rewardViews.append(rewardView)
            }
        }
    }
    
    public func hideRewards() {
        for rewardView in self.rewardViews {
            rewardView.fadeOut()
        }
    }
    
    public func showRewards() {
        for rewardView in self.rewardViews {
            rewardView.fadeIn()
        }
    }
    
    private func animateMultiplierBonusBadge(multiplier: Int, color: UIColor, inRect: CGRect) {
        let duration: TimeInterval = 0.1
        let badgeSize: CGFloat = 40
        
        let borderFrame = CGRect(x: 0, y: 0, width: badgeSize, height: badgeSize)
        let animationLayer = CAShapeLayer()
        animationLayer.fillColor = color.cgColor
        animationLayer.contentsScale = UIScreen.main.scale
        animationLayer.lineWidth = 3
        animationLayer.strokeColor = ColorPallete.shared.almostWhite.cgColor
        animationLayer.bounds = borderFrame
        animationLayer.position = CGPoint(x: inRect.origin.x + 2*inRect.size.width/3, y: inRect.origin.y + inRect.size.height/2)
        animationLayer.path = UIBezierPath(ovalIn: borderFrame).cgPath
        self.layer.addSublayer(animationLayer)
        
        let fontSize: CGFloat = 22
        let textLayer = CATextLayer()
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.foregroundColor = ColorPallete.shared.almostWhite.cgColor
        textLayer.font = CTFontCreateWithName("Helvetica-Bold" as CFString, 18.0, nil)
        textLayer.fontSize = fontSize
        textLayer.alignmentMode = CATextLayerAlignmentMode.center
        textLayer.bounds = CGRect(x: 0, y: 0, width: badgeSize, height: fontSize)
        textLayer.position = CGPoint(x: borderFrame.size.width/2, y: borderFrame.size.height/2 - (fontSize - badgeSize/2))
        textLayer.string = String(format: "%iX", multiplier + 1)
        animationLayer.addSublayer(textLayer)
        
        CATransaction.begin()
        
        CATransaction.setCompletionBlock {
            animationLayer.removeFromSuperlayer()
        }
        
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        //scaleAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0.8, 1.01)
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        scaleAnimation.duration = duration
        scaleAnimation.values = [NSValue(caTransform3D: CATransform3DMakeScale(CGFloat(pow(Double(multiplier), 3)) * 2.0, CGFloat(pow(Double(multiplier), 3)) * 2.0, CGFloat(pow(Double(multiplier), 3)) * 2.0)),
                                 NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0))]
        animationLayer.add(scaleAnimation, forKey:"scaleAnimation")
        
        let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        opacityAnimation.duration = 1.5
        opacityAnimation.values = [NSNumber(value: 1.0 as Float),
                                   NSNumber(value: 0.0 as Float)]
        animationLayer.add(opacityAnimation, forKey:"opacity")
        
        animationLayer.opacity = 0.0
        
        CATransaction.commit()
    }
    
    @objc func didTapReward(sender: AnyObject) {
        if let reward = ((sender as? UITapGestureRecognizer)?.view as? TrophyView)?.associatedObject, let delegate = self.delegate {
            delegate.didTapReward(withAssociatedObject: reward)
        }
    }
}

fileprivate class RideSummaryComponentView : UIView {
    static fileprivate let lengthFontSize: CGFloat = 24
    static fileprivate let unitsFontSize: CGFloat = 10
    static fileprivate let textFontSize: CGFloat = 18
    static fileprivate let distanceViewDimensions = RideSummaryComponentView.lengthFontSize + RideSummaryComponentView.unitsFontSize + 10
    
    public var length: Meters = 0 {
        didSet {
            let (distanceString, unitsString, _) = self.length.distanceStrings(suppressFractionalUnits: false)
            lengthLabel.text = distanceString
            unitsLabel.text = unitsString
        }
    }
    
    private var distanceView: UIView!
    private var lengthLabel: UILabel!
    private var unitsLabel: UILabel!
    
    public var bodyLabel: UILabel!
    
    public var drawsDottedOutline = false {
        didSet {
            self.setNeedsLayout()
        }
    }
    
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
    
    func commonInit() {
        self.backgroundColor = UIColor.clear
        
        self.clipsToBounds = false
        self.translatesAutoresizingMaskIntoConstraints = false
        
        distanceView = UIView()
        distanceView.backgroundColor = UIColor.clear
        distanceView.translatesAutoresizingMaskIntoConstraints = false
        distanceView.clipsToBounds = false
        
        self.addSubview(distanceView)
        
        let borderFrame = CGRect(x: 0, y: 0, width: RideSummaryComponentView.distanceViewDimensions, height: RideSummaryComponentView.distanceViewDimensions)
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = ColorPallete.shared.primary.cgColor
        maskLayer.bounds = borderFrame
        maskLayer.position = CGPoint(x: borderFrame.size.width/2, y: borderFrame.size.height/2)
        maskLayer.path = UIBezierPath(ovalIn: borderFrame).cgPath
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [ColorPallete.shared.primary.cgColor, ColorPallete.shared.primaryDark.cgColor]
        gradientLayer.locations = [0.6, 1.0]
        gradientLayer.bounds = borderFrame
        gradientLayer.position = CGPoint(x: borderFrame.size.width/2, y: borderFrame.size.height/2)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.mask = maskLayer
        distanceView.layer.addSublayer(gradientLayer)
        
        lengthLabel = UILabel()
        lengthLabel.backgroundColor = UIColor.clear
        lengthLabel.adjustsFontSizeToFitWidth = true
        lengthLabel.clipsToBounds = false
        lengthLabel.textAlignment = .center
        lengthLabel.minimumScaleFactor = 0.3
        lengthLabel.numberOfLines = 1
        lengthLabel.textColor = ColorPallete.shared.almostWhite
        lengthLabel.font = UIFont.boldSystemFont(ofSize: RideSummaryComponentView.lengthFontSize)
        lengthLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceView.addSubview(lengthLabel)
        
        unitsLabel = UILabel()
        unitsLabel.backgroundColor = UIColor.clear
        unitsLabel.adjustsFontSizeToFitWidth = true
        unitsLabel.clipsToBounds = false
        unitsLabel.minimumScaleFactor = 0.6
        unitsLabel.textAlignment = .center
        unitsLabel.numberOfLines = 1
        unitsLabel.textColor = ColorPallete.shared.almostWhite
        unitsLabel.font = UIFont.systemFont(ofSize: RideSummaryComponentView.unitsFontSize)
        unitsLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceView.addSubview(unitsLabel)
        
        let xConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-(>=8)-[lengthLabel]-(>=8)-|", options: [.alignAllCenterX], metrics: nil, views: ["lengthLabel": lengthLabel])
        NSLayoutConstraint.activate(xConstraints)
        let xConstraints2 = NSLayoutConstraint.constraints(withVisualFormat: "H:|-(>=8)-[unitsLabel]-(>=8)-|", options: [.alignAllCenterX], metrics: nil, views: ["unitsLabel": unitsLabel])
        NSLayoutConstraint.activate(xConstraints2)
        NSLayoutConstraint(item: lengthLabel, attribute: .centerX, relatedBy: .equal, toItem: distanceView, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        let yConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[lengthLabel]-(-5)-[unitsLabel]-7-|", options: [.alignAllCenterX], metrics: nil, views: ["lengthLabel": lengthLabel, "unitsLabel": unitsLabel])
        NSLayoutConstraint.activate(yConstraints)
        
        bodyLabel = UILabel()
        bodyLabel.backgroundColor = UIColor.clear
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = RideSummaryView.textColor
        bodyLabel.font = UIFont.systemFont(ofSize: RideSummaryComponentView.textFontSize)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(bodyLabel)
    }
    
    public override func updateConstraints() {
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        defer {
            super.updateConstraints()
            NSLayoutConstraint.activate(currentConstraints)
        }
        
        if (bodyLabel.text == "") {
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: 0))
            return
        }
        
        
        let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: String(format:"H:|[distanceView(%f)]-6-[bodyLabel]|", RideSummaryComponentView.distanceViewDimensions), options: [.alignAllCenterY], metrics: nil, views: ["distanceView": distanceView, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: widthConstraints)
        
        currentConstraints.append(NSLayoutConstraint(item: distanceView, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: RideSummaryComponentView.distanceViewDimensions))
        
        let yConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=8)-[bodyLabel]-(>=8)-|", options: [], metrics: nil, views: ["bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: yConstraints)
        
        distanceView.setContentCompressionResistancePriority(UILayoutPriority.required, for: .vertical)
        bodyLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
        
        self.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
    }
}
