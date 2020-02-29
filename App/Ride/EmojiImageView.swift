//
//  EmojiImageView.swift
//  Ride Report
//
//  Created by Heather Buletti on 5/15/18.
//  Copyright © 2018 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Kingfisher
import UIImageColors

class UIImageColorsWrapper { // wrapper to let us use NSCache on the UIImageColors struc
    var colors: UIImageColors!
    
    convenience init(_ colors: UIImageColors) {
        self.init()
        self.colors = colors
    }
}

struct ComputedImageData {
    var imageSize: CGSize = CGSize.zero
    var saturated: Bool = false
    var iconURL: URL?
    var emoji: String? = ""
    var identifier: String = ""
    var emojiFontSize: CGFloat = 50
}

class EmojiImageView: ImageView {
    static let emojiColorsCache = NSCache<NSString, UIImageColorsWrapper>()
    private let context = CIContext(options: nil)
    static var versionNumber = 2
    private var serialImageQueue = DispatchQueue(label: "emojiImageQueue")
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setUpView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setUpView()
    }
    
    func setUpView() {
        self.backgroundColor = UIColor.clear
        self.clipsToBounds = false
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func setImage(with computedImageData: ComputedImageData,
                         completionHandler: @escaping ()->Void ) {
        ImageCache.default.retrieveImage(forKey: computedImageData.identifier, options: nil) { (image, type) in
            if let image = image {
                self.image = image
                completionHandler()
            }
            else {
                self.isHidden = true
                self.serialImageQueue.async { [weak self] in
                    let iconCompletionHandler: (Image?, UIImageColors?) -> Void = { (image, colors) in
                        guard let iconImage = image, let iconColors = colors else {
                            return
                        }
                        var imageToStore: Image?
                        DispatchQueue.global(qos: .background).async { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            if computedImageData.saturated {
                                imageToStore = strongSelf.renderSaturatedImage(withComputedData: computedImageData, iconImage: iconImage, colors: iconColors)
                            }
                            else {
                                imageToStore = strongSelf.renderDesaturatedImage(withComputedData: computedImageData, iconImage: iconImage, colors: iconColors)
                            }
                            if let image = imageToStore {
                                ImageCache.default.store(image, forKey: computedImageData.identifier)
                                DispatchQueue.main.async(execute: {
                                    strongSelf.image = image
                                    strongSelf.fadeIn()
                                    completionHandler()
                                })
                            }
                        }
                    }
                    
                    if computedImageData.iconURL != nil {
                        EmojiImageView.renderIconImage(withComputedData: computedImageData, completionHandler: iconCompletionHandler)
                    }
                    else {
                        EmojiImageView.renderEmojiImage(withComputedData: computedImageData, completionHandler: iconCompletionHandler)
                    }
                }
            }
        }
    }
    
    private func renderSaturatedImage(withComputedData imageData: ComputedImageData, iconImage: Image, colors: UIImageColors) -> Image? {
        
        guard let saturatedGradientEmoji = renderGradientImage(withComputedData: imageData, emojiImage: iconImage, colors: colors) else {
            return nil
        }
        
        return saturatedGradientEmoji.withRenderingMode(UIImage.RenderingMode.alwaysOriginal)
    }
    
    private func renderDesaturatedImage(withComputedData imageData: ComputedImageData, iconImage: Image, colors: UIImageColors) -> Image? {
    
        guard let pixellateFilter = CIFilter(name: "CIPixellate") else {
            return nil
        }
        pixellateFilter.setValue(CIImage(image:iconImage), forKey: kCIInputImageKey)
        pixellateFilter.setValue(NSNumber(value: Float(imageData.imageSize.width)/10), forKey: kCIInputScaleKey)
        guard let pixellateOutput = pixellateFilter.outputImage, let pixellateCGImage = context.createCGImage(pixellateOutput, from:pixellateOutput.extent) else {
            return nil
        }
        let pixellateImage = UIImage(cgImage: pixellateCGImage, scale: UIScreen.main.scale, orientation: UIImage.Orientation.up)
        
        guard let saturatedGradientPixellatedEmoji = renderGradientImage(withComputedData:imageData, emojiImage: pixellateImage, colors: colors) else {
            return nil
        }
        
        guard let desaturateFilter = CIFilter(name: "CIPhotoEffectTonal") else {
            return nil
        }
        desaturateFilter.setValue(CIImage(image: saturatedGradientPixellatedEmoji), forKey: kCIInputImageKey)
        guard let desaturateOutput = desaturateFilter.outputImage, let desaturateCGImage = context.createCGImage(desaturateOutput, from:desaturateOutput.extent) else {
            return nil
        }
        let desaturedImage = UIImage(cgImage: desaturateCGImage, scale: UIScreen.main.scale, orientation: UIImage.Orientation.up)
        
        return desaturedImage
    }
    
    private func renderGradientImage(withComputedData imageData: ComputedImageData, emojiImage: Image, colors: UIImageColors)->UIImage? {
        var nonWhiteBorderColor = colors.background!
        
        let minimumColorValue: CGFloat = 0.84
        if let RGB = nonWhiteBorderColor.cgColor.components, RGB[0] > minimumColorValue && RGB[1] > minimumColorValue && RGB[2] > minimumColorValue {
            // don't use too light a color
            nonWhiteBorderColor = colors.detail
        }
        
        var drawsBorder = false
        // draw a border for light background colors
        
        if let RGB = colors.primary.cgColor.components, RGB[0] > minimumColorValue && RGB[1] > minimumColorValue && RGB[2] > minimumColorValue {
            drawsBorder = true
        } else if let RGB = colors.secondary.cgColor.components, RGB[0] > minimumColorValue && RGB[1] > minimumColorValue && RGB[2] > minimumColorValue {
            drawsBorder = true
        }
        
        UIGraphicsBeginImageContextWithOptions(imageData.imageSize, false , 0.0)
        let gradientRect = CGRect(x: 0, y: 0, width: imageData.imageSize.width, height: imageData.imageSize.height)
        let lineWidth = drawsBorder ? self.borderWidth : 0
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [colors.secondary.cgColor, colors.primary.cgColor]
        gradientLayer.locations = [0.4, 1.0]
        gradientLayer.bounds = gradientRect.insetBy(dx: lineWidth/2, dy: lineWidth/2) // ensure gradient is not visible outside border
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.cornerRadius = self.cornerRadius
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        
        let path = UIBezierPath(roundedRect: gradientRect.insetBy(dx: lineWidth/2, dy: lineWidth/2), byRoundingCorners: UIRectCorner.allCorners, cornerRadii: CGSize(width: self.cornerRadius, height: self.cornerRadius))
        path.lineWidth = lineWidth
        nonWhiteBorderColor.setStroke()
        path.stroke()
        
        let drawPointX = abs(imageData.imageSize.width - emojiImage.size.width)/2.0 * -1.0
        let drawPointY = abs(imageData.imageSize.height - emojiImage.size.height)/2.0 * -1.0
        emojiImage.draw(at: CGPoint(x: drawPointX, y: drawPointY))
        
        let gradientImageOptional = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return gradientImageOptional
    }
    
    private static func getColors(forImage image: Image, imageData: ComputedImageData) -> (UIImageColors?) {
        let cacheKey = EmojiImageView.gradientCacheKey(forEmoji: imageData.emoji, iconURL: imageData.iconURL)
        if let cachedColors =  EmojiImageView.emojiColorsCache.object(forKey: cacheKey as NSString)?.colors {
            return cachedColors
        } else {
            // create it from scratch then store in the cache
            if let colors = image.getColors(quality: .low) {
                EmojiImageView.emojiColorsCache.setObject(UIImageColorsWrapper(colors), forKey: cacheKey as NSString)
                return colors
            } else {
                return nil
            }
        }
    }
    
    static func renderIconImage(withComputedData imageData: ComputedImageData, completionHandler:@escaping (Image?, UIImageColors?)->Void) {
        // Question: Do we want to cache these icons, or do the URLS not change when the images change, leading to potentially stale images?
    
        if let iconURL = imageData.iconURL {
            let cacheKey = EmojiImageView.cacheKey(forComputedImageData: imageData)
            ImageCache.default.retrieveImage(forKey: cacheKey , options: KingfisherManager.shared.defaultOptions) { (image, type) in
                if let iconImage = image {
                    completionHandler(iconImage, EmojiImageView.getColors(forImage: iconImage, imageData: imageData))
                }
                else {
                    ImageDownloader.default.downloadImage(with: iconURL, options: [.scaleFactor(UIScreen.main.scale)], progressBlock: nil) {
                        (image, error, url, data) in
                        if let iconImage = image {
                            UIGraphicsBeginImageContextWithOptions(imageData.imageSize, false , 0.0)
                            let dimension = imageData.emojiFontSize
                            iconImage.draw(in: CGRect(x: (imageData.imageSize.width - dimension)/2, y: (imageData.imageSize.height - dimension)/2, width: dimension, height: dimension))
                            
                            let outputImage = UIGraphicsGetImageFromCurrentImageContext()
                            UIGraphicsEndImageContext()
                            
                            if let image = outputImage {
                                completionHandler(image, EmojiImageView.getColors(forImage: image, imageData: imageData))
                            }
                        }
                        else {
                            print("\(error!.description)")
                        }
                    }
                }
            }
        }
    }
    
    static func renderEmojiImage(withComputedData imageData: ComputedImageData, completionHandler:@escaping (Image?, UIImageColors?)->Void) {
        guard let emoji = imageData.emoji else {
            return
        }
        let cacheKey = EmojiImageView.cacheKey(forComputedImageData: imageData)
        ImageCache.default.retrieveImage(forKey: cacheKey , options: [.scaleFactor(UIScreen.main.scale)]) { (image, type) in
            var iconImage: Image?
            if let image = image {
                iconImage = image
            }
            else {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                UIGraphicsBeginImageContextWithOptions(imageData.imageSize, false , 0.0)
                let attributedEmojiString = NSAttributedString(string: emoji, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: imageData.emojiFontSize), NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.paragraphStyle: paragraphStyle])
                let boundingRect = attributedEmojiString.boundingRect(with: imageData.imageSize, options:[.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics], context: nil)
                let xOffset: CGFloat = 1 // dont know why, but emoji refuse to draw centered
                attributedEmojiString.draw(with: CGRect(x: (imageData.imageSize.width - boundingRect.width)/2 + xOffset, y: (imageData.imageSize.height - boundingRect.height)/2, width: boundingRect.width, height: boundingRect.height),  options:[.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics], context: nil)
                iconImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let image = iconImage {
                    ImageCache.default.store(image, forKey: cacheKey)
                }
            }
            if let image = iconImage {
                completionHandler(image, EmojiImageView.getColors(forImage: image, imageData: imageData))
            }
        }
    }
    
    static func cacheKey(forComputedImageData imageData: ComputedImageData) -> String {
        if let iconURL = imageData.iconURL {
            return String("\(iconURL.lastPathComponent)-\(imageData.imageSize.width)-\(EmojiImageView.versionNumber)")
        }
        if let emoji = imageData.emoji {
            return String("\(emoji)-\(imageData.emojiFontSize)-\(EmojiImageView.versionNumber)")
            
        }
        return ""
    }
    
    static func gradientCacheKey(forEmoji emoji: String?, iconURL: URL?) -> String {
        if let iconURL = iconURL {
            return String(format: "%@-%i", iconURL.lastPathComponent, EmojiImageView.versionNumber)
        }
        if let emoji = emoji {
            return String(format: "%@-%i", emoji, EmojiImageView.versionNumber)
        }
        return ""
    }
    
    private var cornerRadius: CGFloat {
        get {
            let magicCornerRadiusRatio: CGFloat = 10/57 // https://hicksdesign.co.uk/journal/ios-icon-corner-radii
            return CGFloat(TrophyProgressButton.defaultBadgeDimension * magicCornerRadiusRatio)
        }
    }
    
    private var borderWidth: CGFloat {
        get {
            return TrophyProgressButton.defaultBadgeDimension/35.0
        }
    }
    
}
