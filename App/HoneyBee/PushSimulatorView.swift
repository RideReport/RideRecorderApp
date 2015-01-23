//
//  PushSimulatorView.swift
//  HoneyBee
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@objc protocol PushSimulatorViewDelegate {
    optional func didOpenControls(view: PushSimulatorView)
    optional func didCloseControls(view: PushSimulatorView)
    optional func didTapDestructiveButton(view: PushSimulatorView)
    optional func didTapActionButton(view: PushSimulatorView)
}

@IBDesignable class PushSimulatorView : UIView, UIScrollViewDelegate {
    
    @IBInspectable var body: NSString = "Lorem ipsum dolor sit amet" {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var appName: NSString = "Ride" {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var appIcon: UIImage? = nil {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var desturctiveActionTitle: NSString = "Delete" {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var actionTitle: NSString = "View" {
        didSet {
            reloadUI()
        }
    }
    
    let buttonWidth : CGFloat = 75.0
    
    var delegate : PushSimulatorViewDelegate? = nil
    
    var isShowingControls = false
    
    var scrollView : UIScrollView!
    var controlsView : UIView!
    var destructiveButton : UIButton!
    var actionButton : UIButton!
    
    var contentView : UIView!
    var appNameLabel : UILabel!
    var dateLabel : UILabel!
    var bodyLabel : UILabel!
    var slideLabel : UILabel!
    
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
        scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
        scrollView.contentSize = CGSizeMake(self.bounds.width + buttonWidth*2, self.bounds.height)
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        self.addSubview(scrollView)
        
        controlsView = UIView(frame: CGRect(x: self.bounds.width - buttonWidth*2, y: 0, width: 0, height: self.bounds.height))
        controlsView.backgroundColor = UIColor.clearColor()
        controlsView.clipsToBounds = true
        scrollView.addSubview(controlsView)
        
        destructiveButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: self.bounds.height))
        destructiveButton.backgroundColor = UIColor.redColor()
        destructiveButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        destructiveButton.addTarget(self, action: "pressedDestructiveButton", forControlEvents: UIControlEvents.TouchUpInside)
        controlsView.addSubview(destructiveButton)
        
        actionButton = UIButton(frame: CGRect(x: buttonWidth, y: 0, width: buttonWidth, height: self.bounds.height))
        actionButton.backgroundColor = UIColor.blueColor()
        actionButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        actionButton.addTarget(self, action: "pressedActionButton", forControlEvents: UIControlEvents.TouchUpInside)
        controlsView.addSubview(actionButton)
        
        contentView = UIView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
        contentView.backgroundColor = UIColor.clearColor()
        scrollView.addSubview(contentView)
        
        let insetX : CGFloat = 15
        
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
        
        let lineViewTop = UIView(frame: CGRectMake(insetX, 0.0, self.bounds.width, 1.0))
        lineViewTop.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.2)
        contentView.addSubview(lineViewTop)
        
        let lineViewBottom = UIView(frame: CGRectMake(insetX, self.bounds.height - 1, self.bounds.width, 1.0))
        lineViewBottom.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.2)
        contentView.addSubview(lineViewBottom)
        
        slideLabel = UILabel()
        slideLabel.font = UIFont.systemFontOfSize(14)
        slideLabel.textColor = UIColor.whiteColor().colorWithAlphaComponent(0.4)
        slideLabel.text = "slide to view"
        contentView.addSubview(slideLabel)
        
        reloadUI()
    }
    
    func pressedDestructiveButton() {
        delegate?.didTapDestructiveButton?(self)
    }
    
    func pressedActionButton() {
        delegate?.didTapActionButton?(self)
    }
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.scrollView.contentSize = CGSizeMake(self.bounds.width + 2*self.buttonWidth, self.bounds.height)
        self.scrollView.contentInset = UIEdgeInsetsZero
        
        self.scrollView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.controlsView.frame = CGRect(x: self.bounds.width - buttonWidth*2, y: 0, width: 0, height: self.bounds.height)
        self.contentView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        
        reloadUI()
    }
    
    func reloadUI() {
        destructiveButton.setTitle(self.desturctiveActionTitle, forState: UIControlState.Normal)
        actionButton.setTitle(self.actionTitle, forState: UIControlState.Normal)
        
        appNameLabel.text = self.appName
        dateLabel.text = "now"
        bodyLabel.text = self.body
        
        let insetX : CGFloat = 46
        let insetY : CGFloat = 8
        
        let appNameSize = appNameLabel.text!.sizeWithAttributes([NSFontAttributeName: appNameLabel.font])
        let bodySize = bodyLabel.text!.sizeWithAttributes([NSFontAttributeName: bodyLabel.font])
        
        appNameLabel.frame = CGRectMake(insetX, insetY, appNameSize.width, appNameSize.height)
        dateLabel.frame = CGRectMake(appNameSize.width + insetX + 6, insetY, 60.0, appNameSize.height)
        bodyLabel.frame = CGRectMake(insetX, insetY + appNameSize.height, self.bounds.width - (1.5*insetX), bodySize.height * 2)
        slideLabel.frame = CGRectMake(insetX, self.bounds.height - 28, self.bounds.width, 16)
    }

    
    func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView.contentOffset.x > (self.buttonWidth * 2) {
            targetContentOffset.memory.x = self.buttonWidth*2
        } else {
            targetContentOffset.memory = CGPointZero;
            
            dispatch_async(dispatch_get_main_queue(), {
                scrollView.setContentOffset(CGPointZero, animated: true)
            })
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (scrollView.contentOffset.x < 0) {
            scrollView.contentOffset = CGPointZero
        }
        
        if (scrollView.contentOffset.x > self.buttonWidth*2) {
            self.controlsView.frame = CGRectMake(scrollView.contentOffset.x + self.bounds.width - 2*self.buttonWidth, 0, self.buttonWidth*2, self.bounds.height)
        } else {
            self.controlsView.frame = CGRectMake(self.bounds.width, 0, scrollView.contentOffset.x, self.bounds.height)
        }
        
        if (scrollView.contentOffset.x >= self.buttonWidth*2) {
            if !self.isShowingControls {
                self.isShowingControls = true
                delegate?.didOpenControls?(self)
            }
        } else if (scrollView.contentOffset.x == 0) {
            if self.isShowingControls {
                self.isShowingControls = false
                delegate?.didCloseControls?(self)
            }
        }
    }

}