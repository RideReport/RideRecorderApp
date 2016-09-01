//
//  NotificationViewController.swift
//  Ride Report Notification Content
//
//  Created by William Henderson on 8/31/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import SpriteKit


class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var scene: SKScene?
    @IBOutlet weak var spriteKitView: SKView!
    private var imageDictionary : [String: UIImage] = [:]
    
    @IBOutlet var rideEmojiLabel: UILabel!
    @IBOutlet var rideDescriptionLabel: UILabel!
    @IBOutlet var rewardDescriptionLabel: UILabel!
    //@IBOutlet var bottomSpaceConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rewardDescriptionLabel.hidden = true
    }
    
    func didReceiveNotification(notification: UNNotification) {
        if let rideDescription = notification.request.content.userInfo["rideDescription"] as? String,
            let rideEmoji = notification.request.content.userInfo["rideEmoji"] as? String {
            
            rideEmojiLabel.text = rideEmoji ?? ""
            rideDescriptionLabel.text = rideDescription
            
            if let rewardDescription = notification.request.content.userInfo["rewardDescription"] as? String,
                let rewardEmoji = notification.request.content.userInfo["rewardEmoji"] as? String {
                rewardDescriptionLabel.text = rewardDescription
                //bottomSpaceConstraint?.constant = 14
                preferredContentSize = CGSize(width: view.bounds.width, height: view.bounds.width)
                
                rewardDescriptionLabel.delay(1) { self.rewardDescriptionLabel.popIn(1.2) }
                showEmoji(rewardEmoji)
            } else {
                rewardDescriptionLabel.text = ""
                //bottomSpaceConstraint?.constant = 0
            }
        } else {
            self.rideDescriptionLabel.text = notification.request.content.body
            rewardDescriptionLabel.text = ""
            //bottomSpaceConstraint?.constant = 0
        }
    }
    
    private func showEmoji(rewardEmoji: String) {
        guard self.scene == nil else {
            // make sure we haven't already loaded the scene
            return
        }
        
        self.scene = SKScene(size: self.view.bounds.size)
        self.scene!.backgroundColor = self.spriteKitView.backgroundColor!
        self.scene!.scaleMode = SKSceneScaleMode.ResizeFill
        
        self.spriteKitView.ignoresSiblingOrder = true
        
        let topSpace : CGFloat = 400.0
        
        self.scene!.physicsBody = SKPhysicsBody(edgeLoopFromRect: CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, self.preferredContentSize.height + topSpace))
        self.scene!.physicsBody!.friction = 0.8
        self.scene!.physicsBody!.restitution = 0.0
        self.scene!.physicsWorld.gravity = CGVectorMake(0,-9.8)
        
        let fontAttributes = [NSFontAttributeName: UIFont(name: "Helvetica", size: 48)!]
        
        let imageSize = CGSizeMake(52.0, 52.0) // upscale so we can grow it
        let emojiSpriteSize = CGSizeMake(30.0, 30.0)
        for emoji in [rewardEmoji, "🏆"] {
            let unicodeString = NSString(data: emoji.dataUsingEncoding(NSNonLossyASCIIStringEncoding)!, encoding: NSUTF8StringEncoding)
            if (imageDictionary[unicodeString as! String] == nil) {
                UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                (emoji as NSString).drawAtPoint(CGPointMake(0,0), withAttributes:fontAttributes)
                
                let emojiImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                imageDictionary[unicodeString as! String] = emojiImage
            }
        }
        
        let textureAtlas = SKTextureAtlas(dictionary: imageDictionary)
        textureAtlas.preloadWithCompletionHandler { () -> Void in
            self.spriteKitView.presentScene(self.scene)
            
            var emojis : [SKSpriteNode] = []
            var lastEmojiReceived : SKSpriteNode? = nil
            
            let bikeTripEmojiCounts = [["emoji": "🏆", "count" : 50], ["emoji": rewardEmoji, "count" : 1]]
            
            for countData in bikeTripEmojiCounts {
                if let emoji = countData["emoji"] as? String,
                    let count = countData["count"] as? NSNumber {
                    let unicodeString = NSString(data: emoji.dataUsingEncoding(NSNonLossyASCIIStringEncoding)!, encoding: NSUTF8StringEncoding)
                    let texture = textureAtlas.textureNamed(unicodeString as! String)
                    
                    let insetEmojiSize = CGSizeMake(emojiSpriteSize.width - 8, emojiSpriteSize.height - 8)
                    texture.usesMipmaps = true
                    texture.filteringMode = SKTextureFilteringMode.Nearest
                    for _ in 0..<count.integerValue {
                        let emoji = SKSpriteNode(texture: texture, size: emojiSpriteSize)
                        emoji.physicsBody = SKPhysicsBody(rectangleOfSize: insetEmojiSize)
                        emoji.physicsBody!.usesPreciseCollisionDetection = false
                        emoji.physicsBody!.restitution = 0.6
                        emoji.physicsBody!.friction = 0.8
                        emoji.physicsBody!.density = 0.005
                        emoji.physicsBody!.linearDamping = 0.3
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
                var lineCount = 0
                var xCount = 0
                let moundSteepnessCoefficient: CGFloat = 0.3
                for emoji in emojis {
                    self.scene!.addChild(emoji)
                    
                    let targetWidth = self.view.frame.size.width / (moundSteepnessCoefficient*CGFloat(lineCount) + 1)
                    let inset = (self.view.frame.size.width - targetWidth)/2.0
                    var nodePlacementX = inset + emoji.size.width + (CGFloat(xCount) * (emoji.size.width + emojiInitialPadding))
                    if nodePlacementX > targetWidth + inset {
                        lineCount += 1
                        xCount = 0
                        nodePlacementX = inset + emoji.size.width
                    } else {
                        xCount += 1
                    }
                    let targetPoint = CGPointMake(nodePlacementX, emoji.size.height + (emoji.size.height + emojiInitialPadding) * CGFloat(lineCount))
                    
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
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delayBeforeDroppingInLastReward * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
                    guard let strongSelf = self, scene = strongSelf.scene else {
                        return
                    }
                    
                    lastEmoji.physicsBody!.density = 200.0
                    lastEmoji.physicsBody!.dynamic = true
                    
                    scene.addChild(lastEmoji)
                                        
                    lastEmoji.runAction(SKAction.sequence([
                        SKAction.scaleTo(4.0, duration: 0.0),
                        SKAction.moveTo(CGPointMake((strongSelf.view.frame.size.width - lastEmoji.size.width) / 2.0, strongSelf.preferredContentSize.height + topSpace - 40), duration: 0.001)]))
                    
                }
            }
        } //end of preloadWithCompletionHandler block
    }

}
