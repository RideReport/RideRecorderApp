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
    let imageSize = CGSize(width: 80.0, height: 80.0)
    
    override func viewDidLoad() {
        self.termsTextView.isSelectable = true
        self.termsTextView.isEditable = false
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(SetupTermsViewController.didTapLink(_:)))
        self.termsTextView.addGestureRecognizer(tapRecognizer)
        
        helperTextLabel.markdownStringValue = "Track your miles, map your routes, and earn ride streaks for every ride you take. Just hop on your bike – **Ride Report will start automatically**."
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .short
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        numberFormatter.maximumFractionDigits = 0
        
        if (self.scene == nil) {
            self.scene = SKScene(size: self.view.bounds.size)
            self.scene.backgroundColor = self.view.backgroundColor!
            self.scene.scaleMode = SKSceneScaleMode.resizeFill
            self.scene.delegate = self
            
            self.scene.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: self.view.bounds.origin.x, y: self.view.bounds.origin.y - bottomSpace, width: self.view.bounds.size.width, height: self.view.bounds.size.height + topSpace + bottomSpace))
            self.scene.physicsBody!.friction = 0.0
            self.scene.physicsWorld.gravity = CGVector(dx: 0,dy: 0)
            self.scene.physicsBody!.categoryBitMask = 1
            self.scene.physicsBody!.contactTestBitMask = 1|2
            self.scene.physicsWorld.contactDelegate = self
            
            
            let emojis = "🙌 🌂 🌤 🌧 ⛄️ 💧 🚴 🚲 🌈 🌠 ❤️ 💙 💜 💚 💛 🎖 🏅 🏆 🎗 💫 🍁 🎩 👒".components(separatedBy: " ")
            let fontAttributes = [NSFontAttributeName: UIFont(name: "Helvetica", size: 56)!]
            
            for emoji in emojis {
                if emoji.containsUnsupportEmoji() {
                    continue
                }
                
                let unicodeString = NSString(data: emoji.data(using: String.Encoding.nonLossyASCII)!, encoding: String.Encoding.utf8.rawValue)
                if (imageDictionary[unicodeString as! String] == nil) {
                    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                    (emoji as NSString).draw(at: CGPoint(x: 0,y: 0), withAttributes:fontAttributes)
                    
                    let emojiImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    imageDictionary[unicodeString as! String] = emojiImage
                }
                
            }
            
            let textureAtlas = SKTextureAtlas(dictionary: imageDictionary)
            textureAtlas.preload { () -> Void in
                self.spriteKitView.presentScene(self.scene)
                
                var emojisSprites : [SKSpriteNode] = []
                
                for emoji in emojis {
                    if emoji.containsUnsupportEmoji() {
                        continue
                    }
                    
                    
                    let unicodeString = NSString(data: emoji.data(using: String.Encoding.nonLossyASCII)!, encoding: String.Encoding.utf8.rawValue)
                    let texture = textureAtlas.textureNamed(unicodeString as! String)
                    
                    let emojiSize = (emoji as NSString).size(attributes: fontAttributes)
                    let insetEmojiSize = CGSize(width: emojiSize.width - 8, height: emojiSize.height - 8)
                    texture.usesMipmaps = true
                    texture.filteringMode = SKTextureFilteringMode.nearest
                    let emojiSprite = SKSpriteNode(texture: texture, size: self.imageSize)
                    emojiSprite.physicsBody = SKPhysicsBody(rectangleOf: insetEmojiSize)
                    emojiSprite.physicsBody?.collisionBitMask = 0
                    self.scene.physicsBody!.categoryBitMask = 2
                    emojiSprite.physicsBody?.linearDamping = 0.0
                    emojiSprite.position = CGPoint(x: 20.0 + CGFloat(arc4random_uniform(UInt32(self.view.frame.size.width - self.imageSize.width))), y: self.view.frame.size.height + self.topSpace - self.imageSize.height)
                    emojisSprites.append(emojiSprite)
                }
                
                var nodeCount = 0
                let shuffledEmojis = emojisSprites.shuffle()
                for emojiSprite in shuffledEmojis  {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(Double(nodeCount)*0.85 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { [weak self] in
                        guard let strongSelf = self, let strongScene = strongSelf.scene else {
                            return
                        }
                        strongScene.addChild(emojiSprite)
                        emojiSprite.physicsBody?.velocity = CGVector(dx: 0,dy: -49.9)
                    }
                    nodeCount += 1
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let _scene = self.scene {
            _scene.isPaused = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let _scene = self.scene {
            _scene.isPaused = true
            _scene.removeAllActions()
            _scene.removeAllChildren()
            _scene.removeFromParent()
            self.scene = nil
            nodesToMoveBack = []
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        // infinite waterfall - move the sprite back to the top as soon as it hits the floor
        if let node = contact.bodyB.node as? SKSpriteNode {
            nodesToMoveBack.append(node)
        }
    }
    
    func didTapLink(_ tapGesture: UIGestureRecognizer) {
        if tapGesture.state != UIGestureRecognizerState.ended {
            return
        }
        
        let tapLocation = tapGesture.location(in: self.termsTextView)
        let textPosition = self.termsTextView.closestPosition(to: tapLocation)
        if let attributes = self.termsTextView.textStyling(at: textPosition!, in: UITextStorageDirection.forward) {
            let underline = attributes[NSUnderlineStyleAttributeName] as! NSNumber?
            if (underline?.intValue == NSUnderlineStyle.styleSingle.rawValue) {
                UIApplication.shared.openURL(URL(string: "https://ride.report/legal")!)

            }
        }
    }
    
    func update(_ currentTime: TimeInterval, for scene: SKScene) {
        for node in nodesToMoveBack {
            node.physicsBody!.angularVelocity = 0
            node.position = CGPoint(x: 20.0 + CGFloat(arc4random_uniform(UInt32(self.view.frame.size.width - imageSize.width))), y: self.view.frame.size.height + self.topSpace - imageSize.height)
        }
        nodesToMoveBack = []
    }
}
