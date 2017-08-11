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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.connectingApp != nil {
            for s in self.connectingApp.scopes {
                if let scope = s as? ConnectedAppScope {
                    scope.isGranted = true
                }
            }
            
            APIClient.shared.getApplication(self.connectingApp).apiResponse {[weak self] _ in
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
        if let urlString = self.connectingApp.baseImageUrl, let url = URL(string: urlString) {
            self.connectedAppLogo.kf.setImage(with: url)
        }
        
        if let settingsText = self.connectingApp.appSettingsText {
            self.connectedAppSettingsButton.isHidden = false
            self.connectedAppSettingsButton.setTitle(settingsText, for: UIControlState())
        } else {
            self.connectedAppSettingsButton.isHidden = true
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func settings(_ sender: AnyObject) {
        if let urlString = self.connectingApp.appSettingsUrl, let url = URL(string: urlString) {
            if #available(iOS 9.0, *) {
                let sfvc = SFSafariViewController(url: url)
                self.safariViewController = sfvc
                sfvc.delegate = self
                self.navigationController?.pushViewController(sfvc, animated: true)
                if let coordinator = transitionCoordinator {
                    coordinator.animate(alongsideTransition: nil, completion: { (context) in
                        let targetSubview = sfvc.view
                        let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
                        loadingIndicator.color = ColorPallete.shared.darkGrey
                        self.safariViewControllerActivityIndicator = loadingIndicator
                        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
                        targetSubview?.addSubview(loadingIndicator)
                        NSLayoutConstraint(item: loadingIndicator, attribute: .centerY, relatedBy: NSLayoutRelation.equal, toItem: targetSubview, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
                        NSLayoutConstraint(item: loadingIndicator, attribute: .centerX, relatedBy: NSLayoutRelation.equal, toItem: targetSubview, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
                        loadingIndicator.startAnimating()
                    })
                }
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    @IBAction func disconnect(_ sender: AnyObject) {
        let alertController = UIAlertController(title: "Disconnect?", message: String(format: "Your trips data will no longer be shared with %@.", self.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.actionSheet)
        alertController.addAction(UIAlertAction(title: "Disconnect", style: UIAlertActionStyle.destructive, handler: { (_) in
            APIClient.shared.disconnectApplication(self.connectingApp).apiResponse{ [weak self] (response) in
                guard let strongSelf = self else {
                    return
                }
                
                switch response.result {
                case .success(_):
                    strongSelf.dismiss(animated: true, completion: nil)
                case .failure(_):
                    let alertController = UIAlertController(title:nil, message: String(format: "Your Ride Report account could not be disconnected from %@. Please try again later.", strongSelf.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.actionSheet)
                    alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.destructive, handler: { (_) in
                        strongSelf.dismiss(animated: true, completion: nil)
                    }))
                    strongSelf.present(alertController, animated: true, completion: nil)
                }
            }
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc private func showPageLoadError() {
        let alertController = UIAlertController(title:nil, message: String(format: "Ride Report cannot connect to %@. Please try again later.", self.connectingApp?.name ?? "App"), preferredStyle: UIAlertControllerStyle.actionSheet)
        alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.destructive, handler: { (_) in
            _ = self.navigationController?.popViewController(animated: true)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @available(iOS 9.0, *)
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if let loadingIndicator = self.safariViewControllerActivityIndicator {
            loadingIndicator.removeFromSuperview()
            self.safariViewControllerActivityIndicator = nil
        }
        
        if !didLoadSuccessfully {
            self.perform(#selector(ConnectedAppSettingsViewController.showPageLoadError), with: nil, afterDelay: 1.0)
        }
    }
}
