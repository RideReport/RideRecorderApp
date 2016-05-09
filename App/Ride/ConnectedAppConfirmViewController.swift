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
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var connectionActivityIndicatorView: UIActivityIndicatorView!
    
    private var hasCanceled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.connectionActivityIndicatorView.hidden = true
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
        self.connectButton.hidden = true
        self.connectionActivityIndicatorView.hidden = false
        
        self.postConnectApplication()
    }
    
    func postConnectApplication() {
        guard !self.hasCanceled else {
            return
        }
        
        APIClient.sharedClient.connectApplication(self.connectingApp).apiResponse {[weak self] (response) in
            guard let strongSelf = self else {
                return
            }
            
            switch response.result {
            case .Success(_):
                if let httpsResponse = response.response where httpsResponse.statusCode == 200 {
                    strongSelf.dismissViewControllerAnimated(true, completion: nil)
                } else {
                    // otherwise, keep polling
                    strongSelf.performSelector(#selector(ConnectedAppConfirmViewController.postConnectApplication), withObject: nil, afterDelay: 2.0)
                }
            case .Failure(_):
                let alertController = UIAlertController(title:nil, message: String(format: "Your Ride Report account could not be connected to %@. Please Try Again Later.", strongSelf.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.ActionSheet)
                alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.Destructive, handler: { (_) in
                    strongSelf.dismissViewControllerAnimated(true, completion: nil)
                }))
                strongSelf.presentViewController(alertController, animated: true, completion: nil)
                
                strongSelf.connectionActivityIndicatorView.hidden = true
            }
        }
    }
    
    @IBAction func cancel(sender: AnyObject) {
        self.hasCanceled = true
        APIClient.sharedClient.disconnectApplication(self.connectingApp)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return connectingApp.scopes.count ?? 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let tableCell = self.tableView.dequeueReusableCellWithIdentifier("AppConfirmPermisionTableCell", forIndexPath: indexPath)
        if let permissionText = tableCell.viewWithTag(1) as? UILabel, permissionSwitch = tableCell.viewWithTag(2) as? UISwitch {
            // For now we assume that all scopes are of type Bool
            if  indexPath.row < connectingApp.scopes.count {
                let scope = connectingApp.scopes[indexPath.row]
                permissionText.text = scope.descriptionText
                permissionSwitch.enabled = !scope.required
                permissionSwitch.on = scope.granted
            }
        }
        
        tableCell.selectionStyle = .None
        return tableCell
    }
}