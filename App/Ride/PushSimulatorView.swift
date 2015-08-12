//
//  PushSimulatorView.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@objc protocol PushSimulatorViewDelegate {
    optional func didOpenControls(view: PushSimulatorView)
    optional func didCloseControls(view: PushSimulatorView)
    optional func didTapEditButton(view: PushSimulatorView)
    optional func didTapDestructiveButton(view: PushSimulatorView)
    optional func didTapActionButton(view: PushSimulatorView)
    optional func didTapClearButton(view: PushSimulatorView)
}

@IBDesignable class PushSimulatorView : UIView, UIScrollViewDelegate {
    
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
    @IBInspectable var desturctiveActionTitle: String = "Delete" {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var actionTitle: String = "View" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var editTitle: String = "Edit" {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var isInAppView: Bool = false {
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
    
    let buttonWidth : CGFloat = 75.0
    
    var delegate : PushSimulatorViewDelegate? = nil
    
    var isShowingControls = false
    
    let insetX : CGFloat = 15
    
    var scrollView : UIScrollView!
    var controlsView : UIView!
    var destructiveButton : UIButton!
    var actionButton : UIButton!
    var editButton : UIButton!
    var clearButton : UIVisualEffectView!
    
    var contentView : UIView!
    var appNameLabel : UILabel!
    var dateLabel : UILabel!
    var bodyLabel : UILabel!
    var slideLabel : UILabel!
    
    var lineViewTop : UIView!
    var lineViewBottom : UIView!
    
    var appIconView : UIImageView!
    
    
    required init(coder aDecoder: NSCoder) {
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
        contentView.backgroundColor = UIColor.clearColor()
        scrollView.addSubview(contentView)
        
        appIconView = UIImageView(frame: CGRectMake(insetX, 10, 20, 20))
        appIconView.backgroundColor = UIColor.redColor()
        contentView.addSubview(appIconView)
        
        appNameLabel = UILabel()
        appNameLabel.font = UIFont.boldSystemFontOfSize(18)
        appNameLabel.textColor = UIColor.whiteColor()
        contentView.addSubview(appNameLabel)
        
        dateLabel = UILabel()
        dateLabel.font = UIFont.systemFontOfSize(14)
        dateLabel.textColor = UIColor.whiteColor().colorWithAlphaComponent(0.4)
        contentView.addSubview(dateLabel)
        
        bodyLabel = UILabel()
        bodyLabel.font = UIFont.systemFontOfSize(16)
        bodyLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        bodyLabel.numberOfLines = 2
        bodyLabel.textColor = UIColor.whiteColor()
        contentView.addSubview(bodyLabel)
        
        self.lineViewTop = UIView()
        self.lineViewTop.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.2)
        contentView.addSubview(self.lineViewTop)
        
        self.lineViewBottom = UIView()
        self.lineViewBottom.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.2)
        contentView.addSubview(self.lineViewBottom)
        
        slideLabel = UILabel()
        slideLabel.font = UIFont.systemFontOfSize(14)
        slideLabel.textColor = UIColor.whiteColor().colorWithAlphaComponent(0.4)
        slideLabel.text = "slide to rate"
        contentView.addSubview(slideLabel)
        
        clearButton = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.ExtraLight))
        let clearButtonRect = CGRectMake(0, 0, 18, 18)
        UIGraphicsBeginImageContextWithOptions(clearButtonRect.size, false, 0.0)
        let circle = UIBezierPath(ovalInRect: clearButtonRect)
        let line1 = UIBezierPath()
        line1.moveToPoint(CGPointMake(6, 6))
        line1.addLineToPoint(CGPointMake(12, 12))
        line1.lineWidth = 1
        let line2 = UIBezierPath()
        line2.moveToPoint(CGPointMake(6, 12))
        line2.addLineToPoint(CGPointMake(12, 6))
        line2.lineWidth = 1
        
        UIColor.blackColor().setFill()
        circle.fill()
        let ctx = UIGraphicsGetCurrentContext()
        CGContextSetBlendMode(ctx, kCGBlendModeDestinationOut)
        line1.stroke()
        line2.stroke()
        let maskImage = UIGraphicsGetImageFromCurrentImageContext().imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal)
        UIGraphicsEndImageContext()
        let maskLayer = CALayer()
        maskLayer.contentsScale = maskImage.scale
        maskLayer.frame = clearButtonRect
        maskLayer.contents = maskImage.CGImage
        clearButton.frame = clearButtonRect
        clearButton.layer.mask = maskLayer
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "pressedClearButton")
        clearButton.addGestureRecognizer(tapRecognizer)
        contentView.addSubview(clearButton)
        
        controlsView = UIView()
        controlsView.backgroundColor = UIColor.clearColor()
        controlsView.clipsToBounds = true
        scrollView.addSubview(controlsView)
        
        editButton = UIButton()
        editButton.titleLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        editButton.titleLabel?.textAlignment = NSTextAlignment.Center
        editButton.titleLabel?.font = UIFont.systemFontOfSize(16.0)
        editButton.backgroundColor = ColorPallete.sharedPallete.notificationActionGrey
        editButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        editButton.addTarget(self, action: "pressedEditButton", forControlEvents: UIControlEvents.TouchUpInside)
        controlsView.addSubview(editButton)
        
        destructiveButton = UIButton()
        destructiveButton.titleLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        destructiveButton.titleLabel?.textAlignment = NSTextAlignment.Center
        destructiveButton.titleLabel?.font = UIFont.systemFontOfSize(16.0)
        destructiveButton.backgroundColor = ColorPallete.sharedPallete.notificationDestructiveActionRed
        destructiveButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        destructiveButton.addTarget(self, action: "pressedDestructiveButton", forControlEvents: UIControlEvents.TouchUpInside)
        controlsView.addSubview(destructiveButton)
        
        actionButton = UIButton()
        actionButton.titleLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        actionButton.titleLabel?.textAlignment = NSTextAlignment.Center
        actionButton.titleLabel?.font = UIFont.systemFontOfSize(16.0)
        actionButton.backgroundColor = ColorPallete.sharedPallete.notificationActionBlue
        actionButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        actionButton.addTarget(self, action: "pressedActionButton", forControlEvents: UIControlEvents.TouchUpInside)
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
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        destructiveButton.hidden = !self.showsDestructiveActionButon
        actionButton.hidden = !self.showsActionButon
        editButton.hidden = !self.showsEditButton
        
        self.contentView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.controlsView.frame = CGRect(x: self.bounds.width - self.totalButtonWidth, y: 0, width: 0, height: self.bounds.height)

        self.clearButton.frame = CGRect(x: self.bounds.width - self.clearButton.frame.size.width - 10, y: (self.bounds.height - self.clearButton.frame.size.height)/2.0, width: self.clearButton.frame.size.width, height: self.clearButton.frame.size.height)
        
        self.editButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: self.bounds.height)
        self.destructiveButton.frame = CGRect(x: self.totalButtonWidth - 2 * buttonWidth, y: 0, width: buttonWidth, height: self.bounds.height)
        self.actionButton.frame = CGRect(x: self.totalButtonWidth - buttonWidth, y: 0, width: buttonWidth, height: self.bounds.height)
        
        self.lineViewTop.frame = CGRectMake(insetX, 0.0, self.bounds.width + self.totalButtonWidth, 1.0)
        self.lineViewBottom.frame = CGRectMake(insetX, self.bounds.height - 1, self.bounds.width + self.totalButtonWidth, 1.0)
                
        self.scrollView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.scrollView.contentSize = CGSizeMake(self.bounds.width + self.totalButtonWidth, self.bounds.height)
        
        self.controlsView.frame = CGRect(x: self.bounds.width - self.totalButtonWidth, y: 0, width: 0, height: self.bounds.height)
        self.contentView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        
        reloadUI()
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
        destructiveButton.setTitle(self.desturctiveActionTitle, forState: UIControlState.Normal)
        actionButton.setTitle(self.actionTitle, forState: UIControlState.Normal)
        editButton.setTitle(self.editTitle, forState: UIControlState.Normal)
        
        appNameLabel.text = self.appName
        dateLabel.text = self.dateString
        bodyLabel.text = self.body
        
        var insetX : CGFloat = 46
        var insetY : CGFloat = 8
        
        var appNameSize = appNameLabel.text!.sizeWithAttributes([NSFontAttributeName: appNameLabel.font])
        
        if (self.isInAppView) {
            insetX = 8
            insetY = 2
            appNameSize = CGSizeMake(0, appNameSize.height + 2)
            
            self.appNameLabel.hidden = true
            self.appIconView.hidden = true
            self.slideLabel.hidden = true
            self.lineViewTop.hidden = true
            self.lineViewBottom.hidden = true
            self.clearButton.hidden = false
        } else {
            self.appNameLabel.hidden = false
            self.appIconView.hidden = false
            self.slideLabel.hidden = false
            self.lineViewTop.hidden = false
            self.lineViewBottom.hidden = false
            self.clearButton.hidden = true
        }
        
        var dateLabelSize = dateLabel.text!.sizeWithAttributes([NSFontAttributeName: dateLabel.font])
        let bodySize = bodyLabel.text!.boundingRectWithSize(CGSizeMake(self.bounds.width - (1.5*insetX) - (self.isInAppView ? 20 : 0), self.bounds.height - insetY - appNameSize.height), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes:[NSFontAttributeName: bodyLabel.font], context: nil).size
        
        appNameLabel.frame = CGRectMake(insetX, insetY, appNameSize.width, appNameSize.height)
        dateLabel.frame = CGRectMake(appNameSize.width + insetX + (self.isInAppView ? 0 : 6), insetY, dateLabelSize.width, appNameSize.height)
        bodyLabel.frame = CGRectMake(insetX, insetY + appNameSize.height, bodySize.width, bodySize.height)
        slideLabel.frame = CGRectMake(insetX, self.bounds.height - 28, self.bounds.width, 16)
    }
    
    func showControls(animated: Bool = true) {
        dispatch_async(dispatch_get_main_queue(), {
            self.scrollView.setContentOffset(CGPointMake(self.totalButtonWidth, 0), animated: animated)
        })
        self.isShowingControls = true
        delegate?.didOpenControls?(self)
    }
    
    func hideControls(animated: Bool = true) {
        self.scrollView.setContentOffset(CGPointZero, animated: animated)
        if (self.isInAppView) {
            self.clearButton.fadeIn()
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
            
            dispatch_async(dispatch_get_main_queue(), {
                if (self.isInAppView) {
                    self.clearButton.fadeIn()
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
                if (!self.clearButton.hidden) {
                    self.clearButton.fadeOut()
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