//
//  RideSummaryView.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@objc protocol RideSummaryViewDelegate {
    optional func didOpenControls(view: RideSummaryView)
    optional func didCloseControls(view: RideSummaryView)
    optional func didTapEditButton(view: RideSummaryView)
    optional func didTapDestructiveButton(view: RideSummaryView)
    optional func didTapActionButton(view: RideSummaryView)
    optional func didTapClearButton(view: RideSummaryView)
    optional func didTapShareButton(view: RideSummaryView)
}

@IBDesignable class RideSummaryView : UIView, UIScrollViewDelegate {
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
    @IBInspectable var desturctiveActionTitle: String = "Not Great\n👎" {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var actionTitle: String = "Great!\n👍" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var editTitle: String = "Change\nMode" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var textColor: UIColor = ColorPallete.sharedPallete.almostWhite {
        didSet {
            reloadUI()
        }
    }
    
    enum RideSummaryViewStyle : NSInteger {
        case LockScreenStyle = 1
        case AppStyle
        case ShareStyle
    }
    
    @IBInspectable var interfaceStyle: NSInteger = 1 {
        didSet {
            if let newStyle = RideSummaryViewStyle(rawValue: self.interfaceStyle) {
                self.style = newStyle
            }
        }
    }
    
    var style: RideSummaryViewStyle = .LockScreenStyle {
        didSet {
            reloadUI()
        }
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
    
    let buttonWidth : CGFloat = 78.0
    
    weak var delegate : RideSummaryViewDelegate? = nil
    
    var isShowingControls = false
    
    let insetX : CGFloat = 15
    
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
    var lineViewBottom : UIView!
    
    var appIconView : UIImageView!
    
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
        contentView.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.01)
        scrollView.addSubview(contentView)
        
        appIconView = UIImageView(frame: CGRectMake(insetX, 10, 20, 20))
        appIconView.layer.cornerRadius = 3
        appIconView.layer.masksToBounds = true
        appIconView.backgroundColor = UIColor.clearColor()
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
        
        clearButton = ClearButton(frame: CGRectMake(0, 0, 18, 18))
        clearButton.addTarget(self, action: #selector(RideSummaryView.pressedClearButton), forControlEvents: UIControlEvents.TouchUpInside)
        contentView.addSubview(clearButton)
        
        let shareImage = UIImage(named: "Action.png")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        shareButton = UIButton(frame: CGRectMake(0,0,27,27))
        shareButton.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.01)
        shareButton.setImage(shareImage, forState: UIControlState.Normal)
        shareButton.addTarget(self, action: #selector(RideSummaryView.pressedShareButton), forControlEvents: UIControlEvents.TouchUpInside)
        contentView.addSubview(shareButton)
        
        controlsView = UIView()
        controlsView.backgroundColor = UIColor.clearColor()
        controlsView.clipsToBounds = true
        scrollView.addSubview(controlsView)
        
        editButton = UIButton()
        editButton.titleLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        editButton.titleLabel?.textAlignment = NSTextAlignment.Center
        editButton.backgroundColor = ColorPallete.sharedPallete.darkGrey
        editButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        editButton.addTarget(self, action: #selector(RideSummaryView.pressedEditButton), forControlEvents: UIControlEvents.TouchUpInside)
        controlsView.addSubview(editButton)
        
        destructiveButton = UIButton()
        destructiveButton.titleLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        destructiveButton.titleLabel?.textAlignment = NSTextAlignment.Center
        destructiveButton.backgroundColor = ColorPallete.sharedPallete.badRed
        destructiveButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        destructiveButton.addTarget(self, action: #selector(RideSummaryView.pressedDestructiveButton), forControlEvents: UIControlEvents.TouchUpInside)
        controlsView.addSubview(destructiveButton)
        
        actionButton = UIButton()
        actionButton.titleLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        actionButton.titleLabel?.textAlignment = NSTextAlignment.Center
        actionButton.backgroundColor = ColorPallete.sharedPallete.transitBlue
        actionButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        actionButton.addTarget(self, action: #selector(RideSummaryView.pressedActionButton), forControlEvents: UIControlEvents.TouchUpInside)
        controlsView.addSubview(actionButton)
        
        reloadUI()
    }
    
    func pressedEditButton() {
        delegate?.didTapEditButton?(self)
        self.hideControls()
    }
    
    func pressedDestructiveButton() {
        delegate?.didTapDestructiveButton?(self)
        self.hideControls()
    }
    
    func pressedActionButton() {
        delegate?.didTapActionButton?(self)
        self.hideControls()        
    }
    
    func pressedClearButton() {
        delegate?.didTapClearButton?(self)
        self.hideControls()
    }
    
    func pressedShareButton() {
        delegate?.didTapShareButton?(self)
    }
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    override func didMoveToSuperview() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.reloadUI()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        destructiveButton.hidden = !self.showsDestructiveActionButon
        actionButton.hidden = !self.showsActionButon
        editButton.hidden = !self.showsEditButton
        shareButton.hidden = !self.showsShareButon || self.style != .AppStyle
        
        self.clearButton.frame = CGRect(x: self.bounds.width - self.clearButton.frame.size.width - 10, y: (self.bounds.height - self.clearButton.frame.size.height)/2.0, width: self.clearButton.frame.size.width, height: self.clearButton.frame.size.height)

        self.shareButton.frame = CGRect(x: self.bounds.width - self.shareButton.frame.size.width - 10, y: (self.bounds.height - self.shareButton.frame.size.height)/2.0, width: self.shareButton.frame.size.width, height: self.shareButton.frame.size.height)
        
        self.editButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: self.bounds.height)
        self.destructiveButton.frame = CGRect(x: self.totalButtonWidth - 2 * buttonWidth, y: 0, width: buttonWidth, height: self.bounds.height)
        self.actionButton.frame = CGRect(x: self.totalButtonWidth - buttonWidth, y: 0, width: buttonWidth, height: self.bounds.height)
        
        self.lineViewTop.frame = CGRectMake(insetX, 0.0, self.bounds.width + self.totalButtonWidth, 1.0)
        self.lineViewBottom.frame = CGRectMake(insetX, self.bounds.height - 1, self.bounds.width + self.totalButtonWidth, 1.0)
                
        self.scrollView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.scrollView.contentSize = CGSizeMake(self.bounds.width + self.totalButtonWidth, self.bounds.height)
        
        self.controlsView.frame = CGRect(x: scrollView.contentOffset.x + self.bounds.width - self.totalButtonWidth, y: 0, width: self.isShowingControls ? self.totalButtonWidth : 0, height: self.bounds.height)
        self.contentView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
    }
    
    private var totalButtonWidth : CGFloat {
        get {
            if (self.showsEditButton && self.showsActionButon && self.showsDestructiveActionButon) {
                return buttonWidth * 3
            } else if (self.showsEditButton && self.showsActionButon) {
                return buttonWidth * 2
            } else if (self.showsEditButton && self.showsDestructiveActionButon) {
                return buttonWidth * 2
            } else if (self.showsDestructiveActionButon && self.showsActionButon) {
                return buttonWidth * 2
            }
            
            return buttonWidth
        }
    }
    
    func reloadUI() {
        appNameLabel.textColor = self.textColor
        dateLabel.textColor = self.textColor.colorWithAlphaComponent(0.4)
        bodyLabel.textColor = self.textColor
        self.lineViewTop.backgroundColor = self.textColor.colorWithAlphaComponent(0.2)
        self.lineViewBottom.backgroundColor = self.textColor.colorWithAlphaComponent(0.2)
        slideLabel.textColor = self.textColor.colorWithAlphaComponent(0.4)
        shareButton.tintColor = self.textColor
        
        destructiveButton.setTitle(self.desturctiveActionTitle, forState: UIControlState.Normal)
        actionButton.setTitle(self.actionTitle, forState: UIControlState.Normal)
        editButton.setTitle(self.editTitle, forState: UIControlState.Normal)
        
        appNameLabel.text = self.appName
        dateLabel.text = self.dateString
        bodyLabel.text = self.body
        appIconView.image = self.appIcon
        
        if self.style == .LockScreenStyle && self.bounds.height < 100 {
            self.appNameLabel.font = UIFont.systemFontOfSize(15)
            self.bodyLabel.font = UIFont.systemFontOfSize(12)
            self.dateLabel.font = UIFont.systemFontOfSize(11)
            self.slideLabel.font = UIFont.systemFontOfSize(11)
            
            self.editButton.titleLabel?.font = UIFont.systemFontOfSize(13.0)
            self.actionButton.titleLabel?.font = UIFont.systemFontOfSize(13.0)
            self.destructiveButton.titleLabel?.font = UIFont.systemFontOfSize(13.0)
            
            self.bodyLabel.minimumScaleFactor = 0.6
            self.bodyLabel.numberOfLines = 2
            self.bodyLabel.lineBreakMode = NSLineBreakMode.ByTruncatingTail
        } else {
            appNameLabel.font = UIFont.boldSystemFontOfSize(18)
            dateLabel.font = UIFont.systemFontOfSize(16)
            bodyLabel.font = UIFont.systemFontOfSize(18)
            slideLabel.font = UIFont.systemFontOfSize(14)
            
            editButton.titleLabel?.font = UIFont.systemFontOfSize(13.0)
            actionButton.titleLabel?.font = UIFont.systemFontOfSize(13.0)
            destructiveButton.titleLabel?.font = UIFont.systemFontOfSize(13.0)
            
            bodyLabel.minimumScaleFactor = 1.0
            bodyLabel.numberOfLines = 0
            bodyLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        }

        
        var insetLeft : CGFloat = 46
        let insetRight : CGFloat = 4
        var insetY : CGFloat = 8
        
        var appNameSize = appNameLabel.text!.sizeWithAttributes([NSFontAttributeName: appNameLabel.font])
        var bodySizeOffset: CGFloat = 0
        var dateLabelOffsetX: CGFloat = 0
        var dateLabelOffsetY: CGFloat = 0
        
        switch self.style {
        case .AppStyle:
            insetLeft = 8
            insetY = 2
            appNameSize = CGSizeMake(0, appNameSize.height + 2)
            
            self.appNameLabel.hidden = true
            self.appIconView.hidden = true
            self.slideLabel.hidden = true
            self.lineViewTop.hidden = true
            self.lineViewBottom.hidden = true
            self.clearButton.hidden = true
            self.shareButton.hidden = false
            bodySizeOffset = 30
        case .LockScreenStyle:
            self.appNameLabel.hidden = false
            self.appIconView.hidden = false
            self.slideLabel.hidden = false
            self.lineViewTop.hidden = false
            self.lineViewBottom.hidden = false
            self.clearButton.hidden = true
            self.shareButton.hidden = true
            dateLabelOffsetX = 6
        case .ShareStyle:
            insetLeft = 8
            insetY = 4
            
            self.appNameLabel.hidden = false
            self.appIconView.hidden = true
            self.slideLabel.hidden = true
            self.lineViewTop.hidden = true
            self.lineViewBottom.hidden = true
            self.clearButton.hidden = true
            self.shareButton.hidden = true
            dateLabelOffsetX = 8
            dateLabelOffsetY = 1
        }
        
        let dateLabelSize = dateLabel.text!.sizeWithAttributes([NSFontAttributeName: dateLabel.font])
        let bodySize = bodyLabel.text!.boundingRectWithSize(CGSizeMake(self.bounds.width - insetLeft - insetRight - bodySizeOffset, self.bounds.height - insetY - appNameSize.height), options: [NSStringDrawingOptions.UsesLineFragmentOrigin, NSStringDrawingOptions.TruncatesLastVisibleLine], attributes:[NSFontAttributeName: bodyLabel.font], context: nil).size
        
        appNameLabel.frame = CGRectMake(insetLeft, insetY, appNameSize.width, appNameSize.height)
        dateLabel.frame = CGRectMake(appNameSize.width + insetLeft + dateLabelOffsetX, insetY + dateLabelOffsetY, dateLabelSize.width, appNameSize.height)
        bodyLabel.frame = CGRectMake(insetLeft, insetY + appNameSize.height, bodySize.width, bodySize.height)
        slideLabel.frame = CGRectMake(insetLeft, bodyLabel.frame.origin.y + bodyLabel.frame.size.height + 2, self.bounds.width, 16)
        
        
        if (self.heightConstraint != nil) {
            self.removeConstraint(self.heightConstraint)
        }
        
        if self.style != .LockScreenStyle || self.bounds.height > 100 {
            self.bodyLabel.sizeToFit()
            let newHeight = self.bodyLabel.frame.height + self.bodyLabel.frame.origin.y + 5
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, newHeight)
            
            self.heightConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1.0, constant: newHeight)
            self.addConstraint(self.heightConstraint)
            self.setNeedsDisplay()
        }
    }
    
    func showControls(animated: Bool = true) {
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if (strongSelf.isShowingControls) {
                return
            }
            
            strongSelf.isShowingControls = true
            
            strongSelf.scrollView.setContentOffset(CGPointMake(strongSelf.totalButtonWidth, 0), animated: animated)
            strongSelf.delegate?.didOpenControls?(strongSelf)
        })
    }
    
    func hideControls(animated: Bool = true) {
        if (!self.isShowingControls) {
            return
        }
        
        self.scrollView.setContentOffset(CGPointZero, animated: animated)
        if (self.style == .AppStyle && self.showsShareButon) {
            self.shareButton.fadeIn()
        }
        self.isShowingControls = false
        delegate?.didCloseControls?(self)
    }

    
    func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        var offsetXThreshold = self.totalButtonWidth
        if (offsetXThreshold > self.buttonWidth*2) {
            // if there are more than two buttons, lower the threshold to make it easier to slide over to the buttons
            offsetXThreshold = self.buttonWidth*2
        }
        
        if scrollView.contentOffset.x > offsetXThreshold {
            targetContentOffset.memory.x = self.totalButtonWidth
        } else {
            targetContentOffset.memory = CGPointZero;
            
            dispatch_async(dispatch_get_main_queue(), { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                if (strongSelf.style == .AppStyle && strongSelf.showsShareButon) {
                    strongSelf.shareButton.fadeIn()
                }
                
                scrollView.setContentOffset(CGPointZero, animated: true)
            })
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (scrollView.contentOffset.x < 0) {
            scrollView.contentOffset = CGPointZero
        }
        
        if (scrollView.contentOffset.x >= self.totalButtonWidth) {
            self.controlsView.frame = CGRectMake(scrollView.contentOffset.x + self.bounds.width - self.totalButtonWidth, 0, self.totalButtonWidth, self.bounds.height)
        } else {
            self.controlsView.frame = CGRectMake(self.bounds.width, 0, scrollView.contentOffset.x, self.bounds.height)
        }
        
        if (scrollView.contentOffset.x >= self.totalButtonWidth) {
            if !self.isShowingControls {
                self.isShowingControls = true
                delegate?.didOpenControls?(self)
                if (!self.shareButton.hidden) {
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

}