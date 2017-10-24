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

class TrophyViewController: UIViewController {
    var trophyProgress: TrophyProgress? = nil
    
    private static let viewSizePercentageWidth: CGFloat = 0.8
    private static let viewSizePercentageHeight: CGFloat = 0.2
    
    @IBOutlet weak var trophyProgressButton: TrophyProgressButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    
    private var dateFormatter : DateFormatter!
    
    static func presenter()-> Presentr {
        let width = ModalSize.fluid(percentage: Float(TrophyViewController.viewSizePercentageWidth))
        let height = ModalSize.custom(size: 375)
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
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d ''yy"
        
        refreshUI()
        
        if trophyProgress != nil && trophyProgress!.count >= 1 {
            self.trophyProgressButton.isHidden = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let trophyProgress = trophyProgress else {
            return
        }
        
        if trophyProgress.count >= 1 {
            self.view.sparkle(ColorPallete.shared.brightBlue, inRect: self.trophyProgressButton.frame.insetBy(dx: -30, dy: -30))
            self.trophyProgressButton.fadeIn()
        } else {
            self.trophyProgressButton.isHidden = false
        }
    }
    
    private func refreshUI() {
        guard let trophyProgress = trophyProgress else {
            return
        }
        
        self.trophyProgressButton.trophyProgress = trophyProgress
        self.trophyProgressButton.showsCount = false
        
        self.descriptionLabel.text = trophyProgress.body
        
        if trophyProgress.count < 1 {
            if trophyProgress.progress > 0 {
                self.detailLabel.text = String(format: "You are %i%% of the way to earning this trophy.", Int(trophyProgress.progress * 100))
            } else {
                self.detailLabel.text = "You have never earned this trophy."
            }
        } else {
            if trophyProgress.progress > 0 && trophyProgress.progress < 1 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .ordinal
                guard let countOrdinal = formatter.string(from: NSNumber(value: trophyProgress.count + 1)) else {
                    self.detailLabel.text = ""
                    return
                }
                
                var descString = String(format: "You are %i%% of the way to earning this trophy for your %@ time.", Int(trophyProgress.progress * 100), countOrdinal)
                if let lastEarnedDate = trophyProgress.lastEarned {
                    descString += String(format:" You last earned this trophy on %@.", dateFormatter.string(from: lastEarnedDate))
                }
                self.detailLabel.text = descString
            } else if trophyProgress.count == 1 {
                if let lastEarnedDate = trophyProgress.lastEarned {
                    self.detailLabel.text = String(format:"You last earned this trophy on %@.", dateFormatter.string(from: lastEarnedDate))
                } else {
                    self.detailLabel.text = "You have earned this trophy."
                }
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .spellOut
                guard let countSpelled = formatter.string(from: NSNumber(value: trophyProgress.count)) else {
                    self.detailLabel.text = ""
                    return
                }
                
                var descString = String(format: "You have earned this trophy %@ times", countSpelled)
                if let lastEarnedDate = trophyProgress.lastEarned {
                    descString += String(format:", most recently on %@.", dateFormatter.string(from: lastEarnedDate))
                } else {
                    descString += "."
                }
                self.detailLabel.text = descString
            }
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}
