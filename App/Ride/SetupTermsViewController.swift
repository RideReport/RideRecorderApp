//
//  SetupTermsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SpriteKit

class SetupTermsViewController: SetupChildViewController, UITextViewDelegate, SKPhysicsContactDelegate, SKSceneDelegate {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var termsTextView : UITextView!
    @IBOutlet weak var spriteKitView: SKView!
    private var scene: SKScene!
    private var imageDictionary : [String: UIImage] = [:] // storing this works around a crash on iOS 8.4 devices
    
    var nodesToMoveBack : [SKSpriteNode] = []
    
    let topSpace : CGFloat = 100
    let bottomSpace : CGFloat = 100
    
    override func viewDidLoad() {
        self.termsTextView.selectable = true
        self.termsTextView.editable = false
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(SetupTermsViewController.didTapLink(_:)))
        self.termsTextView.addGestureRecognizer(tapRecognizer)
        
        helperTextLabel.markdownStringValue = "Track your miles, map your routes, and earn ride streaks for every ride you take. Just hop on your bike – **Ride Report will start automatically**."
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale.currentLocale()
        dateFormatter.dateStyle = .ShortStyle
        
        let numberFormatter = NSNumberFormatter()
        numberFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        numberFormatter.maximumFractionDigits = 0
        
        if (self.scene == nil) {
            self.scene = SKScene(size: self.view.bounds.size)
            self.scene.backgroundColor = self.view.backgroundColor!
            self.scene.scaleMode = SKSceneScaleMode.ResizeFill
            self.scene.delegate = self
            
            self.scene.physicsBody = SKPhysicsBody(edgeLoopFromRect: CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y - bottomSpace, self.view.bounds.size.width, self.view.bounds.size.height + topSpace + bottomSpace))
            self.scene.physicsBody!.friction = 1.0
            self.scene.physicsBody!.categoryBitMask = 1
            self.scene.physicsBody!.collisionBitMask = 1|2
            self.scene.physicsBody!.contactTestBitMask = 1|2
            self.scene.physicsWorld.gravity = CGVectorMake(0,-0.4)
            self.scene.physicsWorld.contactDelegate = self
            
            
            let emojis = "👍 👎 🙌 🌂 🍄 🌤 🌧 ⛄️ 💧 🚴 🚲 🚀 🌈 🌠 🎉 ❤️ 💙 💜 💚 💛 📢 🎖 🏅 🏆 🎗 💫 🍁 🎩 👻 👒".componentsSeparatedByString(" ")
            let fontAttributes = [NSFontAttributeName: UIFont(name: "Helvetica", size: 36)!]
            
            let imageSize = CGSizeMake(40.0, 40.0)
            for emoji in emojis {
                if emoji.containsUnsupportEmoji() {
                    continue
                }
                
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
                
                var emojisSprites : [SKSpriteNode] = []
                
                for emoji in emojis {
                    if emoji.containsUnsupportEmoji() {
                        continue
                    }
                    
                    
                    let unicodeString = NSString(data: emoji.dataUsingEncoding(NSNonLossyASCIIStringEncoding)!, encoding: NSUTF8StringEncoding)
                    let texture = textureAtlas.textureNamed(unicodeString as! String)
                    
                    let emojiSize = (emoji as NSString).sizeWithAttributes(fontAttributes)
                    let insetEmojiSize = CGSizeMake(emojiSize.width - 8, emojiSize.height - 8)
                    texture.usesMipmaps = true
                    texture.filteringMode = SKTextureFilteringMode.Nearest
                    for _ in 0...1 {
                        let emojiSprite = SKSpriteNode(texture: texture, size: imageSize)
                        emojiSprite.physicsBody = SKPhysicsBody(rectangleOfSize: insetEmojiSize)
                        self.scene.physicsBody!.categoryBitMask = 2
                        emojiSprite.position = CGPointMake(20.0 + CGFloat(arc4random_uniform(UInt32(self.view.frame.size.width - 40.0))), self.view.frame.size.height + self.topSpace - 40)
                        emojisSprites.append(emojiSprite)
                    }
                }
                
                var nodeCount = 0
                let shuffledEmojis = emojisSprites.shuffle()
                for emojiSprite in shuffledEmojis  {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(nodeCount)*0.25 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
                        guard let strongSelf = self, strongScene = strongSelf.scene else {
                            return
                        }
                        
                        strongScene.addChild(emojiSprite)
                    }
                    nodeCount += 1
                }
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let _scene = self.scene {
            _scene.paused = false
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let _scene = self.scene {
            _scene.paused = true
            _scene.removeAllActions()
            _scene.removeAllChildren()
            _scene.removeFromParent()
            self.scene = nil
            nodesToMoveBack = []
        }
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        // infinite waterfall - move the sprite back to the top as soon as it hits the floor
        if let node = contact.bodyB.node as? SKSpriteNode {
            nodesToMoveBack.append(node)
        }
    }
    
    func didTapLink(tapGesture: UIGestureRecognizer) {
        if tapGesture.state != UIGestureRecognizerState.Ended {
            return
        }
        
        let tapLocation = tapGesture.locationInView(self.termsTextView)
        let textPosition = self.termsTextView.closestPositionToPoint(tapLocation)
        if let attributes = self.termsTextView.textStylingAtPosition(textPosition!, inDirection: UITextStorageDirection.Forward) {
            let underline = attributes[NSUnderlineStyleAttributeName] as! NSNumber?
            if (underline?.integerValue == NSUnderlineStyle.StyleSingle.rawValue) {
                UIApplication.sharedApplication().openURL(NSURL(string: "https://ride.report/legal")!)

            }
        }
    }
    
    func update(currentTime: NSTimeInterval, forScene scene: SKScene) {
        for node in nodesToMoveBack {
            node.physicsBody!.velocity = CGVector(dx: 0, dy: 0)
            node.physicsBody!.angularVelocity = 0
            node.position = CGPointMake(20.0 + CGFloat(arc4random_uniform(UInt32(self.view.frame.size.width - 40.0))), self.view.frame.size.height + self.topSpace - 40)
        }
        nodesToMoveBack = []
    }
}