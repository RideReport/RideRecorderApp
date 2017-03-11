//
//  RatingChoiceSelectorView
//  Ride
//
//  Created by William Henderson on 3/8/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

//
//  ModeSelectorView.swift
//  Ride
//
//  Created by William Henderson on 3/30/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

@IBDesignable class RatingChoiceSelectorView : UIControl {
    let displayedRatingChoices = [RatingChoice.Bad, RatingChoice.Mixed, RatingChoice.Good]
    
    private var feedbackGenerator: NSObject!
    
    private var ratingButtons: [UIButton]! = []
    
    private var selectedRatingButtonIndex: Int {
        for (i, button) in ratingButtons.enumerate() {
            if button.selected {
                return i
            }
        }
        
        return -1
    }
    
    var selectedRating: RatingChoice {
        get {
            let selectedIndex = self.selectedRatingButtonIndex
            guard selectedIndex != -1 else {
                return .NotSet
            }
            
            guard selectedIndex < displayedRatingChoices.count else {
                return .NotSet
            }
            
            return displayedRatingChoices[selectedIndex]
        }
        
        set {
            for button in ratingButtons {
                button.selected = false
            }
            
            if (newValue == .NotSet) {
                return
            }
            
            guard let choiceIndex = displayedRatingChoices.indexOf(newValue) else {
                return
            }
            
            guard choiceIndex != -1 else {
                return
            }
            
            guard choiceIndex < ratingButtons.count else {
                return
            }
            
            ratingButtons[choiceIndex].selected = true
        }
    }
    
    
    @IBInspectable var emojiFontSize: CGFloat = 40.0 {
        didSet {
            reloadUI()
        }
    }
    
    @IBInspectable var descriptionFontSize: CGFloat = 40.0 {
        didSet {
            reloadUI()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !self.hidden {
            reloadUI()
        }
    }
    
    
    func commonInit() {
        self.addTarget(self, action: #selector(RatingChoiceSelectorView.selectionDidChange), forControlEvents: UIControlEvents.ValueChanged)
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.backgroundColor = UIColor.clearColor()

        
        for (i, _) in self.displayedRatingChoices.enumerate() {
            let choiceButton = UIButton(type: UIButtonType.Custom)
            
            choiceButton.addTarget(self, action: #selector(RatingChoiceSelectorView.buttonTapped(_:)), forControlEvents: UIControlEvents.TouchUpInside)
            
            choiceButton.backgroundColor = UIColor.clearColor()
            self.addSubview(choiceButton)
            
            choiceButton.translatesAutoresizingMaskIntoConstraints = false
            
            let heightConstraint = NSLayoutConstraint(item: choiceButton, attribute: .Height, relatedBy: .Equal, toItem: self, attribute: .Height, multiplier: 1.0, constant: 0)
            self.addConstraint(heightConstraint)
            heightConstraint.active = true
            
            let yConstraint = NSLayoutConstraint(item: choiceButton, attribute: .CenterY, relatedBy: .Equal, toItem: self, attribute: .CenterY, multiplier: 1.0, constant: 0)
            self.addConstraint(yConstraint)
            yConstraint.active = true
            
            let widthConstraint = NSLayoutConstraint(item: choiceButton, attribute: .Width, relatedBy: .Equal, toItem: self, attribute: .Width, multiplier: 1.0/CGFloat(self.displayedRatingChoices.count), constant: 0)
            self.addConstraint(widthConstraint)
            widthConstraint.active = true
            
            if i == 0 {
                let xConstraint = NSLayoutConstraint(item: choiceButton, attribute: .Leading, relatedBy: .Equal, toItem: self, attribute: .Leading, multiplier: 1.0, constant: 0)
                self.addConstraint(xConstraint)
                xConstraint.active = true
            } else if let lastButton = ratingButtons.last {
                let xConstraint = NSLayoutConstraint(item: choiceButton, attribute: .Leading, relatedBy: .Equal, toItem: lastButton, attribute: .Trailing, multiplier: 1.0, constant: 0)
                self.addConstraint(xConstraint)
                xConstraint.active = true
            }
            
            ratingButtons.append(choiceButton)
        }
        
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.Heavy)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
        
        reloadUI()
    }
    
    func buttonTapped(sender:UIButton)
    {
        
        if #available(iOS 10.0, *) {
            if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                feedbackGenerator.impactOccurred()
            }
        }
        
        // make the button "sticky"
        sender.selected = !sender.selected
        
        if (sender.selected) {
            // deselect other buttons
            for button in ratingButtons {
                if button != sender {
                    button.selected = false
                }
            }
        
            animateChoice(forButton: sender)
        }
        
        self.sendActionsForControlEvents(.ValueChanged)
    }
    
    private func animateChoice(forButton button: UIButton) {
        let duration: NSTimeInterval = 2.0
        
        guard let buttonIndex = ratingButtons.indexOf(button) else {
            return
        }
        
        let ratingChoice = displayedRatingChoices[buttonIndex]
        
        guard let selectedImage = image(forRatingChoice: ratingChoice, selected: true, imageWidth: button.frame.size.width, withDescription: false) else {
            return
        }
        
        let animationLayer = CALayer()
        animationLayer.frame = button.bounds
        animationLayer.contents = selectedImage.CGImage
        button.layer.addSublayer(animationLayer)
        CATransaction.begin()
        
        CATransaction.setCompletionBlock {
            animationLayer.removeFromSuperlayer()
        }
        
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        scaleAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0.8, 1.01)
        scaleAnimation.duration = duration
        scaleAnimation.values = [NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
                                 NSValue(CATransform3D: CATransform3DMakeScale(3.5, 3.5, 1.0))]
        animationLayer.addAnimation(scaleAnimation, forKey:"scaleAnimation")
        
        // we need to animate the position so the emoji stays centered about itself
        let positonAnimation = CAKeyframeAnimation(keyPath: "position")
        positonAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0.8, 1.01)
        positonAnimation.duration = duration
        positonAnimation.values = [NSValue(CGPoint:animationLayer.position),
                                   NSValue(CGPoint:CGPointMake(0.5 * button.frame.size.width, 0.1 * button.frame.size.height))]
        animationLayer.addAnimation(positonAnimation, forKey:"position")
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = duration;
        opacityAnimation.fromValue = NSNumber(float: 1.0)
        opacityAnimation.toValue =   NSNumber(float: 0.0)
        animationLayer.addAnimation(opacityAnimation, forKey:"opacity")
        
        animationLayer.opacity = 0.0
        
        CATransaction.commit()
    }
    
    func selectionDidChange() {
        reloadUI()
    }
    
    override func prepareForInterfaceBuilder() {
        reloadUI()
    }
    
    private func image(forRatingChoice ratingChoice:RatingChoice, selected:Bool, imageWidth: CGFloat, withDescription: Bool = true) -> UIImage? {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Center
        
        let attributedEmojiString = NSAttributedString(string: ratingChoice.emoji, attributes: [NSFontAttributeName: UIFont.systemFontOfSize(self.emojiFontSize), NSForegroundColorAttributeName: UIColor.blackColor(), NSParagraphStyleAttributeName: paragraphStyle])
        let attributedDescriptionString = NSAttributedString(string: ratingChoice.noun, attributes: [NSFontAttributeName: UIFont.systemFontOfSize(self.descriptionFontSize), NSForegroundColorAttributeName: (selected ? ColorPallete.sharedPallete.darkGrey : ColorPallete.sharedPallete.unknownGrey), NSParagraphStyleAttributeName: paragraphStyle])
        
        let emojiSize = attributedEmojiString.boundingRectWithSize(CGSizeMake(imageWidth, CGFloat.max), options:[NSStringDrawingOptions.UsesLineFragmentOrigin, NSStringDrawingOptions.UsesFontLeading], context:nil).size
        let descriptionSize = attributedDescriptionString.boundingRectWithSize(CGSizeMake(imageWidth, CGFloat.max), options:(NSStringDrawingOptions.UsesLineFragmentOrigin), context:nil).size
        
        let verticalMargin: CGFloat = 4
        let emojiOffset: CGFloat = 2 // dont know why, but emoji refuse to draw centered
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageWidth, self.frame.size.height), false , 0.0)
        let emojiDrawRect = CGRectMake(emojiOffset + (imageWidth - emojiSize.width)/2.0, verticalMargin, emojiSize.width, emojiSize.height)
        if let context = UIGraphicsGetCurrentContext() where selected == false && ratingChoice == .Bad {
            // the bad emoji is red and darker, so we draw it slightly lighter in deselected state to even things out
            CGContextSetAlpha(context, 0.7)
            attributedEmojiString.drawInRect(emojiDrawRect)
            CGContextSetAlpha(context, 1.0)
        } else {
            attributedEmojiString.drawInRect(emojiDrawRect)
        }
        
        if withDescription {
            let descriptionDrawRect = CGRectMake((imageWidth - descriptionSize.width)/2.0, self.frame.size.height - descriptionSize.height - verticalMargin, descriptionSize.width, descriptionSize.height)
            attributedDescriptionString.drawInRect(descriptionDrawRect)
        }
        
        let renderedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if renderedImage == nil {
            return nil
        }
        
        if (selected) {
            return renderedImage!.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal)
        }
        
        let context = CIContext(options: nil)
        let currentFilter = CIFilter(name: "CIPhotoEffectTonal")
        currentFilter!.setValue(CIImage(image: renderedImage!), forKey: kCIInputImageKey)
        let output = currentFilter!.outputImage
        let cgImage = context.createCGImage(output!,fromRect:output!.extent)
        let processedImage = UIImage(CGImage: cgImage!, scale: UIScreen.mainScreen().scale, orientation: UIImageOrientation.Up)
        
        return processedImage.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal)
    }
    
    func reloadUI() {
        for (i, ratingChoice) in self.displayedRatingChoices.enumerate() {
            // leave room for the end caps
            let button = self.ratingButtons[i]
            let imageWidth = self.frame.size.width/CGFloat(self.displayedRatingChoices.count)
            button.setImage(image(forRatingChoice: ratingChoice, selected: false, imageWidth: imageWidth), forState: .Normal)
            
            let selectedImage = image(forRatingChoice: ratingChoice, selected: true, imageWidth: imageWidth)
            button.setImage(selectedImage, forState: .Selected)
            button.setImage(selectedImage, forState: .Highlighted)
        }
    }
}
