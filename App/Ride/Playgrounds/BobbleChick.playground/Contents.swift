//: Playground - noun: a place where people can play

import UIKit
import SpriteKit
import XCPlayground

var str = "Hello, playground"

let emojiSize = CGSizeMake(160, 160)
let j = 0

UIGraphicsBeginImageContextWithOptions(emojiSize, false, 0.0)
("🐣" as NSString).drawAtPoint(CGPointMake(0,0), withAttributes:[NSFontAttributeName: UIFont(name: "Helvetica", size: 140)!])

let maskImage = UIGraphicsGetImageFromCurrentImageContext()
UIGraphicsEndImageContext()

let imageView = UIImageView(image: maskImage)
XCPlaygroundPage.currentPage.liveView = imageView

CATransaction.begin()

let shakeAnimation = CAKeyframeAnimation(keyPath: "transform")

//let rotationOffsets = [M_PI, -M_PI_2, -0.2, 0.2, -0.2, 0.2, -0.2, 0.2, 0.0]
shakeAnimation.values = [
    NSValue(CATransform3D:CATransform3DMakeRotation(10 * CGFloat(M_PI/180), 0, 0, -1)),
    NSValue(CATransform3D: CATransform3DMakeRotation(-10 * CGFloat(M_PI/180), 0, 0, 1)),
    NSValue(CATransform3D: CATransform3DMakeRotation(6 * CGFloat(M_PI/180), 0, 0, 1)),
    NSValue(CATransform3D: CATransform3DMakeRotation(-6 * CGFloat(M_PI/180), 0, 0, 1)),
    NSValue(CATransform3D: CATransform3DMakeRotation(2 * CGFloat(M_PI/180), 0, 0, 1)),
    NSValue(CATransform3D: CATransform3DMakeRotation(-2 * CGFloat(M_PI/180), 0, 0, 1))
]
shakeAnimation.keyTimes = [0, 0.2, 0.4, 0.65, 0.8, 1]
shakeAnimation.additive = true
shakeAnimation.duration = 0.6

imageView.layer.addAnimation(shakeAnimation, forKey:"transform")

CATransaction.commit()

