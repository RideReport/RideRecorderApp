//
//  RewardsViewController.swift
//  Ride
//
//  Created by William Henderson on 1/6/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SpriteKit

class RewardsViewController: UIViewController, SKPhysicsContactDelegate, SKSceneDelegate
{
    @IBOutlet weak var spriteKitView: SKView!
    @IBOutlet weak var rewardsLabel1: UILabel!
    @IBOutlet weak var rewardsLabel2: UILabel!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var emptyTrophiesView: UIView!
    @IBOutlet weak var bobbleChickView: UIView!
    @IBOutlet weak var rewardPopup: PopupView!
    
    private var scene: SKScene?
    var imageDictionary : [String: UIImage] = [:]
    
    var touchPoint: CGPoint = CGPoint()
    var touchTime: NSTimeInterval = 0
    var touchedSprite: SKSpriteNode?
    var currentVelocity: CGVector? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.rewardPopup.hidden = true
        
        let trophyCount = Trip.numberOfRewardedTrips
        if trophyCount > 0 {
            self.title = String(trophyCount) + " Trophies"
        } else {
            self.title = "No Trophies Yet"
        }
    }
    
    override func viewWillLayoutSubviews()
    {
        super.viewWillLayoutSubviews()
        
        if Trip.numberOfRewardedTrips == 0 {
            self.emptyTrophiesView.hidden = false
            self.bobbleChickView.delay(0.2) {
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
                
                self.bobbleChickView.layer.addAnimation(shakeAnimation, forKey:"transform")
                
                CATransaction.commit()
            }
            
            return
        }
        
        self.emptyTrophiesView.hidden = true
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale.currentLocale()
        dateFormatter.dateStyle = .ShortStyle
        
        let numberFormatter = NSNumberFormatter()
        numberFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        numberFormatter.maximumFractionDigits = 0
        
        if let firstTripDate = Profile.profile().firstTripDate {
            self.rewardsLabel1.text = String(format: "%@%@ miles biked since %@", Profile.profile().milesBikedJewel, numberFormatter.stringFromNumber(NSNumber(float: Profile.profile().milesBiked))!, dateFormatter.stringFromDate(firstTripDate))
        } else {
            self.rewardsLabel1.hidden = true
        }
        
        if let longestStreak = Profile.profile().longestStreakLength?.integerValue, longestStreakDate = Profile.profile().longestStreakStartDate {
            self.rewardsLabel2.text = String(format: "%@  Longest streak: %i days on %@", Profile.profile().longestStreakJewel, longestStreak, dateFormatter.stringFromDate(longestStreakDate))
        } else {
            self.rewardsLabel2.hidden = true
        }
        
        guard self.scene == nil else {
            // make sure we haven't already loaded the scene
            return
        }
        
        self.scene = SKScene(size: self.view.bounds.size)
        self.scene!.backgroundColor = self.spriteKitView.backgroundColor!
        self.scene!.scaleMode = SKSceneScaleMode.ResizeFill
        self.scene!.delegate = self
        
        self.spriteKitView.ignoresSiblingOrder = true
        
        #if DEBUG
            self.spriteKitView.showsDrawCount = true
            self.spriteKitView.showsFPS = true
        #endif
        
        let topSpace : CGFloat = 400.0
        
        self.scene!.physicsBody = SKPhysicsBody(edgeLoopFromRect: CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, self.view.bounds.size.height + topSpace))
        self.scene!.physicsBody!.friction = 0.8
        self.scene!.physicsBody!.restitution = 0.0
        self.scene!.physicsWorld.gravity = CGVectorMake(0,-9.8)
        
        let bikeTripEmojiCounts = Trip.bikeTripCountsGroupedByAttribute("rewardEmoji", additionalAttributes: ["rewardDescription"])
        let fontAttributes = [NSFontAttributeName: UIFont(name: "Helvetica", size: 26)!]
        
        let imageSize = CGSizeMake(30.0, 30.0)
        for countData in bikeTripEmojiCounts {
            if let rewardEmoji = countData["rewardEmoji"] as? String {
                let unicodeString = NSString(data: rewardEmoji.dataUsingEncoding(NSNonLossyASCIIStringEncoding)!, encoding: NSUTF8StringEncoding)
                if (imageDictionary[unicodeString as! String] == nil) {
                    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                    (rewardEmoji as NSString).drawAtPoint(CGPointMake(0,0), withAttributes:fontAttributes)
                    
                    let emojiImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    imageDictionary[unicodeString as! String] = emojiImage
                }
            }
        }
        
        let textureAtlas = SKTextureAtlas(dictionary: imageDictionary)
        textureAtlas.preloadWithCompletionHandler { () -> Void in
            self.spriteKitView.presentScene(self.scene)
            
            var emojis : [SKSpriteNode] = []
            var lastEmojiReceived : SKSpriteNode? = nil
            
            for (j, countData) in bikeTripEmojiCounts.enumerate() {
                if let rewardEmoji = countData["rewardEmoji"] as? String,
                    rewardDescription = countData["rewardDescription"] as? String,
                    count = countData["count"] as? NSNumber {
                    let unicodeString = NSString(data: rewardEmoji.dataUsingEncoding(NSNonLossyASCIIStringEncoding)!, encoding: NSUTF8StringEncoding)
                    let texture = textureAtlas.textureNamed(unicodeString as! String)
                    
                    let emojiSize = (rewardEmoji as NSString).sizeWithAttributes(fontAttributes)
                    let insetEmojiSize = CGSizeMake(emojiSize.width - 8, emojiSize.height - 8)
                    texture.usesMipmaps = true
                    texture.filteringMode = SKTextureFilteringMode.Nearest
                    for i in 0..<count.integerValue {
                        let emoji = SKSpriteNode(texture: texture, size: imageSize)
                        emoji.name = rewardDescription
                        emoji.physicsBody = SKPhysicsBody(rectangleOfSize: insetEmojiSize)
                        emoji.physicsBody!.usesPreciseCollisionDetection = false
                        emoji.physicsBody!.restitution = 0.6
                        emoji.physicsBody!.friction = 1.0
                        emoji.physicsBody!.density = 0.005
                        emoji.physicsBody!.linearDamping = 0.0
                        emoji.physicsBody!.angularDamping = 0.0
                        emoji.physicsBody!.dynamic = false
                        
                        emojis.append(emoji)
                    }
                }
            }
            
            lastEmojiReceived = emojis.last
            emojis.removeLast()
            
            dispatch_async(dispatch_get_main_queue()) {
                var nodeCount = 0
                
                let emojiInitialPadding: CGFloat = -7.0
                
                for emoji in emojis.shuffle() {
                    self.scene!.addChild(emoji)

                    let nodePlacementX = (CGFloat(nodeCount) * (emoji.size.width + emojiInitialPadding))
                    let nodePlacementXModuloWidth = nodePlacementX % self.view.frame.size.width
                    let targetPoint = CGPointMake(nodePlacementXModuloWidth, (emoji.size.height + emojiInitialPadding) * (nodePlacementX - nodePlacementXModuloWidth) / self.view.frame.size.width)
                    
                    emoji.runAction(SKAction.sequence([
                        SKAction.rotateByAngle(CGFloat(2 * M_PI * Double(arc4random_uniform(360)) / 360.0), duration: 0.0),
                        SKAction.moveTo(targetPoint, duration: 0.0),
                        SKAction.runBlock({
                            emoji.physicsBody!.dynamic = true
                        })]))
                    nodeCount += 1
                }
                
                guard let lastEmoji = lastEmojiReceived else {
                    return
                }
                
                let delayBeforeDroppingInLastReward: NSTimeInterval = 1.0
                let delayBeforeDescalingLastEmoji: NSTimeInterval = 4.5
                
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delayBeforeDroppingInLastReward * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
                    guard let strongSelf = self, scene = strongSelf.scene else {
                        return
                    }
                    
                    lastEmoji.physicsBody!.density = 100.0 // make it heavy so it can knock other emoji around easily
                    lastEmoji.physicsBody!.dynamic = true

                    scene.addChild(lastEmoji)
                    
                    if let name = lastEmoji.name {
                        strongSelf.rewardPopup.text = name
                        strongSelf.rewardPopup.sizeToFit()
                        strongSelf.rewardPopup.popIn()
                        strongSelf.rewardPopup.delay(delayBeforeDescalingLastEmoji) {
                            if strongSelf.touchedSprite == nil {
                                strongSelf.rewardPopup.fadeOut()
                            }
                        }
                    }
                    
                    lastEmoji.runAction(SKAction.sequence([
                        SKAction.unhide(),
                        SKAction.scaleTo(4.0, duration: 0.0),
                        SKAction.moveTo(CGPointMake((strongSelf.view.frame.size.width - lastEmoji.size.width) / 2.0, strongSelf.view.frame.size.height + topSpace - 40), duration: 0.001),
                        SKAction.waitForDuration(delayBeforeDescalingLastEmoji),
                        SKAction.scaleTo(1.0, duration: 0.2)]))
                    
                }
            }
        } //end of preloadWithCompletionHandler block        
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let scene = self.scene else {
            return
        }
        
        let touch = touches.first!
        let point = touch.locationInNode(scene)
        if let tappedSprite = scene.nodeAtPoint(point) as? SKSpriteNode {
            self.touchPoint = point
            self.touchTime = touch.timestamp
            self.touchedSprite = tappedSprite
            self.touchedSprite!.physicsBody!.density = 100.0 // make it heavy so it can knock other emoji around easily
            self.currentVelocity = CGVector(dx: 0, dy: 0)
            if #available(iOS 9.0, *) {
                self.touchedSprite?.runAction(SKAction.scaleTo(4.0, duration: 0.2))
            } else {
                // Fallback on earlier versions
            }
            
            if let name = tappedSprite.name {
                self.rewardPopup.text = name
                self.rewardPopup.sizeToFit()
                self.rewardPopup.popIn()
            }
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let scene = self.scene else {
            return
        }
        
        if let touchedSprite = self.touchedSprite {
            let touch = touches.first!
            let point = touch.locationInNode(scene)
            
            let dt:CGFloat = CGFloat(touch.timestamp - self.touchTime)
            let distance = CGVector(dx: point.x - touchedSprite.position.x, dy: point.y - touchedSprite.position.y)
            self.currentVelocity = CGVector(dx: distance.dx/dt, dy: distance.dy/dt)
            self.touchTime = touch.timestamp
            self.touchPoint = point
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let _ = self.scene else {
            return
        }
        
        if self.touchedSprite != nil {
            self.touchedSprite!.physicsBody!.density = 0.5
            self.touchedSprite?.runAction(SKAction.scaleTo(1.0, duration: 0.2))
            
            self.touchedSprite = nil
            self.currentVelocity = nil
            
            self.rewardPopup.delay(1) {
                if self.touchedSprite == nil {
                    self.rewardPopup.fadeOut()
                }
            }
        }
    }
    
    func update(currentTime: NSTimeInterval, forScene scene: SKScene) {
        if let touchedSprite = self.touchedSprite,
            let velocity = self.currentVelocity {
            touchedSprite.physicsBody!.velocity = velocity
        }
    }
}