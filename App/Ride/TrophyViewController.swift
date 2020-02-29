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
    
    private static let viewSizePercentageWidth: CGFloat = 0.8
    private static let viewSizeHeight: CGFloat = 475
    
    @IBOutlet weak var miniTrophyProgressButton: TrophyProgressButton!
    @IBOutlet weak var trophyProgressButton: TrophyProgressButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var rewardExpiresLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var moreInfoTextView: UITextView!
    
    @IBOutlet weak var rewardImageView: UIImageView!
    @IBOutlet weak var rewardOrganizationName: UILabel!
    @IBOutlet weak var redeeemRewardButton: UIButton!
    @IBOutlet weak var redeemContentView: UIView!
    @IBOutlet weak var topStackView: UIStackView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var contentStackView: UIStackView!
    
    private var borderLayer: CALayer?
    
    private var shouldShowTrophyProgressView = true
    private var sparkleInColor: UIColor?
    
    var trophyProgress: TrophyProgress? = nil {
        didSet {
            refreshUI()
        }
    }
    
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
        self.miniTrophyProgressButton.delegate = self
        
        self.contentStackView.isHidden = true
        
        refreshUI()
        
        if trophyProgress != nil && trophyProgress!.count >= 1 {
            self.trophyProgressButton.layer.opacity = 0.0
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
                self.rewardImageView.image = nil
            }
        }
    }
    
    static func lastEarnedSubstring(fromDate date: Date)->String{
        if date.isToday() || date.isYesterday() {
            return date.colloquialDate()
        } else {
            return String(format:"on %@", date.colloquialDate())
        }
    }
    
    @objc func didTapMoreInfo(_ tapGesture: UIGestureRecognizer) {
        if tapGesture.state != UIGestureRecognizer.State.ended {
            return
        }
        
        if let url = trophyProgress?.moreInfoUrl {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            else {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    private func refreshUI() {
        guard let trophyProgress = trophyProgress else {
            self.activityIndicator.startAnimating()
            return
        }
        
        self.contentStackView.isHidden = false
        self.activityIndicator.stopAnimating()
        self.activityIndicator.isHidden = true
        
        self.trophyProgressButton.trophyProgress = trophyProgress
        self.trophyProgressButton.showsCount = false
        
        self.miniTrophyProgressButton.trophyProgress = trophyProgress
        self.miniTrophyProgressButton.showsCount = false
        self.miniTrophyProgressButton.isHidden = true
        
        self.trophyProgressButton.isHidden = false
        self.rewardImageView.isHidden = true
        self.rewardOrganizationName.isHidden = true
        
        self.rewardOrganizationName.sizeToFit()
        self.rewardOrganizationName.adjustsFontSizeToFitWidth = true
        
        self.descriptionLabel.sizeToFit()
        self.descriptionLabel.adjustsFontSizeToFitWidth = true

        self.redeeemRewardButton.isHidden = true
        self.redeeemRewardButton.tintColor = ColorPallete.shared.goodGreen
        
        self.shouldShowTrophyProgressView = true
        
        if let imageURL = trophyProgress.imageURL {
            self.trophyProgressButton.isHidden = true
            self.shouldShowTrophyProgressView = false
            self.rewardImageView.isHidden = false
            self.miniTrophyProgressButton.isHidden = false
            self.rewardImageView.kf.setImage(with: imageURL)
        }
        
        if let reward = trophyProgress.reward {
            if let orgName = reward.organizationName, orgName.count > 0 {
                self.rewardOrganizationName.isHidden = false
                self.rewardOrganizationName.text = orgName
            }

            if reward.instances.count > 0 {
                self.redeeemRewardButton.isHidden = false
            }
            else {
                self.redeeemRewardButton.isHidden = true
            }
            
            if trophyProgress.count > 0, let description = reward.description, description.count > 0 {
                self.descriptionLabel.isHidden = false
                self.descriptionLabel.text = description
            }
            else if trophyProgress.count == 0 {
                self.descriptionLabel.text = trophyProgress.instructions ?? TrophyProgress.emptyBodyPlaceholderString
            }
            else {
                self.descriptionLabel.isHidden = true
            }

            
            if self.borderLayer == nil {
                let borderWidth: CGFloat = 4

                let borderLayer = CAShapeLayer()
                borderLayer.fillColor = UIColor.clear.cgColor
                borderLayer.strokeColor = ColorPallete.shared.goodGreen.cgColor
                borderLayer.lineWidth = borderWidth
                borderLayer.lineJoin = CAShapeLayerLineJoin.round
                borderLayer.lineDashPattern = [10,6]
                
                self.view.clipsToBounds = false
                var frame = self.view.frame
                frame.origin.x = 0
                frame.origin.y = 0
                frame.size.height = TrophyViewController.viewSizeHeight
                
                if let presentingVC = self.presentingViewController {
                    frame.size.width = frame.size.width < presentingVC.view.frame.size.width ? frame.size.width : frame.size.width * TrophyViewController.viewSizePercentageWidth
                }

                let borderRect = frame
                
                borderLayer.bounds = borderRect
                borderLayer.position = CGPoint(x: frame.size.width/2, y: frame.size.height/2)
                borderLayer.path = UIBezierPath(roundedRect: borderRect, cornerRadius: 5).cgPath
                
                self.view.layer.addSublayer(borderLayer)
                self.borderLayer = borderLayer
            }
            
        } else if let borderLayer = self.borderLayer {
            self.borderLayer = nil
            borderLayer.removeFromSuperlayer()
        }
        
        if trophyProgress.reward == nil, trophyProgress.count == 0 {
            // trophy that is a reward and has not been earned
            self.descriptionLabel.text = trophyProgress.instructions ?? TrophyProgress.emptyBodyPlaceholderString
        }
        else if trophyProgress.reward == nil, trophyProgress.count > 0 {
            // trophy that is not a reward but has been earned
            self.descriptionLabel.text = trophyProgress.body ?? TrophyProgress.emptyBodyPlaceholderString
        }
        
        
        
        if let _ = trophyProgress.moreInfoUrl {
            moreInfoTextView.isHidden = false
        } else {
            moreInfoTextView.isHidden = true
        }
        
        if rewardOrganizationName.isHidden {
            // This is a slightly weird hack, but if we don't insert these placeholder views, the icon will not be centered if there is no organization name for a trophy
            let frontStretchingView = UIView()
            frontStretchingView.setContentHuggingPriority(UILayoutPriority(rawValue: 1), for: .horizontal)
            frontStretchingView.backgroundColor = .clear
            frontStretchingView.translatesAutoresizingMaskIntoConstraints = false
            
            let rearStretchingView = UIView()
            rearStretchingView.setContentHuggingPriority(UILayoutPriority(rawValue: 1), for: .horizontal)
            rearStretchingView.backgroundColor = .clear
            rearStretchingView.translatesAutoresizingMaskIntoConstraints = false
            
            self.topStackView.addArrangedSubview(rearStretchingView)
            self.topStackView.insertArrangedSubview(frontStretchingView, at: 0)
            self.topStackView.addConstraint(NSLayoutConstraint(item: frontStretchingView, attribute: .width, relatedBy: .equal, toItem: rearStretchingView, attribute: .width, multiplier: 1.0, constant: 0.0))
        }
        
        self.detailLabel.text = TrophyViewController.detailStringFromTrophyProgress(trophyProgress: trophyProgress)
        
        if let reward = trophyProgress.reward, let instance = reward.instances.first {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current
            dateFormatter.dateFormat = "MMM d ''yy"
            
            self.rewardExpiresLabel.isHidden = false

            if instance.voided {
                self.redeeemRewardButton.isEnabled = false
                self.redeeemRewardButton.setTitle("VOID", for: .disabled)
                self.redeeemRewardButton.setTitleColor(ColorPallete.shared.badRed, for: .disabled)
                self.redeeemRewardButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24.0)
                
                if let expiresDate = instance.expires {
                    if expiresDate < Date() {
                        self.rewardExpiresLabel.text = "Expired on " + dateFormatter.string(from: expiresDate) + "."
                    }
                    else {
                        // This probably means the coupon was voided because it was redeemed, so the future expiration date is just confusing. 
                        self.rewardExpiresLabel.isHidden = true
                    }
                }
                else if instance.voided {
                    self.rewardExpiresLabel.text = "Redeemed."
                }
                else {
                    self.rewardExpiresLabel.isHidden = true
                }
            } else {
                self.redeeemRewardButton.isEnabled = true
                self.redeemContentView.bringSubviewToFront(self.redeemContentView)
                if let expiresDate = instance.expires {

                    if expiresDate.compare(Date().daysFrom(7)) == .orderedAscending {
                        // if it's coming up in a week
                        self.rewardExpiresLabel.textColor = ColorPallete.shared.badRed
                    }
                    
                    self.rewardExpiresLabel.text = "Expires on " + dateFormatter.string(from: expiresDate) + "."
                } else {
                    self.rewardExpiresLabel.isHidden = true
                }
            }
        } else {
            self.rewardExpiresLabel.isHidden = true
        }
        
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
    static func detailStringFromTrophyProgress(trophyProgress: TrophyProgress) -> String {
        var detailString = ""
        if trophyProgress.count < 1 {
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
                    return ""
                }
                
                detailString = String(format: "You are %i%% of the way to earning this trophy for your %@ time.", Int(trophyProgress.progress * 100), countOrdinal)
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString += String(format:" You last earned this trophy %@.", TrophyViewController.lastEarnedSubstring(fromDate: lastEarnedDate))
                }
            } else if trophyProgress.count == 1 {
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString = String(format:"You earned this trophy %@.", TrophyViewController.lastEarnedSubstring(fromDate: lastEarnedDate))
                } else {
                    detailString = "You have earned this trophy."
                }
            } else if trophyProgress.count == 2 {
                detailString = String(format: "You have earned this trophy twice")
                
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString += String(format:", most recently %@.", TrophyViewController.lastEarnedSubstring(fromDate: lastEarnedDate))
                } else {
                    detailString += "."
                }
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .spellOut
                guard let countSpelled = formatter.string(from: NSNumber(value: trophyProgress.count)) else {
                    return ""
                }
                
                detailString = String(format: "You have earned this trophy %@ times", countSpelled)
                if let lastEarnedDate = trophyProgress.lastEarned {
                    detailString += String(format:", most recently %@.", lastEarnedSubstring(fromDate: lastEarnedDate))
                } else {
                    detailString += "."
                }
            }
        }
        return detailString
    }
}
