//
//  UIImage+HBAdditions.swift
//  Ride Report
//
//  Created by William Henderson on 1/5/18.
//  Copyright © 2018 Knock Softwae, Inc. All rights reserved.
//

import Foundation

public extension UIImage {
    func getPixelColor(point: CGPoint) -> UIColor {
        guard let cgImage : CGImage = self.cgImage, let provider = cgImage.dataProvider, let providerData = provider.data, let data = CFDataGetBytePtr(providerData) else {
            return UIColor.clear
        }
        
        let x = Int(point.x)
        let y = Int(point.y)
        let index = Int(self.size.width * self.scale) * y + x * Int(self.scale)
        let expectedLengthA = Int(self.size.width * self.scale * self.size.height * self.scale)
        let expectedLengthRGB = 3 * expectedLengthA
        let expectedLengthRGBA = 4 * expectedLengthA
        let numBytes = CFDataGetLength(providerData)
        switch numBytes {
        case expectedLengthA:
            return UIColor(red: 0, green: 0, blue: 0, alpha: CGFloat(data[index])/255.0)
        case expectedLengthRGB:
            return UIColor(red: CGFloat(data[3*index])/255.0, green: CGFloat(data[3*index+1])/255.0, blue: CGFloat(data[3*index+2])/255.0, alpha: 1.0)
        case expectedLengthRGBA:
            return UIColor(red: CGFloat(data[4*index])/255.0, green: CGFloat(data[4*index+1])/255.0, blue: CGFloat(data[4*index+2])/255.0, alpha: CGFloat(data[4*index+3])/255.0)
        default:
            // unsupported format
            return UIColor.clear
        }
    }
}
