//
//  RideSummaryView.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UIKit

fileprivate class RideRewardComponentView : UIView {
    static fileprivate var emojiFontSize: CGFloat = 24
    static fileprivate var textFontSize: CGFloat = 16
    
    
    public var associatedObject: Any?
    public var emojiLabel: UILabel!
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
    
    override func layoutSubviews() {
        if (drawsDottedOutline) {
            self.backgroundColor = ColorPallete.shared.almostWhite
            let borderWidth: CGFloat = 2
            
            if self.borderLayer == nil {
                let borderLayer = CAShapeLayer()
                borderLayer.fillColor = UIColor.clear.cgColor
                bodyLabel.textColor = ColorPallete.shared.goodGreen
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
            bodyLabel.textColor = RideSummaryView.textColor
            self.backgroundColor = UIColor.clear
            
            if let layer = self.borderLayer {
                layer.removeFromSuperlayer()
                self.borderLayer = nil
            }
        }
    }
    
    func commonInit() {
        self.clipsToBounds = false
        self.translatesAutoresizingMaskIntoConstraints = false
        
        emojiLabel = UILabel()
        emojiLabel.backgroundColor = UIColor.clear
        emojiLabel.numberOfLines = 0
        emojiLabel.lineBreakMode = .byWordWrapping
        emojiLabel.textColor = RideSummaryView.textColor
        emojiLabel.font = UIFont.systemFont(ofSize: RideRewardComponentView.emojiFontSize)
        emojiLabel.clipsToBounds = false
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiLabel)
        
        bodyLabel = UILabel()
        bodyLabel.backgroundColor = UIColor.clear
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.numberOfLines = 0
        bodyLabel.font = UIFont.systemFont(ofSize: RideRewardComponentView.textFontSize)
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
        
        if (emojiLabel.text == "" && bodyLabel.text == "") {
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 0))
            return
        }
        
        let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: String(format:"H:|-[emojiLabel(%f)]-[bodyLabel]|", RideRewardComponentView.emojiFontSize*1.1), options: [.alignAllCenterY], metrics: nil, views: ["emojiLabel": emojiLabel, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: widthConstraints)
        
        let heightConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-4-[bodyLabel(>=emojiLabel)]-4-|", options: [], metrics: nil, views: ["emojiLabel": emojiLabel, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: heightConstraints)
        
        emojiLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
        bodyLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .vertical)
        
        self.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .vertical)
    }
}

fileprivate class RideSummaryComponentView : UIView {
    static fileprivate let lengthFontSize: CGFloat = 26
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
        lengthLabel.minimumScaleFactor = 0.6
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
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 0))
            return
        }
        
        
        let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: String(format:"H:|[distanceView(%f)]-6-[bodyLabel]|", RideSummaryComponentView.distanceViewDimensions), options: [.alignAllTop], metrics: nil, views: ["distanceView": distanceView, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: widthConstraints)
        
        currentConstraints.append(NSLayoutConstraint(item: distanceView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: RideSummaryComponentView.distanceViewDimensions))
        
        let yConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[bodyLabel(>=distanceView)]|", options: [], metrics: nil, views: ["distanceView": distanceView, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: yConstraints)
        
        distanceView.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
        bodyLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .vertical)
        
        self.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .vertical)
    }
}

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
    private var rewardViews: [RideRewardComponentView]!
    
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
        NSLayoutConstraint.deactivate(currentConstraints)
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
            
            let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: String(format: "H:|-[tripSummaryView]-[chevronImageView(%f)]-|", chevron.size.width), options: [.alignAllCenterY], metrics: nil, views: ["tripSummaryView": summaryView, "chevronImageView": chevronImageView!])
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
        var visualFormat = "V:|[tripSummaryView]"
        var i = 0
        for componentView in rewardViews {
            let stringI = "comp" + String(i)
            viewDict[stringI] = componentView
            visualFormat += String(format: "-8-[%@]", stringI)
            i += 1
            
            let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[componentView]-12-|", options: [], metrics: nil, views: ["componentView": componentView])
            currentConstraints.append(contentsOf: widthConstraints)
        }
        visualFormat += "-|"
        let heightConstraints = NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: [], metrics: nil, views: viewDict)
        currentConstraints.append(contentsOf: heightConstraints)
    }
    
    public func setTripSummary(tripLength: Float, description: String) {
        if let summaryView = tripSummaryView {
            summaryView.removeFromSuperview()
            self.tripSummaryView = nil
        }
        
        defer {
            self.setNeedsUpdateConstraints()
        }
        
        guard description != "" else {
            return
        }
        
        tripSummaryView = RideSummaryComponentView()
        self.addSubview(tripSummaryView!)
        
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
        var colors = [ColorPallete.shared.notificationActionBlue, ColorPallete.shared.pink, ColorPallete.shared.primary, ColorPallete.shared.turquoise]
        
        for rewardDict in rewards {
            if let displaySafeEmoji = rewardDict["displaySafeEmoji"] as? String,
                let descriptionText = rewardDict["descriptionText"] as? String, descriptionText.range(of: "day ride streak") == nil {
                let rewardView = RideRewardComponentView()
                if let object = rewardDict["object"] {
                    rewardView.associatedObject = object
                }
                
                if let rewardUUID = rewardDict["rewardUUID"] as? String, !rewardUUID.isEmpty {
                    rewardView.drawsDottedOutline = true
                    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RideSummaryView.didTapReward(sender:)))
                    rewardView.addGestureRecognizer(tapRecognizer)
                }
                if (animated) {
                    rewardView.isHidden = true
                    let v = i // capture state in delayed scope
                    self.delay(0.3 + Double(i) * 0.4, completionHandler: {
                        self.sparkle(colors[v%colors.count], inRect: CGRect(x: rewardView.frame.origin.x - 8, y: rewardView.frame.origin.y, width: rewardView.frame.size.width + 10, height: rewardView.frame.size.height))
                        rewardView.fadeIn()
                    })
                    i += 1
                }
                
                self.addSubview(rewardView)
                
                rewardView.emojiLabel.text = displaySafeEmoji
                rewardView.bodyLabel.text = descriptionText
                rewardViews.append(rewardView)
            }
        }
    }
    
    func didTapReward(sender: AnyObject) {
        if let reward = ((sender as? UITapGestureRecognizer)?.view as? RideRewardComponentView)?.associatedObject, let delegate = self.delegate {
            delegate.didTapReward(withAssociatedObject: reward)
        }
    }
}
