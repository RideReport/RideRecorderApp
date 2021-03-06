//
//  RewardView.swift
//  Ride Report
//
//  Created by William Henderson on 10/11/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Kingfisher


@IBDesignable public class TrophyView : UIView {
    public var associatedObject: Any?
    
    @IBInspectable var emojiFont: UIFont = UIFont.systemFont(ofSize: 30)  {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var bodyFont: UIFont = UIFont.systemFont(ofSize: 18)  {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var bodyColor = ColorPallete.shared.darkGrey  {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var emoji: String = "" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var iconURLString: String? = nil {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var body: String = "" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable public var drawsDottedOutline = false {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    private var iconImageView: UIImageView!
    private var emojiLabel: UILabel!
    private var bodyLabel: UILabel!
    
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
        if let iconURLString = iconURLString, let iconURL = URL(string: iconURLString) {
            self.iconImageView.kf.setImage(with: iconURL)
            self.iconImageView.isHidden = false
            emojiLabel.isHidden = true
        } else {
            emojiLabel.isHidden = false
            iconImageView.isHidden = true
        }
        
        emojiLabel.text = emoji
        bodyLabel.text = body
        
        emojiLabel.textColor = self.bodyColor
        emojiLabel.font = self.emojiFont

        bodyLabel.font = self.bodyFont
        
        if (drawsDottedOutline) {
            self.backgroundColor = ColorPallete.shared.almostWhite
            let borderWidth: CGFloat = 2
            
            bodyLabel.textColor = ColorPallete.shared.goodGreen
            
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
                let borderRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height - 6)
                
                layer.bounds = borderRect
                layer.position = CGPoint(x: frameSize.width/2, y: frameSize.height/2)
                layer.path = UIBezierPath(roundedRect: borderRect, cornerRadius: 5).cgPath
            }
        } else {
            self.backgroundColor = UIColor.clear
            bodyLabel.textColor = self.bodyColor
            
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
        
        emojiLabel = UILabel()
        emojiLabel.backgroundColor = UIColor.clear
        emojiLabel.numberOfLines = 0
        emojiLabel.lineBreakMode = .byWordWrapping
        emojiLabel.textAlignment = .center
        emojiLabel.clipsToBounds = false
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(emojiLabel)
        
        iconImageView = UIImageView()
        iconImageView.backgroundColor = UIColor.clear
        iconImageView.clipsToBounds = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.isHidden = true
        self.addSubview(iconImageView)
        
        bodyLabel = UILabel()
        bodyLabel.backgroundColor = UIColor.clear
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(bodyLabel)
        
        reloadUI()
    }
    
    public override func updateConstraints() {
        NSLayoutConstraint.deactivate(currentConstraints)
        currentConstraints = []
        
        defer {
            super.updateConstraints()
            NSLayoutConstraint.activate(currentConstraints)
        }
        
        if (emojiLabel.text == "" && bodyLabel.text == "") {
            currentConstraints.append(NSLayoutConstraint(item: self, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: 0))
            return
        }
        
        let widthConstraints = NSLayoutConstraint.constraints(withVisualFormat: String(format:"H:|-[emojiLabel(%f)]-12-[bodyLabel]|", self.emojiFont.pointSize*1.1), options: [.alignAllCenterY], metrics: nil, views: ["emojiLabel": emojiLabel, "bodyLabel": bodyLabel])
        currentConstraints.append(contentsOf: widthConstraints)
        
        currentConstraints.append(NSLayoutConstraint(item: emojiLabel, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: iconImageView, attribute: NSLayoutConstraint.Attribute.height, multiplier: 1.0, constant: 0))
        currentConstraints.append(NSLayoutConstraint(item: emojiLabel, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: iconImageView, attribute: NSLayoutConstraint.Attribute.width, multiplier: 1.0, constant: 0))
        currentConstraints.append(NSLayoutConstraint(item: emojiLabel, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: iconImageView, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: 0))
        currentConstraints.append(NSLayoutConstraint(item: emojiLabel, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: iconImageView, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant: 0))
        currentConstraints.append(NSLayoutConstraint(item: emojiLabel, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: iconImageView, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: 0))
        currentConstraints.append(NSLayoutConstraint(item: emojiLabel, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: iconImageView, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1.0, constant: 0))
        
        var heightConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-4-[bodyLabel(>=emojiLabel)]-4-|", options: [], metrics: nil, views: ["emojiLabel": emojiLabel, "bodyLabel": bodyLabel])
        if (drawsDottedOutline) {
            heightConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[bodyLabel(>=emojiLabel)]-6-|", options: [], metrics: nil, views: ["emojiLabel": emojiLabel, "bodyLabel": bodyLabel])
        }
        currentConstraints.append(contentsOf: heightConstraints)
        
        emojiLabel.setContentCompressionResistancePriority(UILayoutPriority.required, for: .vertical)
        bodyLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
        
        self.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
    }
}
