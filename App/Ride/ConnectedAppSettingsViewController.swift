//
//  ConnectedAppConfirmViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class ConnectedAppSettingsViewController : UIViewController{
    var connectingApp: ConnectedApp!

    @IBOutlet weak var connectedAppLogo: UIImageView!
    @IBOutlet weak var connectedAppDetailText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
            
            
            self.connectedAppDetailText.text = String(format: "%@ accesses data from your trips in Ride Report.", self.connectingApp.name ?? "App")
            if let urlString = self.connectingApp.baseImageUrl, url = NSURL(string: urlString) {
                self.connectedAppLogo.kf_setImageWithURL(url, placeholderImage: UIImage(named: "placeholder"))
            }
        }
    }
    
    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func disconnect(sender: AnyObject) {
        let alertController = UIAlertController(title: "Disconnect?", message: String(format: "Your trips data will no longer be shared with %@.", self.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Disconnect", style: UIAlertActionStyle.Destructive, handler: { (_) in
            self.connectingApp.profile = nil
            CoreDataManager.sharedManager.saveContext()
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
}