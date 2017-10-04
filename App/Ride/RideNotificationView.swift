//
//  RideSummaryView.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import AudioToolbox

@objc protocol RideNotificationViewDelegate {
    @objc optional func didOpenControls(_ view: RideNotificationView)
    @objc optional func didCloseControls(_ view: RideNotificationView)
    @objc optional func didTapEditButton(_ view: RideNotificationView)
    @objc optional func didTapDestructiveButton(_ view: RideNotificationView)
    @objc optional func didTapActionButton(_ view: RideNotificationView)
    @objc optional func didTapClearButton(_ view: RideNotificationView)
    @objc optional func didTapShareButton(_ view: RideNotificationView)
    @objc optional func didDeepTouchSummaryView(_ view: RideNotificationView)
}

@IBDesignable class RideNotificationView : UIView, UIScrollViewDelegate {
    @IBInspectable var body: String = "Lorem ipsum dolor sit amet" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var dateString: String = "now" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var appName: String = "Ride Report" {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var appIcon: UIImage? = nil {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var desturctiveActionTitle: String = Rating.ratingWithCurrentVersion(.bad).noun {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var actionTitle: String = Rating.ratingWithCurrentVersion(.good).noun {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var editTitle: String = "Change\nMode" {
        didSet {
            reloadUI()
        }
    }
    
    enum RideSummaryViewStyle : NSInteger {
        case lockScreenStyle = 1
        case appStyle
        case shareStyle
    }
    
    @IBInspectable var interfaceStyle: NSInteger = 1 {
        didSet {
            if let newStyle = RideSummaryViewStyle(rawValue: self.interfaceStyle) {
                self.style = newStyle
            }
        }
    }
    
    var style: RideSummaryViewStyle = .lockScreenStyle {
        didSet {
            reloadUI()
        }
    }
    
    override var canBecomeFocused : Bool {
        return !self.allowsScrolling
    }
    
    var showsEditButton : Bool = false {
        didSet {
            layoutSubviews()
        }
    }
    var showsActionButon : Bool = true {
        didSet {
            layoutSubviews()
        }
    }
    var showsDestructiveActionButon : Bool = true {
        didSet {
            layoutSubviews()
        }
    }
    var showsShareButon : Bool = true {
        didSet {
            layoutSubviews()
        }
    }
    
    var allowsScrolling : Bool = true {
        didSet {
            self.scrollView.isScrollEnabled = allowsScrolling
            self.scrollView.delaysContentTouches = allowsScrolling
            self.scrollView.isExclusiveTouch = allowsScrolling
            self.scrollView.isUserInteractionEnabled = allowsScrolling
        }
    }
    
    let buttonWidth : CGFloat = 78.0
    
    weak var delegate : RideNotificationViewDelegate? = nil
    
    var isShowingControls = false
    
    var insetX : CGFloat = 15
    
    var scrollView : UIScrollView!
    var controlsView : UIView!
    var destructiveButton : UIButton!
    var actionButton : UIButton!
    var editButton : UIButton!
    var shareButton : UIButton!
    var clearButton : ClearButton!
    
    var contentView : UIView!
    var appNameLabel : UILabel!
    var dateLabel : UILabel!
    var bodyLabel : UILabel!
    var slideLabel : UILabel!
    
    var lineViewTop : UIView!
    var titleBar : UIView!
    var lineViewBottom : UIView!
    
    var appIconView : UIImageView!
    
    private var didFireDeepTouchForTouchEvent = false
    
    private var heightConstraint : NSLayoutConstraint! = nil
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        self.addSubview(scrollView)
        
        contentView = UIView()
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.01)
        scrollView.addSubview(contentView)
        
        self.titleBar = UIView()
        contentView.addSubview(self.titleBar)
        
        appIconView = UIImageView()
        appIconView.layer.cornerRadius = 3
        appIconView.layer.masksToBounds = true
        appIconView.backgroundColor = UIColor.clear
        contentView.addSubview(appIconView)
        
        appNameLabel = UILabel()
        contentView.addSubview(appNameLabel)
        
        dateLabel = UILabel()
        contentView.addSubview(dateLabel)
        
        bodyLabel = UILabel()
        bodyLabel.adjustsFontSizeToFitWidth = true
        contentView.addSubview(bodyLabel)
        
        self.lineViewTop = UIView()
        contentView.addSubview(self.lineViewTop)
        
        self.lineViewBottom = UIView()
        contentView.addSubview(self.lineViewBottom)
        
        slideLabel = UILabel()
        slideLabel.text = "slide to rate"
        contentView.addSubview(slideLabel)
        
        clearButton = ClearButton(frame: CGRect(x: 0, y: 0, width: 18, height: 18))
        clearButton.addTarget(self, action: #selector(RideNotificationView.pressedClearButton), for: UIControlEvents.touchUpInside)
        contentView.addSubview(clearButton)
        
        let shareImage = UIImage(named: "Action.png")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        shareButton = UIButton(frame: CGRect(x: 0,y: 0,width: 47,height: 87))
        shareButton.backgroundColor = UIColor.white.withAlphaComponent(0.01)
        shareButton.setImage(shareImage, for: UIControlState())
        shareButton.addTarget(self, action: #selector(RideNotificationView.pressedShareButton), for: UIControlEvents.touchUpInside)
        contentView.addSubview(shareButton)
        
        controlsView = UIView()
        controlsView.backgroundColor = UIColor.clear
        controlsView.clipsToBounds = true
        scrollView.addSubview(controlsView)
        
        editButton = UIButton()
        editButton.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        editButton.titleLabel?.textAlignment = NSTextAlignment.center
        editButton.setTitleColor(UIColor.white, for: UIControlState())
        editButton.addTarget(self, action: #selector(RideNotificationView.pressedEditButton), for: UIControlEvents.touchUpInside)
        controlsView.addSubview(editButton)
        
        destructiveButton = UIButton()
        destructiveButton.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        destructiveButton.titleLabel?.textAlignment = NSTextAlignment.center
        destructiveButton.backgroundColor = ColorPallete.shared.badRed
        destructiveButton.setTitleColor(UIColor.white, for: UIControlState())
        destructiveButton.addTarget(self, action: #selector(RideNotificationView.pressedDestructiveButton), for: UIControlEvents.touchUpInside)
        controlsView.addSubview(destructiveButton)
        
        actionButton = UIButton()
        actionButton.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        actionButton.titleLabel?.textAlignment = NSTextAlignment.center
        actionButton.backgroundColor = ColorPallete.shared.transitBlue
        actionButton.setTitleColor(UIColor.white, for: UIControlState())
        actionButton.addTarget(self, action: #selector(RideNotificationView.pressedActionButton), for: UIControlEvents.touchUpInside)
        controlsView.addSubview(actionButton)
        
        reloadUI()
    }
    
    @objc func pressedEditButton() {
        delegate?.didTapEditButton?(self)
        self.hideControls()
    }
    
    @objc func pressedDestructiveButton() {
        delegate?.didTapDestructiveButton?(self)
        self.hideControls()
    }
    
    @objc func pressedActionButton() {
        delegate?.didTapActionButton?(self)
        self.hideControls()        
    }
    
    @objc func pressedClearButton() {
        delegate?.didTapClearButton?(self)
        self.hideControls()
    }
    
    @objc func pressedShareButton() {
        delegate?.didTapShareButton?(self)
    }
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    override func didMoveToSuperview() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.reloadUI()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        destructiveButton.isHidden = !self.showsDestructiveActionButon
        actionButton.isHidden = !self.showsActionButon
        editButton.isHidden = !self.showsEditButton
        shareButton.isHidden = !self.showsShareButon || self.style != .appStyle
        
        self.clearButton.frame = CGRect(x: self.bounds.width - self.clearButton.frame.size.width - 10, y: (self.bounds.height - self.clearButton.frame.size.height)/2.0, width: self.clearButton.frame.size.width, height: self.clearButton.frame.size.height)

        self.shareButton.frame = CGRect(x: self.bounds.width - self.shareButton.frame.size.width - 10, y: (self.bounds.height - self.shareButton.frame.size.height)/2.0, width: self.shareButton.frame.size.width, height: self.shareButton.frame.size.height)
        
        self.editButton.frame = CGRect(x: buttonOffsetX, y: 0, width: buttonWidth, height: self.bounds.height)
        self.destructiveButton.frame = CGRect(x: self.totalButtonWidth - 2 * buttonWidth, y: 0, width: buttonWidth, height: self.bounds.height)
        self.actionButton.frame = CGRect(x: self.totalButtonWidth - buttonWidth, y: 0, width: buttonWidth, height: self.bounds.height)
        
        self.lineViewTop.frame = CGRect(x: insetX, y: 0.0, width: self.bounds.width + self.totalButtonWidth, height: 1.0)
        self.lineViewBottom.frame = CGRect(x: insetX, y: self.bounds.height - 1, width: self.bounds.width + self.totalButtonWidth, height: 1.0)
        
        self.titleBar.frame = CGRect(x: 0, y: 0.0, width: self.bounds.width, height: 30)
                
        self.scrollView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.scrollView.contentSize = CGSize(width: self.bounds.width + self.totalButtonWidth, height: self.bounds.height)
        
        self.controlsView.frame = CGRect(x: scrollView.contentOffset.x + self.bounds.width - self.totalButtonWidth, y: 0, width: self.isShowingControls ? self.totalButtonWidth : 0, height: self.bounds.height)
        self.contentView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
    }
    
    private var buttonOffsetX : CGFloat {
        get {
            if #available(iOS 10.0, *) {
                return 6
            }
            return 0
        }
    }
    
    private var totalButtonWidth : CGFloat {
        get {
            if (self.showsEditButton && self.showsActionButon && self.showsDestructiveActionButon) {
                return buttonWidth * 3 + buttonOffsetX
            } else if (self.showsEditButton && self.showsActionButon) {
                return buttonWidth * 2 + buttonOffsetX
            } else if (self.showsEditButton && self.showsDestructiveActionButon) {
                return buttonWidth * 2 + buttonOffsetX
            } else if (self.showsDestructiveActionButon && self.showsActionButon) {
                return buttonWidth * 2 + buttonOffsetX
            }
            
            return buttonWidth + buttonOffsetX
        }
    }
    
    func reloadUI() {
        var textColor = ColorPallete.shared.almostWhite
        if #available(iOS 10.0, *) {
            textColor = UIColor.black
        }
        
        appNameLabel.textColor = textColor
        dateLabel.textColor = textColor.withAlphaComponent(0.4)
        bodyLabel.textColor = textColor
        self.lineViewTop.backgroundColor = textColor.withAlphaComponent(0.2)
        self.titleBar.isHidden = true
        self.lineViewBottom.backgroundColor = textColor.withAlphaComponent(0.2)
        slideLabel.textColor = textColor.withAlphaComponent(0.4)
        shareButton.tintColor = textColor
        
        destructiveButton.setTitle(self.desturctiveActionTitle, for: UIControlState())
        actionButton.setTitle(self.actionTitle, for: UIControlState())
        editButton.setTitle(self.editTitle, for: UIControlState())
        editButton.backgroundColor = ColorPallete.shared.darkGrey
        
        appNameLabel.text = self.appName
        dateLabel.text = self.dateString
        bodyLabel.text = self.body
        appIconView.image = self.appIcon
        
        if self.style == .lockScreenStyle && self.bounds.height < 100 {
            self.appNameLabel.font = UIFont.systemFont(ofSize: 15)
            self.bodyLabel.font = UIFont.systemFont(ofSize: 12)
            self.dateLabel.font = UIFont.systemFont(ofSize: 11)
            self.slideLabel.font = UIFont.systemFont(ofSize: 11)
            
            self.editButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            self.actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            self.destructiveButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            
            self.bodyLabel.minimumScaleFactor = 0.6
            self.bodyLabel.numberOfLines = 2
            self.bodyLabel.lineBreakMode = NSLineBreakMode.byTruncatingTail
        } else {
            appNameLabel.font = UIFont.boldSystemFont(ofSize: 18)
            dateLabel.font = UIFont.systemFont(ofSize: 16)
            bodyLabel.font = UIFont.systemFont(ofSize: 18)
            slideLabel.font = UIFont.systemFont(ofSize: 14)
            
            editButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            destructiveButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            
            bodyLabel.minimumScaleFactor = 1.0
            bodyLabel.numberOfLines = 0
            bodyLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        }

        
        var insetLeft : CGFloat = 46
        var insetLeftBody : CGFloat = 46
        let insetRight : CGFloat = 4
        var insetY : CGFloat = 8
        var bodySpacingY : CGFloat = 0
        
        var appNameSize = appNameLabel.text!.size(withAttributes: [NSAttributedStringKey.font: appNameLabel.font])
        var bodySizeOffset: CGFloat = 0
        var dateLabelOffsetX: CGFloat = 0
        var dateLabelOffsetY: CGFloat = 0
        
        switch self.style {
        case .appStyle:
            insetLeft = 8
            insetLeftBody = 8
            insetY = 2
            appNameSize = CGSize(width: 0, height: appNameSize.height + 2)
            
            self.appNameLabel.isHidden = true
            self.appIconView.isHidden = true
            self.slideLabel.isHidden = true
            self.lineViewTop.isHidden = true
            self.lineViewBottom.isHidden = true
            self.clearButton.isHidden = true
            self.shareButton.isHidden = false
            bodySizeOffset = 30
        case .lockScreenStyle:
            if #available(iOS 10.0, *) {
                insetX = 6
                insetY = 6
                insetLeft = 36
                insetLeftBody = 8
                bodySpacingY = 14
                self.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.55)
                self.titleBar.backgroundColor = UIColor.white.withAlphaComponent(0.6)
                editButton.backgroundColor = UIColor.white.withAlphaComponent(0.55)
                self.editButton.layer.cornerRadius = 10
                self.contentView.layer.cornerRadius = 10
                self.contentView.clipsToBounds = true
                self.lineViewTop.isHidden = true
                self.lineViewBottom.isHidden = true
                self.titleBar.isHidden = false
                self.slideLabel.isHidden = true
            } else {
                self.layer.cornerRadius = 0
                self.lineViewTop.isHidden = false
                self.lineViewBottom.isHidden = false
                self.slideLabel.isHidden = false
            }
            self.appNameLabel.isHidden = false
            self.appIconView.isHidden = false
            self.clearButton.isHidden = true
            self.shareButton.isHidden = true
            dateLabelOffsetX = 6
        case .shareStyle:
            insetLeft = 8
            insetLeftBody = 8
            insetY = 4
            
            self.appNameLabel.isHidden = false
            self.appIconView.isHidden = true
            self.slideLabel.isHidden = true
            self.lineViewTop.isHidden = true
            self.lineViewBottom.isHidden = true
            self.clearButton.isHidden = true
            self.shareButton.isHidden = true
            dateLabelOffsetX = 8
            dateLabelOffsetY = 1
        }
        
        let dateLabelSize = dateLabel.text!.size(withAttributes: [NSAttributedStringKey.font: dateLabel.font])
        let bodySize = bodyLabel.text!.boundingRect(with: CGSize(width: self.bounds.width - insetLeftBody - insetRight - bodySizeOffset, height: self.bounds.height - insetY - appNameSize.height), options: [NSStringDrawingOptions.usesLineFragmentOrigin, NSStringDrawingOptions.truncatesLastVisibleLine], attributes:[NSAttributedStringKey.font: bodyLabel.font], context: nil).size
        
        appIconView.frame = CGRect(x: insetX, y: insetY, width: 20, height: 20)
        appNameLabel.frame = CGRect(x: insetLeft, y: insetY, width: appNameSize.width, height: appNameSize.height)
        dateLabel.frame = CGRect(x: appNameSize.width + insetLeft + dateLabelOffsetX, y: insetY + dateLabelOffsetY, width: dateLabelSize.width, height: appNameSize.height)
        if self.style == .lockScreenStyle {
            if #available(iOS 10.0, *) {
                dateLabel.frame = CGRect(x: self.bounds.width - dateLabelSize.width - 8, y: insetY + dateLabelOffsetY, width: dateLabelSize.width, height: appNameSize.height)
            }
        }
        bodyLabel.frame = CGRect(x: insetLeftBody, y: insetY + bodySpacingY + appNameSize.height, width: bodySize.width, height: bodySize.height)
        slideLabel.frame = CGRect(x: insetLeftBody, y: bodyLabel.frame.origin.y + bodyLabel.frame.size.height + 2, width: self.bounds.width, height: 16)
        
        
        if (self.heightConstraint != nil) {
            self.removeConstraint(self.heightConstraint)
        }
        
        if self.style != .lockScreenStyle || self.bounds.height > 100 {
            self.bodyLabel.sizeToFit()
            let newHeight = self.bodyLabel.frame.height + self.bodyLabel.frame.origin.y + 5
            self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width, height: newHeight)
            
            self.heightConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: newHeight)
            self.addConstraint(self.heightConstraint)
            self.setNeedsDisplay()
        }
    }
    
    func showControls(_ animated: Bool = true) {
        DispatchQueue.main.async(execute: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if (strongSelf.isShowingControls) {
                return
            }
            
            strongSelf.isShowingControls = true
            
            strongSelf.scrollView.setContentOffset(CGPoint(x: strongSelf.totalButtonWidth, y: 0), animated: animated)
            strongSelf.delegate?.didOpenControls?(strongSelf)
        })
    }
    
    func hideControls(_ animated: Bool = true) {
        if (!self.isShowingControls) {
            return
        }
        
        self.scrollView.setContentOffset(CGPoint.zero, animated: animated)
        if (self.style == .appStyle && self.showsShareButon) {
            self.shareButton.fadeIn()
        }
        self.isShowingControls = false
        delegate?.didCloseControls?(self)
    }

    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if (!allowsScrolling) {
            return
        }
        
        var offsetXThreshold = self.totalButtonWidth
        if (offsetXThreshold > self.buttonWidth*2) {
            // if there are more than two buttons, lower the threshold to make it easier to slide over to the buttons
            offsetXThreshold = self.buttonWidth*2
        }
        
        if scrollView.contentOffset.x > offsetXThreshold {
            targetContentOffset.pointee.x = self.totalButtonWidth
        } else {
            targetContentOffset.pointee = CGPoint.zero;
            
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                if (strongSelf.style == .appStyle && strongSelf.showsShareButon) {
                    strongSelf.shareButton.fadeIn()
                }
                
                scrollView.setContentOffset(CGPoint.zero, animated: true)
            })
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (!allowsScrolling) {
            return
        }
        
        if (scrollView.contentOffset.x < 0) {
            scrollView.contentOffset = CGPoint.zero
        }
        
        if (scrollView.contentOffset.x >= self.totalButtonWidth) {
            self.controlsView.frame = CGRect(x: scrollView.contentOffset.x + self.bounds.width - self.totalButtonWidth, y: 0, width: self.totalButtonWidth, height: self.bounds.height)
        } else {
            self.controlsView.frame = CGRect(x: self.bounds.width, y: 0, width: scrollView.contentOffset.x, height: self.bounds.height)
        }
        
        if (scrollView.contentOffset.x >= self.totalButtonWidth) {
            if !self.isShowingControls {
                self.isShowingControls = true
                delegate?.didOpenControls?(self)
                if (!self.shareButton.isHidden) {
                    self.shareButton.fadeOut()
                }
            }
        } else if (scrollView.contentOffset.x == 0) {
            if self.isShowingControls {
                self.isShowingControls = false
                delegate?.didCloseControls?(self)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        didFireDeepTouchForTouchEvent = false
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        if (didFireDeepTouchForTouchEvent) {
            return
        }
        
        if let touch = touches.first {
            if #available(iOS 9.0, *) {
                if touch.force/touch.maximumPossibleForce > 0.7 {
                    didFireDeepTouchForTouchEvent = true
                    if #available(iOS 10.0, *) {
                        UIImpactFeedbackGenerator().impactOccurred()
                    } else {
                        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                    }
                    delegate?.didDeepTouchSummaryView?(self)
                }
            }
        }
    }

}
