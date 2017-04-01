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
    private var feedbackGenerator: NSObject!
    
    private var ratingButtons: [UIButton]! = []
    
    private var selectedRatingButtonIndex: Int {
        for (i, button) in ratingButtons.enumerated() {
            if button.isSelected {
                return i
            }
        }
        
        return -1
    }
    
    var selectedRating: RatingChoice {
        get {
            let selectedIndex = self.selectedRatingButtonIndex
            guard selectedIndex != -1 else {
                return .notSet
            }
            
            guard selectedIndex < RatingVersion.currentRatingVersion.availableRatingChoices.count else {
                return .notSet
            }
            
            return RatingVersion.currentRatingVersion.availableRatingChoices[selectedIndex]
        }
        
        set {
            for button in ratingButtons {
                button.isSelected = false
            }
            
            if (newValue == .notSet) {
                return
            }
            
            guard let choiceIndex = RatingVersion.currentRatingVersion.availableRatingChoices.index(of: newValue) else {
                return
            }
            
            guard choiceIndex != -1 else {
                return
            }
            
            guard choiceIndex < ratingButtons.count else {
                return
            }
            
            ratingButtons[choiceIndex].isSelected = true
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
        if !self.isHidden {
            reloadUI()
        }
    }
    
    
    func commonInit() {
        self.addTarget(self, action: #selector(RatingChoiceSelectorView.selectionDidChange), for: UIControlEvents.valueChanged)
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.backgroundColor = UIColor.clear

        
        for (i, _) in RatingVersion.currentRatingVersion.availableRatingChoices.enumerated() {
            let choiceButton = UIButton(type: UIButtonType.custom)
            
            choiceButton.addTarget(self, action: #selector(RatingChoiceSelectorView.buttonTapped(_:)), for: UIControlEvents.touchUpInside)
            
            choiceButton.backgroundColor = UIColor.clear
            self.addSubview(choiceButton)
            
            choiceButton.translatesAutoresizingMaskIntoConstraints = false
            
            let heightConstraint = NSLayoutConstraint(item: choiceButton, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: 0)
            self.addConstraint(heightConstraint)
            heightConstraint.isActive = true
            
            let yConstraint = NSLayoutConstraint(item: choiceButton, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0)
            self.addConstraint(yConstraint)
            yConstraint.isActive = true
            
            let widthConstraint = NSLayoutConstraint(item: choiceButton, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/CGFloat(RatingVersion.currentRatingVersion.availableRatingChoices.count), constant: 0)
            self.addConstraint(widthConstraint)
            widthConstraint.isActive = true
            
            if i == 0 {
                let xConstraint = NSLayoutConstraint(item: choiceButton, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0)
                self.addConstraint(xConstraint)
                xConstraint.isActive = true
            } else if let lastButton = ratingButtons.last {
                let xConstraint = NSLayoutConstraint(item: choiceButton, attribute: .leading, relatedBy: .equal, toItem: lastButton, attribute: .trailing, multiplier: 1.0, constant: 0)
                self.addConstraint(xConstraint)
                xConstraint.isActive = true
            }
            
            ratingButtons.append(choiceButton)
        }
        
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
        
        reloadUI()
    }
    
    func buttonTapped(_ sender:UIButton)
    {
        
        if #available(iOS 10.0, *) {
            if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                feedbackGenerator.impactOccurred()
            }
        }
        
        // make the button "sticky"
        sender.isSelected = !sender.isSelected
        
        if (sender.isSelected) {
            // deselect other buttons
            for button in ratingButtons {
                if button != sender {
                    button.isSelected = false
                }
            }
        
            animateChoice(forButton: sender)
        }
        
        self.sendActions(for: .valueChanged)
    }
    
    private func animateChoice(forButton button: UIButton) {
        let duration: TimeInterval = 2.0
        
        guard let buttonIndex = ratingButtons.index(of: button) else {
            return
        }
        
        let ratingChoice = RatingVersion.currentRatingVersion.availableRatingChoices[buttonIndex]
        
        guard let selectedImage = image(forRatingChoice: ratingChoice, selected: true, imageWidth: button.frame.size.width, withDescription: false) else {
            return
        }
        
        let animationLayer = CALayer()
        animationLayer.frame = button.bounds
        animationLayer.contents = selectedImage.cgImage
        button.layer.addSublayer(animationLayer)
        CATransaction.begin()
        
        CATransaction.setCompletionBlock {
            animationLayer.removeFromSuperlayer()
        }
        
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        scaleAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0.8, 1.01)
        scaleAnimation.duration = duration
        scaleAnimation.values = [NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
                                 NSValue(caTransform3D: CATransform3DMakeScale(3.5, 3.5, 1.0))]
        animationLayer.add(scaleAnimation, forKey:"scaleAnimation")
        
        // we need to animate the position so the emoji stays centered about itself
        let positonAnimation = CAKeyframeAnimation(keyPath: "position")
        positonAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.71, 0.8, 1.01)
        positonAnimation.duration = duration
        positonAnimation.values = [NSValue(cgPoint:animationLayer.position),
                                   NSValue(cgPoint:CGPoint(x: 0.5 * button.frame.size.width, y: 0.1 * button.frame.size.height))]
        animationLayer.add(positonAnimation, forKey:"position")
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.timingFunction = CAMediaTimingFunction(controlPoints:0.18, 0.71, 0, 1.01)
        opacityAnimation.duration = duration;
        opacityAnimation.fromValue = NSNumber(value: 1.0 as Float)
        opacityAnimation.toValue =   NSNumber(value: 0.0 as Float)
        animationLayer.add(opacityAnimation, forKey:"opacity")
        
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
        paragraphStyle.alignment = .center
        
        let attributedEmojiString = NSAttributedString(string: ratingChoice.emoji, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: self.emojiFontSize), NSForegroundColorAttributeName: UIColor.black, NSParagraphStyleAttributeName: paragraphStyle])
        let attributedDescriptionString = NSAttributedString(string: ratingChoice.noun, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: self.descriptionFontSize), NSForegroundColorAttributeName: (selected ? ColorPallete.shared.darkGrey : ColorPallete.shared.unknownGrey), NSParagraphStyleAttributeName: paragraphStyle])
        
        let emojiSize = attributedEmojiString.boundingRect(with: CGSize(width: imageWidth, height: CGFloat.greatestFiniteMagnitude), options:[NSStringDrawingOptions.usesLineFragmentOrigin, NSStringDrawingOptions.usesFontLeading], context:nil).size
        let descriptionSize = attributedDescriptionString.boundingRect(with: CGSize(width: imageWidth, height: CGFloat.greatestFiniteMagnitude), options:(NSStringDrawingOptions.usesLineFragmentOrigin), context:nil).size
        
        let verticalMargin: CGFloat = 4
        let emojiOffset: CGFloat = 2 // dont know why, but emoji refuse to draw centered
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageWidth, height: self.frame.size.height), false , 0.0)
        let emojiDrawRect = CGRect(x: emojiOffset + (imageWidth - emojiSize.width)/2.0, y: verticalMargin, width: emojiSize.width, height: emojiSize.height)
        if let context = UIGraphicsGetCurrentContext(), selected == false && ratingChoice == .bad {
            // the bad emoji is red and darker, so we draw it slightly lighter in deselected state to even things out
            context.setAlpha(0.7)
            attributedEmojiString.draw(in: emojiDrawRect)
            context.setAlpha(1.0)
        } else {
            attributedEmojiString.draw(in: emojiDrawRect)
        }
        
        if withDescription {
            let descriptionDrawRect = CGRect(x: (imageWidth - descriptionSize.width)/2.0, y: self.frame.size.height - descriptionSize.height - verticalMargin, width: descriptionSize.width, height: descriptionSize.height)
            attributedDescriptionString.draw(in: descriptionDrawRect)
        }
        
        let renderedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if renderedImage == nil {
            return nil
        }
        
        if (selected) {
            return renderedImage!.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
        }
        
        let context = CIContext(options: nil)
        let currentFilter = CIFilter(name: "CIPhotoEffectTonal")
        currentFilter!.setValue(CIImage(image: renderedImage!), forKey: kCIInputImageKey)
        let output = currentFilter!.outputImage
        let cgImage = context.createCGImage(output!,from:output!.extent)
        let processedImage = UIImage(cgImage: cgImage!, scale: UIScreen.main.scale, orientation: UIImageOrientation.up)
        
        return processedImage.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
    }
    
    func reloadUI() {
        for (i, ratingChoice) in RatingVersion.currentRatingVersion.availableRatingChoices.enumerated() {
            // leave room for the end caps
            let button = self.ratingButtons[i]
            let imageWidth = self.frame.size.width/CGFloat(RatingVersion.currentRatingVersion.availableRatingChoices.count)
            button.setImage(image(forRatingChoice: ratingChoice, selected: false, imageWidth: imageWidth), for: .normal)
            
            let selectedImage = image(forRatingChoice: ratingChoice, selected: true, imageWidth: imageWidth)
            button.setImage(selectedImage, for: .selected)
            button.setImage(selectedImage, for: .highlighted)
        }
    }
}
