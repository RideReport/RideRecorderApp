//
//  ConnectedAppConfirmViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SafariServices

class ConnectedAppSettingsViewController : UIViewController, SFSafariViewControllerDelegate{
    var connectingApp: ConnectedApp!

    @IBOutlet weak var connectedAppSettingsButton: UIButton!
    @IBOutlet weak var connectedAppLogo: UIImageView!
    @IBOutlet weak var connectedAppDetailText: UILabel!
    
    private var safariViewController: UIViewController? = nil
    private var safariViewControllerActivityIndicator: UIActivityIndicatorView? = nil
    
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
            
            APIClient.sharedClient.getApplication(self.connectingApp).apiResponse {[weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.refreshUI()
            }
            
            self.refreshUI()
        }
    }
    
    private func refreshUI() {
        self.connectedAppDetailText.text = String(format: "%@ accesses data from your trips in Ride Report.", self.connectingApp.name ?? "App")
        if let urlString = self.connectingApp.baseImageUrl, url = NSURL(string: urlString) {
            self.connectedAppLogo.kf_setImageWithURL(url)
        }
        
        if let settingsText = self.connectingApp.appSettingsText {
            self.connectedAppSettingsButton.hidden = false
            self.connectedAppSettingsButton.setTitle(settingsText, forState: UIControlState.Normal)
        } else {
            self.connectedAppSettingsButton.hidden = true
        }
    }
    
    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func settings(sender: AnyObject) {
        if let urlString = self.connectingApp.appSettingsUrl, url = NSURL(string: urlString) {
            if #available(iOS 9.0, *) {
                let sfvc = SFSafariViewController(URL: url)
                self.safariViewController = sfvc
                sfvc.delegate = self
                self.navigationController?.pushViewController(sfvc, animated: true)
                if let coordinator = transitionCoordinator() {
                    coordinator.animateAlongsideTransition(nil, completion: { (context) in
                        let targetSubview = sfvc.view
                        let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
                        loadingIndicator.color = ColorPallete.sharedPallete.darkGrey
                        self.safariViewControllerActivityIndicator = loadingIndicator
                        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
                        targetSubview.addSubview(loadingIndicator)
                        NSLayoutConstraint(item: loadingIndicator, attribute: .CenterY, relatedBy: NSLayoutRelation.Equal, toItem: targetSubview, attribute: .CenterY, multiplier: 1, constant: 0).active = true
                        NSLayoutConstraint(item: loadingIndicator, attribute: .CenterX, relatedBy: NSLayoutRelation.Equal, toItem: targetSubview, attribute: .CenterX, multiplier: 1, constant: 0).active = true
                        loadingIndicator.startAnimating()
                    })
                }
            } else {
                UIApplication.sharedApplication().openURL(url)
            }
        }
    }
    
    @IBAction func disconnect(sender: AnyObject) {
        let alertController = UIAlertController(title: "Disconnect?", message: String(format: "Your trips data will no longer be shared with %@.", self.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Disconnect", style: UIAlertActionStyle.Destructive, handler: { (_) in
            APIClient.sharedClient.disconnectApplication(self.connectingApp).apiResponse{ [weak self] (response) in
                guard let strongSelf = self else {
                    return
                }
                
                switch response.result {
                case .Success(_):
                    strongSelf.dismissViewControllerAnimated(true, completion: nil)
                case .Failure(_):
                    let alertController = UIAlertController(title:nil, message: String(format: "Your Ride Report account could not be disconnected from %@. Please try again later.", strongSelf.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.ActionSheet)
                    alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.Destructive, handler: { (_) in
                        strongSelf.dismissViewControllerAnimated(true, completion: nil)
                    }))
                    strongSelf.presentViewController(alertController, animated: true, completion: nil)
                }
            }
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    @objc private func showPageLoadError() {
        let alertController = UIAlertController(title:nil, message: String(format: "Ride Report cannot connect to %@. Please try again later.", self.connectingApp?.name ?? "App"), preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.Destructive, handler: { (_) in
            self.navigationController?.popViewControllerAnimated(true)
        }))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    @available(iOS 9.0, *)
    func safariViewController(controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if let loadingIndicator = self.safariViewControllerActivityIndicator {
            loadingIndicator.removeFromSuperview()
            self.safariViewControllerActivityIndicator = nil
        }
        
        if !didLoadSuccessfully {
            self.performSelector(#selector(ConnectedAppSettingsViewController.showPageLoadError), withObject: nil, afterDelay: 1.0)
        }
    }
}