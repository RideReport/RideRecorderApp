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
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        if (indexPath.row == 0) {
            UIApplication.sharedApplication().openURL(NSURL(string: "http://help.ride.report")!)
        } else if (indexPath.row == 1) {
            AppDelegate.appDelegate().transitionToSetup()
        } else if (indexPath.row == 2) {
            AppDelegate.appDelegate().showMapAttribution()
        }
    }
    
}


