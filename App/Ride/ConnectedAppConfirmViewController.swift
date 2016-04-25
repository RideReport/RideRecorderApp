//
//  ConnectedAppConfirmViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class ConnectedAppConfirmViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var connectingAppLogo: UIImageView!
    @IBOutlet weak var connectingAppDetailText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.connectingAppDetailText.text = String(format: "%@ would access your data from your trips in Ride Report.", "Love to Ride")
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func connect(sender: AnyObject) {
        self.performSegueWithIdentifier("showConnectedAppFinished", sender: self)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier("AppConfirmPermisionTableCell", forIndexPath: indexPath)
        if let permissionText = tableCell.viewWithTag(1) as? UILabel, permissionSwitch = tableCell.viewWithTag(2) as? UISwitch {
            if indexPath.row == 0 {
                permissionText.text = "Share my trip times and lengths"
            } else {
                permissionText.text = "Share my trip routes"
            }
            permissionSwitch.enabled = true
        }
        return tableCell
    }
}