//
//  PopupView.swift
//  Ride Report
//
//  Created by William Henderson on 1/15/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@IBDesignable class PopupView : UIButton {
    
    @IBInspectable var strokeWidth: CGFloat = 2
    @IBInspectable var arrowHeight: CGFloat = 10
    @IBInspectable var arrowBaseWidth: CGFloat = 10
    @IBInspectable var cornerRadius: CGFloat = 10
    @IBInspectable var arrowInset: CGFloat = 10
    @IBInspectable var fontSize: CGFloat = 14
    @IBInspectable var strokeColor: UIColor = UIColor.darkGray
    @IBInspectable var fillColor: UIColor = UIColor.white
    @IBInspectable var text: String = "Popupview Text" {
        didSet {
            self.reloadView()
        }
    }
    
    private var textLabel : UILabel! = nil
    private var widthConstraint : NSLayoutConstraint! = nil
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
        self.textLabel = UILabel(frame: CGRect(x: 7, y: 20, width: self.frame.size.width, height: self.frame.size.height - 20))
        self.textLabel.textColor = UIColor.white
        self.textLabel.numberOfLines = 0
        self.textLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        self.textLabel.adjustsFontSizeToFitWidth = true
        self.textLabel.minimumScaleFactor = 0.4
        self.reloadView()
        self.addSubview(self.textLabel)
    }
    
    private func reloadView() {
        let rightHandBefore = self.frame.origin.x + self.frame.width
        self.textLabel.text = self.text
        self.textLabel.font = UIFont.systemFont(ofSize: self.fontSize)
        if let superview = self.superview {
            self.textLabel.frame.size.width = superview.frame.width - 30
        }
        self.textLabel.sizeToFit()
        
        let newWidth = self.textLabel.frame.width + 20
        let newHeight = self.textLabel.frame.height + 28
        self.frame = CGRect(x: rightHandBefore - newWidth, y: self.frame.origin.y, width: newWidth, height: newHeight)
        
        if (self.widthConstraint != nil) {
            self.removeConstraint(self.widthConstraint)
        }
        self.widthConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: newWidth)
        self.addConstraint(self.widthConstraint)
        
        if (self.heightConstraint != nil) {
            self.removeConstraint(self.heightConstraint)
        }
        self.heightConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: newHeight)
        self.addConstraint(self.heightConstraint)
        self.setNeedsDisplay()
    }
    
    override func didMoveToSuperview() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.reloadView()
        }
    }
    
    override func draw(_ rect: CGRect) {
        let smallerPath = CGRect(x: rect.origin.x + strokeWidth, y: arrowHeight + strokeWidth, width: rect.size.width - 2*strokeWidth, height: rect.size.height - arrowHeight - 2*strokeWidth)
        
        let path = UIBezierPath(roundedRect: smallerPath, cornerRadius: cornerRadius)
        
        fillColor.setFill()
        strokeColor.setStroke()
        
        path.lineWidth = strokeWidth
        path.stroke()
        
        if arrowHeight > 0 && arrowBaseWidth > 0 {
            let arrowPoint = CGPoint(x: arrowInset, y: arrowHeight + strokeWidth)
            let arrowPath = UIBezierPath()
            
            let halfArrowWidth = arrowBaseWidth / 2.0
            let tipPt = CGPoint(x: arrowPoint.x + halfArrowWidth, y: strokeWidth)
            let endPt = CGPoint(x: arrowPoint.x + arrowBaseWidth, y: arrowPoint.y)
            
            // Note: we always build the arrow path in a clockwise direction.
            // Arrow points towards top. We're starting from the left.
            
            arrowPath.move(to: arrowPoint)
            arrowPath.addLine(to: tipPt)
            arrowPath.addLine(to: endPt)
            arrowPath.lineCapStyle = CGLineCap.butt
            
            arrowPath.lineWidth = strokeWidth
            arrowPath.stroke()
            arrowPath.fill(with: CGBlendMode.clear, alpha:1.0)
            arrowPath.fill()
        }
        
        path.fill(with: CGBlendMode.clear, alpha:1.0)
        path.fill()
    }

}
