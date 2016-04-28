//
//  HelpViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import ECSlidingViewController

class ConnectedAppsViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        self.slidingViewController().anchorRightRevealAmount = 276.0 // the default
        self.slidingViewController().viewDidLayoutSubviews()
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.min
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = self.tableView.dequeueReusableCellWithIdentifier("SyncWithHealthAppCell", forIndexPath: indexPath)
            guard #available(iOS 9.0, *) else {
                cell.textLabel?.textColor = ColorPallete.sharedPallete.unknownGrey
                cell.textLabel?.text = "Connect Health App"
                return cell
            }
            
            if (NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup")) {
                cell.textLabel?.text = "Disconnect Health App"
            } else {
                cell.textLabel?.text = "Connect Health App"
            }
            return cell
        } else if indexPath.row == 2 {
            return self.tableView.dequeueReusableCellWithIdentifier("ConnectAppCell", forIndexPath: indexPath)
        }
        
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier("ConnectedAppCell", forIndexPath: indexPath)
        if let label = tableCell.textLabel {
            label.text = "Love to Ride"
        }
        return tableCell
    }

    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {
            return
        }
        
        if (cell.reuseIdentifier == "SyncWithHealthAppCell") {
            guard #available(iOS 9.0, *) else {
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                return
            }
            
            let priorHealthKitState = NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup")
            
            if (priorHealthKitState) {
                // it was enabled
                // it was enabled
                let alertController = UIAlertController(title:nil, message: "Your rides will no longer automatically saved into the Health App.", preferredStyle: UIAlertControllerStyle.ActionSheet)
                alertController.addAction(UIAlertAction(title: "Disconnect", style: UIAlertActionStyle.Destructive, handler: { (_) in
                    HealthKitManager.shutdown()
                    NSUserDefaults.standardUserDefaults().setBool(false, forKey: "healthKitIsSetup")
                    NSUserDefaults.standardUserDefaults().synchronize()
                    self.tableView.reloadData()
                }))
                alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            } else {
                let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                let healthKitNavVC = storyBoard.instantiateViewControllerWithIdentifier("HealthKitSetupNavController") as! UINavigationController
                
                self.presentViewController(healthKitNavVC, animated: true, completion: nil)
            }
            
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        } else if (cell.reuseIdentifier == "ConnectAppCell") {
            let storyBoard = UIStoryboard(name: "Main", bundle: nil)
            let connectedAppNavVC = storyBoard.instantiateViewControllerWithIdentifier("ConnectedAppSetupNavController") as! UINavigationController
            
            self.presentViewController(connectedAppNavVC, animated: true, completion: nil)
        }
    }
}


