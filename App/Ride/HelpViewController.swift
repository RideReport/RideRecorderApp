//
//  HelpViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import ECSlidingViewController

class HelpViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.backgroundColor = ColorPallete.shared.primary
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.slidingViewController().anchorRightRevealAmount = 276.0 // the default
        self.slidingViewController().viewDidLayoutSubviews()
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        for case let button as UIButton in cell.subviews {
            let image = button.backgroundImage(for: .normal)?.withRenderingMode(.alwaysTemplate)
            button.tintColor = ColorPallete.shared.almostWhite
            button.setBackgroundImage(image, for: .normal)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if (indexPath.row == 0) {
            self.slidingViewController().anchorRightPeekAmount = 0.0
            self.slidingViewController().viewDidLayoutSubviews()
            self.slidingViewController().topViewAnchoredGesture = [ECSlidingViewControllerAnchoredGesture.tapping, ECSlidingViewControllerAnchoredGesture.panning]
        } else if (indexPath.row == 1) {
            AppDelegate.appDelegate().transitionToSetup()
        } else if (indexPath.row == 2) {
            AppDelegate.appDelegate().showMapAttribution()
        }
    }
}


