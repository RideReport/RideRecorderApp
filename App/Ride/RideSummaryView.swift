//
//  RideSummaryView.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UIKit

fileprivate class RideSummaryComponentView : UIView {
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
                borderLayer.strokeColor = ColorPallete.shared.goodGreen.cgColor
                borderLayer.lineWidth = borderWidth
                borderLayer.lineJoin = kCALineJoinRound
                borderLayer.lineDashPattern = [6,3]
                
                self.layer.addSublayer(borderLayer)
                self.borderLayer = borderLayer
            }
            if let layer = self.borderLayer {
                let frameSize = self.frame.size
                let borderRect = CGRect(x: -16, y: 4, width: frameSize.width + 8, height: frameSize.height + 8)
                
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
    
    func commonInit() {
        self.backgroundColor = UIColor.clear
        
        self.clipsToBounds = false
        self.translatesAutoresizingMaskIntoConstraints = false
        
        emojiLabel = UILabel()
        emojiLabel.backgroundColor = UIColor.clear
        emojiLabel.numberOfLines = 0
        emojiLabel.lineBreakMode = .byWordWrapping
        emojiLabel.textColor = RideSummaryView.textColor
        emojiLabel.font = UIFont.systemFont(ofSize: RideSummaryView.emojiFontSize)
        emojiLabel.clipsToBounds = false
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiLabel)
        
        bodyLabel = UILabel()
        bodyLabel.backgroundColor = UIColor.clear
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = RideSummaryView.textColor
        bodyLabel.font = UIFont.systemFont(ofSize: RideSummaryView.textFontSize)
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
        
        let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: String(format:"H:|[emojiLabel(%f)]-[bodyLabel]|", RideSummaryView.emojiFontSize*1.1), options: [.alignAllTop], metrics: nil, views: ["emojiLabel": emojiLabel, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: widthConstraints)
        
        let heightConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[bodyLabel(>=emojiLabel)]|", options: [], metrics: nil, views: ["emojiLabel": emojiLabel, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: heightConstraints)
        
        emojiLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
        bodyLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .vertical)
        
        self.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .vertical)
    }
}

@objc protocol RideSummaryViewDelegate {
    @objc func didTapReward(_ reward: TripReward)
}

@IBDesignable public class RideSummaryView : UIView {
    weak var delegate : RideSummaryViewDelegate? = nil

    static fileprivate var textColor = ColorPallete.shared.darkGrey
    static fileprivate var marginX: CGFloat = 8
    static fileprivate var emojiFontSize: CGFloat = 40
    static fileprivate var textFontSize: CGFloat = 18
    
    var currentConstraints: [NSLayoutConstraint]! = []

    private var chevronImageView: UIImageView?
    private var tripSummaryView: RideSummaryComponentView?
    private var rewardViews: [RideSummaryComponentView]!
    
    var trip: Trip? = nil {
        didSet {
            reloadUI()
        }
    }
    
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
            visualFormat += String(format: "-16-[%@]", stringI)
            i += 1
            
            let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-[componentView]-|", options: [], metrics: nil, views: ["componentView": componentView])
            currentConstraints.append(contentsOf: widthConstraints)
        }
        visualFormat += "-|"
        let heightConstraints = NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: [], metrics: nil, views: viewDict)
        currentConstraints.append(contentsOf: heightConstraints)
    }

    
    func reloadUI() {
        if let oldRewardViews = rewardViews {
            rewardViews = []
            
            for rewardView in oldRewardViews {
                rewardView.removeFromSuperview()
            }
        } else {
            rewardViews = []
        }
        if let summaryView = tripSummaryView {
            summaryView.removeFromSuperview()
            self.tripSummaryView = nil
        }

        defer {
            self.setNeedsUpdateConstraints()
        }
        
        guard let trip = self.trip else {
            return
        }
        
        tripSummaryView = RideSummaryComponentView()
        self.addSubview(tripSummaryView!)
        
        if !trip.isClosed {
            tripSummaryView?.emojiLabel.text = "🏁"
            tripSummaryView?.bodyLabel.text = String(format: "%@ starting at %@.", trip.inProgressLength.distanceString(), trip.timeString())
        } else {
            tripSummaryView?.emojiLabel.text = trip.climacon ?? ""
            tripSummaryView?.bodyLabel.text = trip.displayStringWithTime()
            
            for element in trip.tripRewards {
                if let reward = element as? TripReward, reward.descriptionText.range(of: "day ride streak") == nil {
                    let rewardView = RideSummaryComponentView()
                    rewardView.associatedObject = reward
                    
                    if let rewardUUID = reward.rewardUUID, !rewardUUID.isEmpty {
                        rewardView.drawsDottedOutline = true
                        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RideSummaryView.didTapReward(sender:)))
                        rewardView.addGestureRecognizer(tapRecognizer)
                    }
                    
                    self.addSubview(rewardView)
                    
                    rewardView.emojiLabel.text = reward.displaySafeEmoji
                    rewardView.bodyLabel.text = reward.descriptionText
                    rewardViews.append(rewardView)
                }
            }
        }
    }
    
    func didTapReward(sender: AnyObject) {
        if let reward = ((sender as? UITapGestureRecognizer)?.view as? RideSummaryComponentView)?.associatedObject as? TripReward, let delegate = self.delegate {
            delegate.didTapReward(reward)
        }
    }
}
