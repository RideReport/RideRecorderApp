//
//  RedeemRewardViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

class RedeemRewardViewController: UIViewController {
    var tripReward: TripReward?
    
    private var rewardJSON: JSON?

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var organizationNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var couponMessageLabel: UILabel!
    @IBOutlet weak var couponTitleLabel: UILabel!
    @IBOutlet weak var expiresLabel: UILabel!
    
    private var dateFormatter : DateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d ''yy"
        
        contentView.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let tripReward = self.tripReward, let uuid = tripReward.rewardUUID {
            APIClient.shared.getReward(uuid: uuid, completionHandler: {
                [weak self] (response) in
                switch response.result {
                case .success(let json):
                    if let strongSelf = self {
                        strongSelf.contentView.isHidden = false
                        strongSelf.activityIndicator.isHidden = true
                        
                        strongSelf.rewardJSON = json
                        strongSelf.refreshUI()
                    }
                case .failure(_):
                    DDLogWarn("Error retriving getting reward!")
                    if let strongSelf = self {
                        let alert = UIAlertView(title:nil, message: "Your reward could not be loaded. Please check that you are connected to the internet and try again.", delegate: nil, cancelButtonTitle:"Darn")
                        alert.show()
                        
                        strongSelf.cancel(strongSelf)
                    }
                }
            })
        }
    }
    
    private func refreshUI() {
        guard let json = rewardJSON else {
            return
        }
        
        
        if let voided = json["voided"].bool, voided {
            self.cancel(self)
            let alert = UIAlertView(title:nil, message: "This reward has expired.", delegate: nil, cancelButtonTitle:"Darn")
            alert.show()
            
            return
        }
        
        if let expiresString = json["expires"].string, let expiresDate = Date.dateFromJSONString(expiresString) {
            if expiresDate.compare(Date().daysFrom(14)) == .orderedAscending {
                // if it's coming up in a week
                expiresLabel.textColor = ColorPallete.shared.badRed
            }
            
            expiresLabel.text = "Expires on " + dateFormatter.string(from: expiresDate)
        } else {
            expiresLabel.isHidden = true
        }
        
        if let text = json["organization_name"].string {
            organizationNameLabel.text = text
        } else {
            organizationNameLabel.isHidden = true
        }
        
        if let imageURLString = json["image_url"].string, let url = URL(string: imageURLString) {
            imageView.kf.setImage(with: url)
        } else {
            imageView.isHidden = true
        }
        
        if let text = json["description"].string {
            descriptionLabel.text = text
        } else {
            descriptionLabel.isHidden = true
        }
        
        if let coupon = json["coupon"].dictionary, let title = coupon["title"]?.string, let message = coupon["message"]?.string {
            couponTitleLabel.text = title
            couponMessageLabel.text = message
        } else {
            couponTitleLabel.isHidden = true
            couponMessageLabel.isHidden = true
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}
