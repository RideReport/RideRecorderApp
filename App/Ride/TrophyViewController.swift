//
//  TrophyViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON
import Presentr
import CocoaLumberjack

class TrophyViewController: UIViewController, TrophyProgressButtonDelegate {
    var trophyProgress: TrophyProgress? = nil
    
    private static let viewSizePercentageWidth: CGFloat = 0.8
    private static let viewSizePercentageHeight: CGFloat = 0.2
    
    @IBOutlet weak var trophyProgressButton: TrophyProgressButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var moreInfoTextView: UITextView!
    
    @IBOutlet weak var rewardImageView: UIImageView!
    @IBOutlet weak var rewardOrganizationName: UILabel!
    @IBOutlet weak var rewardDescriptionLabel: UILabel!
    
    private var shouldShowTrophyProgressView = true
    private var sparkleInColor: UIColor?
    
    static func presenter()-> Presentr {
        let width = ModalSize.fluid(percentage: Float(TrophyViewController.viewSizePercentageWidth))
        let height = ModalSize.custom(size: 475)
        let center = ModalCenterPosition.center
        let customType = PresentationType.custom(width: width, height: height, center: center)
        
        let customPresenter = Presentr(presentationType: customType)
        customPresenter.transitionType = .coverVertical
        customPresenter.dismissTransitionType = .coverVertical
        customPresenter.dismissOnSwipe = true
        customPresenter.dismissOnSwipeDirection = .bottom
        customPresenter.roundCorners = true
        customPresenter.backgroundColor = ColorPallete.shared.darkGrey
        customPresenter.backgroundOpacity = 0.8
        
        return customPresenter
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(TrophyViewController.didTapMoreInfo(_:)))
        self.moreInfoTextView.addGestureRecognizer(tapRecognizer)
        self.moreInfoTextView.isSelectable = true
        self.moreInfoTextView.isEditable = false
        
        self.trophyProgressButton.delegate = self
        
        refreshUI()
        
        if trophyProgress != nil && trophyProgress!.count >= 1 {
            self.trophyProgressButton.layer.opacity = 0.0
        }
    }
    
    let sparkleDX: CGFloat = -40
    let sparkleDY: CGFloat = -60
    func didFinishInitialRendering(color: UIColor?) {
        let sparkleColor = color ?? ColorPallete.shared.brightBlue
        self.sparkleInColor = sparkleColor
        if shouldSparkleIn {
            self.view.sparkle(sparkleColor, inRect: self.trophyProgressButton.frame.insetBy(dx: sparkleDX, dy: sparkleDY))
        }
    }
    
    private var shouldSparkleIn = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let trophyProgress = trophyProgress else {
            return
        }
        
        if shouldShowTrophyProgressView {
            if trophyProgress.count >= 1 {
                self.trophyProgressButton.fadeIn()
                if let color = sparkleInColor {
                    self.view.sparkle(color, inRect: self.trophyProgressButton.frame.insetBy(dx: sparkleDX, dy: sparkleDY))
                } else {
                    shouldSparkleIn = true
                }
            } else {
                self.trophyProgressButton.isHidden = false
            }
        }
    }
    
    private func lastEarnedSubstring(fromDate date: Date)->String{
        if date.isToday() || date.isYesterday() {
            return date.colloquialDate()
        } else {
            return String(format:"on %@", date.colloquialDate())
        }
    }
    
    @objc func didTapMoreInfo(_ tapGesture: UIGestureRecognizer) {
        if tapGesture.state != UIGestureRecognizerState.ended {
            return
        }
        
        if let url = trophyProgress?.moreInfoUrl {
            UIApplication.shared.openURL(url)
        }
    }
    
    private func refreshUI() {
        guard let trophyProgress = trophyProgress else {
            return
        }
        
        self.trophyProgressButton.trophyProgress = trophyProgress
        self.trophyProgressButton.showsCount = false
        
        self.descriptionLabel.text = trophyProgress.body ?? TrophyProgress.emptyBodyPlaceholderString
        
        self.trophyProgressButton.isHidden = false
        self.rewardImageView.isHidden = true
        self.rewardOrganizationName.isHidden = true
        self.rewardDescriptionLabel.superview?.isHidden = true
        self.shouldShowTrophyProgressView = true
        
        var hasReward = false
        if let reward = trophyProgress.reward {
            hasReward = true
            if let imageURL = reward.imageURL {
                self.trophyProgressButton.isHidden = true
                self.shouldShowTrophyProgressView = false
                self.rewardImageView.isHidden = false
                self.rewardImageView.kf.setImage(with: imageURL)
            }
            if let orgName = reward.organizationName {
                self.rewardOrganizationName.isHidden = false
                self.rewardOrganizationName.text = orgName
            }
            
            self.rewardDescriptionLabel.superview?.isHidden = false
            self.rewardDescriptionLabel.text = reward.description
        }
        
        if let _ = trophyProgress.moreInfoUrl {
            moreInfoTextView.superview?.isHidden = false
        } else {
            moreInfoTextView.superview?.isHidden = true
        }
        
        var detailString = ""
        if trophyProgress.count < 1 {
            if let instructions = trophyProgress.instructions {
                self.descriptionLabel.text = instructions
            }
            
            if trophyProgress.progress > 0 {
                detailString = String(format: "You are %i%% of the way to earning this trophy.", Int(trophyProgress.progress * 100))
            } else {
                detailString = "You have not earned this trophy."
            }
        } else {
            if trophyProgress.progress > 0 && trophyProgress.progress < 1 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .ordinal
                guard let countOrdinal = formatter.string(from: NSNumber(value: trophyProgress.count + 1)) else {
                    self.detailLabel.text = ""
                    return
                }
                
                detailString = String(format: "You are %i%% of the way to earning this trophy for your %@ time.", Int(trophyProgress.progress * 100), countOrdinal)
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString += String(format:" You last earned this trophy %@.", lastEarnedSubstring(fromDate: lastEarnedDate))
                }
            } else if trophyProgress.count == 1 {
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString = String(format:"You earned this trophy %@.", lastEarnedSubstring(fromDate: lastEarnedDate))
                } else {
                    detailString = "You have earned this trophy."
                }
            } else if trophyProgress.count == 2 {
                detailString = String(format: "You have earned this trophy twice")
                
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString += String(format:", most recently %@.", lastEarnedSubstring(fromDate: lastEarnedDate))
                } else {
                    detailString += "."
                }
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .spellOut
                guard let countSpelled = formatter.string(from: NSNumber(value: trophyProgress.count)) else {
                    self.detailLabel.text = ""
                    return
                }
                
                detailString = String(format: "You have earned this trophy %@ times", countSpelled)
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString += String(format:", most recently %@.", lastEarnedSubstring(fromDate: lastEarnedDate))
                } else {
                    detailString += "."
                }
            }
        }
        
        if hasReward {
            detailString = detailString.replacingOccurrences(of: "trophy", with: "reward")
        }
        
        self.detailLabel.text = detailString
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}
