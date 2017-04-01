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
    @IBOutlet weak var connectingAppScopesText: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var connectionActivityIndicatorView: UIView!
    @IBOutlet weak var connectionActivityIndicatorViewText: UILabel!
    
    private var hasCanceled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.connectionActivityIndicatorView.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.connectingApp != nil {
            for scope in self.connectingApp.scopes {
                scope.granted = true
            }
            
            self.connectingAppDetailText.text = self.connectingApp.descriptionText
            self.connectingAppScopesText.text = String(format: "%@ would like the following data about your rides:", self.connectingApp.name ?? "App")
            self.connectionActivityIndicatorViewText.text = String(format: "Connecting to %@…", self.connectingApp.name ?? "App")
            if let urlString = self.connectingApp.baseImageUrl, let url = URL(string: urlString) {
                self.connectingAppLogo.kf.setImage(with: url)
            }
            self.tableView.reloadData()
        }
    }
    
    @IBAction func didFlipSwitch(_ sender: AnyObject) {
        if let view = sender as? UIView,
            let cellContent = view.superview,
            let cell = cellContent.superview as? UITableViewCell,
            let indexPath = self.tableView.indexPath(for: cell), indexPath.row < self.connectingApp.scopes.count {
                let app = self.connectingApp.scopes[indexPath.row]
                app.granted = sender.isOn
        }
    }
    
    @IBAction func connect(_ sender: AnyObject) {
        if let superview = self.connectionActivityIndicatorView.superview {
            superview.bringSubview(toFront: self.connectionActivityIndicatorView)
        }
        self.connectionActivityIndicatorView.isHidden = false
        
        self.postConnectApplication()
    }
    
    func postConnectApplication() {
        guard !self.hasCanceled else {
            return
        }
        
        APIClient.shared.connectApplication(self.connectingApp).apiResponse {[weak self] (response) in
            guard let strongSelf = self else {
                return
            }
            
            switch response.result {
            case .success(_):
                if let httpsResponse = response.response, httpsResponse.statusCode == 200 {
                    strongSelf.dismiss(animated: true, completion: nil)
                } else {
                    // otherwise, keep polling
                    strongSelf.perform(#selector(ConnectedAppConfirmViewController.postConnectApplication), with: nil, afterDelay: 2.0)
                }
            case .failure(_):
                let alertController = UIAlertController(title:nil, message: String(format: "Your Ride Report account could not be connected to %@. Please try again later.", strongSelf.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.actionSheet)
                alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.destructive, handler: { (_) in
                    strongSelf.dismiss(animated: true, completion: nil)
                }))
                strongSelf.present(alertController, animated: true, completion: nil)
                
                strongSelf.connectionActivityIndicatorView.isHidden = true
            }
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.hasCanceled = true
        APIClient.shared.disconnectApplication(self.connectingApp)
        self.dismiss(animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return connectingApp.scopes.count 
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "AppConfirmPermisionTableCell", for: indexPath)
        if let permissionText = tableCell.viewWithTag(1) as? UILabel, let permissionSwitch = tableCell.viewWithTag(2) as? UISwitch {
            // For now we assume that all scopes are of type Bool
            if  indexPath.row < connectingApp.scopes.count {
                let scope = connectingApp.scopes[indexPath.row]
                permissionText.text = scope.descriptionText ?? ""
                permissionSwitch.isEnabled = !scope.required
                permissionSwitch.isOn = scope.granted
            }
        }
        
        tableCell.selectionStyle = .none
        return tableCell
    }
}
