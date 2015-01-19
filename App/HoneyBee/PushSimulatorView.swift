//
//  PushSimulatorView.swift
//  HoneyBee
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@IBDesignable class PushSimulatorView : UIView, UIScrollViewDelegate {
    
    @IBInspectable var body: NSString = "Lorem ipsum dolor sit amet" {
        didSet {
            reloadUI()
        }
    }
    @IBInspectable var appName: NSString = "Lorem" {
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
    
    var scrollView : UIScrollView!
    var controlsView : UIView!
    var destructiveButton : UIButton!
    var actionButton : UIButton!
    
    var contentView : UIView!
    var appNameLabel : UILabel!
    
    
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
        
        appNameLabel = UILabel(frame: CGRectMake(10, 10, self.bounds.width, self.bounds.height))
        appNameLabel.textColor = UIColor.whiteColor()
        contentView.addSubview(appNameLabel)
        
        reloadUI()
    }
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.scrollView.contentSize = CGSizeMake(self.bounds.width + 2*self.buttonWidth, self.bounds.height)
        self.scrollView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.controlsView.frame = CGRect(x: self.bounds.width - buttonWidth*2, y: 0, width: 0, height: self.bounds.height)
        self.contentView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
    }
    
    func reloadUI() {
        destructiveButton.setTitle(self.desturctiveActionTitle, forState: UIControlState.Normal)
        actionButton.setTitle(self.actionTitle, forState: UIControlState.Normal)
        appNameLabel.text = self.appName
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
    }

}