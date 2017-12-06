//
//  RewardsViewController.swift
//  Ride
//
//  Created by William Henderson on 1/6/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SpriteKit
import CoreMotion

class RewardsViewController: UIViewController, SKPhysicsContactDelegate, SKSceneDelegate
{
    @IBOutlet weak var spriteKitView: SKView!
    @IBOutlet weak var rewardPopup: PopupView!
    
    private var scene: SKScene?
    private var imageDictionary : [String: UIImage] = [:]
    private var motionManager = CMMotionManager()
    
    private var feedbackGenerator: NSObject!
    private var inflateFeedbackGenerator: NSObject!
    
    var touchPoint: CGPoint = CGPoint()
    var touchTime: TimeInterval = 0
    var touchedSprite: SKSpriteNode?
    var selectedSprite: SKSpriteNode?
    var currentVelocity: CGVector? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.light)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
            
            self.inflateFeedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy)
            (self.inflateFeedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
        
        self.rewardPopup.isHidden = true
        
        self.motionManager.deviceMotionUpdateInterval = 0.10
        
        self.title = "Trophy Snow Globe"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        if let queue = OperationQueue.current, motionManager.isAccelerometerAvailable {
            self.motionManager.startDeviceMotionUpdates(to: queue, withHandler: { [weak self] (motion, error) in
                if let scene = self?.scene, let gravity = motion?.gravity, let userAccel = motion?.userAcceleration {
                    scene.physicsWorld.gravity = CGVector(dx: 5*(gravity.x), dy: 5 * (gravity.y))
                    scene.enumerateChildNodes(withName: "//*") {
                        (node, stop) in
                        
                        let density = Double(node.physicsBody?.density ?? 0.005)
                        node.physicsBody?.applyForce(CGVector(dx: 1000.0 * userAccel.x * density, dy: 1000.0 * userAccel.y * density))
                    }
                }
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.motionManager.stopDeviceMotionUpdates()
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillLayoutSubviews()
    {
        super.viewWillLayoutSubviews()
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .short
        
        guard self.scene == nil else {
            // make sure we haven't already loaded the scene
            return
        }
        
        self.scene = SKScene(size: self.view.bounds.size)
        self.scene!.backgroundColor = self.spriteKitView.backgroundColor ?? UIColor.clear
        self.scene!.scaleMode = SKSceneScaleMode.resizeFill
        self.scene!.delegate = self
        
        self.spriteKitView.ignoresSiblingOrder = true
        
        self.scene!.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: self.view.bounds.origin.x, y: self.view.bounds.origin.y, width: self.view.bounds.size.width, height: self.view.bounds.size.height + 400))
        self.scene!.physicsBody!.friction = 0.8
        self.scene!.physicsBody!.contactTestBitMask = 1
        self.scene!.physicsBody!.restitution = 0.0
        self.scene!.physicsWorld.gravity = CGVector(dx: 0,dy: -9.8)
        self.scene!.physicsWorld.contactDelegate = self
        
        let bikeTripEmojiCounts = TripReward.tripRewardCountsGroupedByAttribute("emoji", additionalAttributes: ["descriptionText"])
        let fontAttributes = [NSAttributedStringKey.font: UIFont(name: "Helvetica", size: 48)!]
        
        let imageSize = CGSize(width: 52.0, height: 52.0) // upscale so we can grow it
        let emojiSpriteSize = CGSize(width: 30.0, height: 30.0)
        for countData in bikeTripEmojiCounts {
            if let emoji = countData["emoji"] as? String, let unicodeString = NSString(data: emoji.data(using: String.Encoding.nonLossyASCII)!, encoding: String.Encoding.utf8.rawValue) {
                if (imageDictionary[unicodeString as String] == nil) {
                    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                    (emoji as NSString).draw(at: CGPoint(x: 0,y: 0), withAttributes:fontAttributes)
                    
                    let emojiImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    imageDictionary[unicodeString as String] = emojiImage
                }
            }
        }
        
        let textureAtlas = SKTextureAtlas(dictionary: imageDictionary)
        textureAtlas.preload { () -> Void in
            self.spriteKitView.presentScene(self.scene)
            
            var emojis : [SKSpriteNode] = []
            var lastEmojiReceived : SKSpriteNode? = nil
            
            for countData in bikeTripEmojiCounts {
                if let emoji = countData["emoji"] as? String,
                    let descriptionText = countData["descriptionText"] as? String,
                    let unicodeString = NSString(data: emoji.data(using: String.Encoding.nonLossyASCII)!, encoding: String.Encoding.utf8.rawValue),
                    let count = countData["count"] as? NSNumber {
                        let texture = textureAtlas.textureNamed(unicodeString as String)
                    
                        let insetEmojiSize = CGSize(width: emojiSpriteSize.width - 8, height: emojiSpriteSize.height - 8)
                        texture.usesMipmaps = true
                        texture.filteringMode = SKTextureFilteringMode.nearest
                        for i in 0..<count.intValue {
                            if i > 5 {
                                // only show up to 5 trophies of a type
                                break
                            }
                            let emoji = SKSpriteNode(texture: texture, size: emojiSpriteSize)
                            emoji.name = descriptionText
                            emoji.physicsBody = SKPhysicsBody(rectangleOf: insetEmojiSize)
                            emoji.physicsBody!.usesPreciseCollisionDetection = false
                            emoji.physicsBody!.restitution = 0.6
                            emoji.physicsBody!.friction = 1.0
                            emoji.physicsBody!.density = 0.005
                            emoji.physicsBody!.contactTestBitMask = 1
                            emoji.physicsBody!.linearDamping = 0.0
                            emoji.physicsBody!.angularDamping = 0.0
                            emoji.physicsBody!.isDynamic = false
                            
                            emojis.append(emoji)
                        }
                }
            }
            
            lastEmojiReceived = emojis.last
            emojis.removeLast()
            
            DispatchQueue.main.async {
                var nodeCount = 0
                
                for emoji in emojis.shuffle() {
                    self.scene!.addChild(emoji)
                    
                    emoji.run(SKAction.sequence([
                        SKAction.rotate(byAngle: CGFloat(2 * Double.pi * Double(arc4random_uniform(360)) / 360.0), duration: 0.0),
                        SKAction.move(to: CGPoint(x: 20.0 + CGFloat(arc4random_uniform(UInt32(self.view.frame.size.width - 40.0))), y: 20.0 + CGFloat(arc4random_uniform(UInt32(self.view.frame.size.height - 40.0)))), duration: 0.00),
                        SKAction.run({
                            emoji.physicsBody!.isDynamic = true
                        }),
                        SKAction.unhide()]))
                    nodeCount += 1
                }
                
                guard let lastEmoji = lastEmojiReceived else {
                    return
                }
                
                let delayBeforeDroppingInLastReward: TimeInterval = 0.2
                
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delayBeforeDroppingInLastReward * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { [weak self] in
                    guard let strongSelf = self, let scene = strongSelf.scene else {
                        return
                    }
                    
                    lastEmoji.physicsBody!.density = 100.0 // make it heavy so it can knock other emoji around easily
                    lastEmoji.physicsBody!.isDynamic = true

                    scene.addChild(lastEmoji)
                    
                    strongSelf.selectedSprite = lastEmoji
                    strongSelf.rewardPopup.text = "OMG SUPER SECRET TROPHY SNOW GLOBE"
                    strongSelf.rewardPopup.sizeToFit()
                    strongSelf.rewardPopup.popIn()
                    strongSelf.rewardPopup.delay(4.0) {
                        if strongSelf.touchedSprite == nil {
                            strongSelf.rewardPopup.fadeOut()
                        }
                    }
                    
                    lastEmoji.run(SKAction.sequence([
                        SKAction.unhide(),
                        SKAction.move(to: CGPoint(x: (strongSelf.view.frame.size.width - lastEmoji.size.width) / 2.0, y: strongSelf.view.frame.size.height / 2.0 - 40), duration: 0.001),
                        SKAction.scale(to: 4.0, duration: 0.0)]))
                    
                }
            }
        } //end of preloadWithCompletionHandler block        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let scene = self.scene else {
            return
        }
        
        if self.selectedSprite != nil {
            self.selectedSprite!.physicsBody!.density = 0.005
            self.selectedSprite?.run(SKAction.scale(to: 1.0, duration: 0.2))
            
            self.selectedSprite = nil
        }
        
        let touch = touches.first!
        let point = touch.location(in: scene)
        if let tappedSprite = scene.atPoint(point) as? SKSpriteNode {
            if #available(iOS 10.0, *) {
                if let feedbackGenerator = self.inflateFeedbackGenerator as? UIImpactFeedbackGenerator {
                    feedbackGenerator.impactOccurred()
                }
            }
            self.touchPoint = point
            self.touchTime = touch.timestamp
            self.touchedSprite = tappedSprite
            self.selectedSprite = tappedSprite
            self.touchedSprite!.physicsBody!.density = 100.0 // make it heavy so it can knock other emoji around easily
            self.currentVelocity = CGVector(dx: 0, dy: 0)
            if #available(iOS 9.0, *) {
                self.touchedSprite?.run(SKAction.scale(to: 4.0, duration: 0.2))
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
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let scene = self.scene else {
            return
        }
        
        if let touchedSprite = self.touchedSprite {
            let touch = touches.first!
            var point = touch.location(in: scene)
            
            // avoid the crazy edge dragging thing by constraining point within the scene
            point.x = min(point.x, scene.size.width - touchedSprite.size.width/2)
            point.x = max(point.x, touchedSprite.size.width/2)
            point.y = min(point.y, scene.size.height - touchedSprite.size.height/2)
            point.y = max(point.y, touchedSprite.size.height/2)
            
            let dt:CGFloat = CGFloat(touch.timestamp - self.touchTime)
            let distance = CGVector(dx: point.x - touchedSprite.position.x, dy: point.y - touchedSprite.position.y)
            self.currentVelocity = CGVector(dx: distance.dx/dt, dy: distance.dy/dt)
            self.touchTime = touch.timestamp
            self.touchPoint = point
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = self.scene else {
            return
        }
        
        self.rewardPopup.delay(1) {
            if self.touchedSprite == nil {
                self.rewardPopup.fadeOut()
            }
        }
        
        if self.touchedSprite != nil {
            self.touchedSprite = nil
            self.currentVelocity = nil
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        if let selectedSprite = self.touchedSprite, contact.bodyB == selectedSprite.physicsBody {
            if #available(iOS 10.0, *) {
                if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                    feedbackGenerator.impactOccurred()
                }
            }
        }
    }
    
    func update(_ currentTime: TimeInterval, for scene: SKScene) {
        if let touchedSprite = self.touchedSprite,
            let velocity = self.currentVelocity {
            touchedSprite.physicsBody!.velocity = velocity
        }
    }
}
