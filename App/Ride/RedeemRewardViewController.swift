//
//  RedeemRewardViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON
import Presentr
import CocoaLumberjack

class RedeemRewardViewController: UIViewController, PresentrDelegate {
    private static let viewSizePercentageWidth: CGFloat = 0.8
    private static let viewSizeHeight: CGFloat = 475

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var organizationNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var couponMessageLabel: AnimatedGradientLabel!
    @IBOutlet weak var couponTitleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var expiresLabel: UILabel!
    @IBOutlet weak var miniTrophyProgressButton: TrophyProgressButton!
    @IBOutlet weak var topStackView: UIStackView!
    @IBOutlet weak var moreInfoTextView: UITextView!
    
    private var dateFormatter : DateFormatter!
    
    var trophyProgress: TrophyProgress? = nil {
        didSet {
            refreshUI()
        }
    }
    
    static func presenter()-> Presentr {
        let width = ModalSize.fluid(percentage: Float(RedeemRewardViewController.viewSizePercentageWidth))
        let height = ModalSize.custom(size: 475)
        let center = ModalCenterPosition.center
        let customType = PresentationType.custom(width: width, height: height, center: center)
        
        let customPresenter = Presentr(presentationType: customType)
        customPresenter.transitionType = .flipHorizontal
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
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d ''yy"
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(TrophyViewController.didTapMoreInfo(_:)))
        self.moreInfoTextView.addGestureRecognizer(tapRecognizer)
        self.moreInfoTextView.isSelectable = true
        self.moreInfoTextView.isEditable = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
        frame.size.width = frame.size.width * RedeemRewardViewController.viewSizePercentageWidth
        frame.size.height = RedeemRewardViewController.viewSizeHeight
        let borderRect = frame
        
        borderLayer.bounds = borderRect
        borderLayer.position = CGPoint(x: frame.size.width/2, y: frame.size.height/2)
        borderLayer.path = UIBezierPath(roundedRect: borderRect, cornerRadius: 5).cgPath
        
        self.view.layer.addSublayer(borderLayer)
    }
    
    private func refreshUI() {
        guard let trophyProgress = self.trophyProgress else {
            self.activityIndicator.startAnimating()
            return
        }
        
        self.miniTrophyProgressButton.trophyProgress = trophyProgress
        self.miniTrophyProgressButton.showsCount = false
        self.activityIndicator.stopAnimating()
        self.activityIndicator.isHidden = true
        
        if let _ = trophyProgress.moreInfoUrl {
            moreInfoTextView.isHidden = false
        } else {
            moreInfoTextView.isHidden = true
        }
        
        if let reward = trophyProgress.reward, let rewardInstance = reward.instances.first, case .coupon(let title, let message, _) = rewardInstance.type  {
            if let expiresDate = rewardInstance.expires  {
                if expiresDate.compare(Date().daysFrom(7)) == .orderedAscending {
                    // if it's coming up in a week
                    expiresLabel.textColor = ColorPallete.shared.badRed
                }
                
                expiresLabel.text = "Expires on " + dateFormatter.string(from: expiresDate)
            } else {
                expiresLabel.isHidden = true
            }
            
            let detailText = TrophyViewController.detailStringFromTrophyProgress(trophyProgress: trophyProgress)
            if detailText.count > 0 {
                detailLabel.isHidden = false
                detailLabel.text = detailText
            } else {
                detailLabel.isHidden = true
            }
            
            if let organizationName = reward.organizationName {
                organizationNameLabel.isHidden = false
                organizationNameLabel.text = organizationName
            } else {
                organizationNameLabel.isHidden = true
            }
            
            if let imageURLString = trophyProgress.imageURL?.absoluteString, let url = URL(string: imageURLString) {
                imageView.kf.setImage(with: url)
            } else {
                imageView.isHidden = true
            }
            
            if let description = reward.description, description.count > 0 {
                self.descriptionLabel.isHidden = false
                self.descriptionLabel.text = description
            } else {
                self.descriptionLabel.isHidden = true
            }
            self.descriptionLabel.adjustsFontSizeToFitWidth = true
            
            if title.count > 0 {
                self.couponTitleLabel.isHidden = false
                self.couponTitleLabel.text = title
            } else {
                self.couponTitleLabel.isHidden = true
            }
            
            self.couponMessageLabel.text = message
            self.couponMessageLabel.textColor = ColorPallete.shared.notificationActionGrey
            self.couponMessageLabel.adjustsFontSizeToFitWidth = true
            self.couponMessageLabel.minimumScaleFactor = 0.5
            self.couponMessageLabel.attributedText = NSAttributedString(string: message, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 80)])
            self.couponMessageLabel.direction = .leftToRight
            self.couponMessageLabel.shouldAnimateContinuously = true
            self.couponMessageLabel.gradientColor = ColorPallete.shared.brightBlue
            self.couponMessageLabel.duration = 2.0
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
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}
