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
    var emoji: String = ""
    var body: String = ""
    var count: Int = 0
    var progress: Double = 1
    
    private static let viewSizePercentageWidth: CGFloat = 0.8
    private static let viewSizePercentageHeight: CGFloat = 0.2
    
    @IBOutlet weak var trophyProgress: TrophyProgressButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    
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
        
        refreshUI()
        
        if count >= 1 {
            self.trophyProgress.isHidden = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if count >= 1 {
            self.view.sparkle(ColorPallete.shared.brightBlue, inRect: self.trophyProgress.frame.insetBy(dx: -30, dy: -30))
            self.trophyProgress.fadeIn()
        } else {
            self.trophyProgress.isHidden = false
        }
    }
    
    private func refreshUI() {
        self.trophyProgress.emoji = emoji
        self.trophyProgress.count = 1 // don't show count
        self.trophyProgress.progress = progress
        
        self.descriptionLabel.text = body
        
        if count < 1 {
            if progress > 0 {
                self.detailLabel.text = String(format: "You are %i%% of the way to earning this trophy.", Int(progress * 100))
            } else {
                self.detailLabel.text = "You have never earned this trophy."
            }
        } else {
            if progress > 0 && progress < 1 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .ordinal
                guard let countOrdinal = formatter.string(from: NSNumber(value: count + 1)) else {
                    self.detailLabel.text = ""
                    return
                }
                
                self.detailLabel.text = String(format: "You are %i%% of the way to earning this trophy for your %@ time.", Int(progress * 100), countOrdinal)
            } else if count == 1 {
                self.detailLabel.text = "You have earned this trophy."
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .spellOut
                guard let countSpelled = formatter.string(from: NSNumber(value: count)) else {
                    self.detailLabel.text = ""
                    return
                }
                
                self.detailLabel.text = String(format: "You have earned this trophy %@ times.", countSpelled)
            }
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}
