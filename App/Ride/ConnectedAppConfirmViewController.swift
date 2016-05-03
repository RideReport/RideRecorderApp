//
//  ConnectedAppConfirmViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class ConnectedAppConfirmViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    var connectingApp: ConnectedApp!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var connectingAppLogo: UIImageView!
    @IBOutlet weak var connectingAppDetailText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.connectingApp != nil {
            for scope in self.connectingApp.scopes {
                scope.granted = true
            }

            
            self.connectingAppDetailText.text = String(format: "%@ would access your data from your trips in Ride Report.", self.connectingApp.name ?? "App")
            if let urlString = self.connectingApp.baseImageUrl, url = NSURL(string: urlString) {
                self.connectingAppLogo.kf_setImageWithURL(url, placeholderImage: UIImage(named: "placeholder"))
            }
            self.tableView.reloadData()
        }
    }
    
    @IBAction func didFlipSwitch(sender: AnyObject) {
        if let view = sender as? UIView,
            cellContent = view.superview,
            cell = cellContent.superview as? UITableViewCell,
            let indexPath = self.tableView.indexPathForCell(cell)
            where indexPath.row < self.connectingApp.scopes.count {
                let app = self.connectingApp.scopes[indexPath.row]
                app.granted = sender.on
        }
    }
    
    @IBAction func connect(sender: AnyObject) {
        self.connectingApp.profile = Profile.profile()
        CoreDataManager.sharedManager.saveContext()
        self.performSegueWithIdentifier("showConnectedAppFinished", sender: self)
    }
    
    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return connectingApp.scopes.count ?? 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier("AppConfirmPermisionTableCell", forIndexPath: indexPath)
        if let permissionText = tableCell.viewWithTag(1) as? UILabel, permissionSwitch = tableCell.viewWithTag(2) as? UISwitch {
            if  indexPath.row < connectingApp.scopes.count {
                let scope = connectingApp.scopes[indexPath.row]
                permissionText.text = scope.descriptionText
                permissionSwitch.enabled = scope.optional
                permissionSwitch.on = scope.granted
            }
        }
        
        tableCell.selectionStyle = .None
        return tableCell
    }
}