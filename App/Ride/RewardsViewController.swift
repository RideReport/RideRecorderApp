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

    private var scene: SKScene!
    
    var touchPoint: CGPoint = CGPoint()
    var touchTime: NSTimeInterval = 0
    var touchedSprite: SKSpriteNode?
    var currentVelocity: CGVector? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "🏆 Trophy Room"
    }
    
    override func viewWillLayoutSubviews()
    {
        super.viewWillLayoutSubviews()
        
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
        
        if Profile.profile().longestStreakLength.integerValue > 0 {
            self.rewardsLabel2.text = String(format: "%@  Longest streak: %i days on %@", Profile.profile().longestStreakJewel, Profile.profile().longestStreakLength.integerValue, dateFormatter.stringFromDate(Profile.profile().longestStreakStartDate))
        } else {
            self.rewardsLabel2.hidden = true
        }
        
        if (self.scene == nil) {
            self.scene = SKScene(size: self.view.bounds.size)
            self.scene.scaleMode = SKSceneScaleMode.ResizeFill
            self.scene.delegate = self
            
//            self.spriteKitView.showsFPS = true
//            self.spriteKitView.showsDrawCount = true
//            self.spriteKitView.showsNodeCount = true
//            self.spriteKitView.showsQuadCount = true
            
            let topSpace : CGFloat = 400.0
            
            self.scene.physicsBody = SKPhysicsBody(edgeLoopFromRect: CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, self.view.bounds.size.height + topSpace))
            self.scene.physicsBody!.friction = 0.2
            self.scene.physicsWorld.gravity = CGVectorMake(0,-9.8)
            
            var i = 0
            
            var imageDictionary : [String: UIImage] = [:]
            let bikeTripEmojiCounts = Trip.bikeTripCountsGroupedByProperty("rewardEmoji")
            let fontAttributes = [NSFontAttributeName: UIFont(name: "Helvetica", size: 26)!]
            
            let imageSize = CGSizeMake(30.0, 30.0)
            for countData in bikeTripEmojiCounts {
                if let rewardEmoji = countData["rewardEmoji"] as? String {
                    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                    (rewardEmoji as NSString).drawAtPoint(CGPointMake(0,0), withAttributes:fontAttributes)
                    
                    let emojiImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    imageDictionary[String(i)] = emojiImage
                    
                    i++
                }
            }
            
            i = 0
            
            let textureAtlas = SKTextureAtlas(dictionary: imageDictionary)
            textureAtlas.preloadWithCompletionHandler { () -> Void in
                self.spriteKitView.presentScene(self.scene)
                
                var emojis : [SKSpriteNode] = []
                
                for countData in bikeTripEmojiCounts {
                    if let rewardEmoji = countData["rewardEmoji"] as? String,
                        let count = countData["count"] as? NSNumber {
                            
                        let emojiSize = (rewardEmoji as NSString).sizeWithAttributes(fontAttributes)
                        let insetEmojiSize = CGSizeMake(emojiSize.width - 8, emojiSize.height - 8)
                        let texture = textureAtlas.textureNamed(String(i))
                        texture.usesMipmaps = true
                        texture.filteringMode = SKTextureFilteringMode.Nearest
                        for _ in 0..<count.integerValue {
                            let emoji = SKSpriteNode(texture: texture, size: imageSize)
                            emoji.physicsBody = SKPhysicsBody(rectangleOfSize: insetEmojiSize)
                            emoji.position = CGPointMake(20.0 + CGFloat(arc4random_uniform(UInt32(self.view.frame.size.width - 40.0))), self.view.frame.size.height + topSpace - 40)
                            emojis.append(emoji)
                        }
                        i++
                    }
                }
                
                var nodeCount = 0
                let shuffledEmojis = emojis.shuffle()
                for emoji in shuffledEmojis  {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(nodeCount)*0.01 * Double(NSEC_PER_SEC))),      dispatch_get_main_queue()) { () -> Void in
                            self.scene.addChild(emoji)
                    }
                    nodeCount++
                }
            }
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first!
        let point = touch.locationInNode(self.scene)
        if let tappedSprite = self.scene.nodeAtPoint(point) as? SKSpriteNode {
            self.touchPoint = point
            self.touchTime = touch.timestamp
            self.touchedSprite = tappedSprite
        }
    }
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touchedSprite = self.touchedSprite {
            let touch = touches.first!
            let point = touch.locationInNode(self.scene)
            
            let dt:CGFloat = CGFloat(touch.timestamp - self.touchTime)
            let distance = CGVector(dx: point.x - touchedSprite.position.x, dy: point.y - touchedSprite.position.y)
            self.currentVelocity = CGVector(dx: distance.dx/dt, dy: distance.dy/dt)
            self.touchTime = touch.timestamp
            self.touchPoint = point
        }
    }
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.touchedSprite = nil
        self.currentVelocity = nil
    }
    
    func update(currentTime: NSTimeInterval, forScene scene: SKScene) {
        if let touchedSprite = self.touchedSprite,
        let velocity = self.currentVelocity {
            touchedSprite.physicsBody!.velocity = velocity
        }
    }
}