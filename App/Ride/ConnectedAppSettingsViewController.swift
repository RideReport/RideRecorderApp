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
    @IBOutlet weak var disconnectedAppButton: UIButton!
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
            
            RideReportAPIClient.shared.getApplication(self.connectingApp).apiResponse {[weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.refreshUI()
            }
            
            self.refreshUI()
        }
    }
    
    private func refreshUI() {
        self.title = self.connectingApp.name ?? "App"
        
        if let title = self.connectingApp.disconnectButtonTitleText {
            self.disconnectedAppButton.setTitle(title, for: UIControlState())
        }
        
        self.connectedAppDetailText.text = self.connectingApp.descriptionText
        
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
        var confirmationText = String(format: "Your Ride Report account will no longer be connected with %@.", self.connectingApp.name ?? "App")
        if let text = self.connectingApp.disconnectConfirmationText {
            confirmationText = text
        }
        
        var disconnectTitle = "Disconnect"
        if let title = self.connectingApp.disconnectButtonTitleText {
            disconnectTitle = title
        }
        
        let alertController = UIAlertController(title: nil, message: confirmationText, preferredStyle: UIAlertControllerStyle.actionSheet)
        alertController.addAction(UIAlertAction(title: disconnectTitle, style: UIAlertActionStyle.destructive, handler: { (_) in
            RideReportAPIClient.shared.disconnectApplication(self.connectingApp).apiResponse{ [weak self] (response) in
                guard let strongSelf = self else {
                    return
                }
                
                switch response.result {
                case .success(_):
                    strongSelf.navigationController?.popViewController(animated: true)
                case .failure(_):
                    var disconnectTitle = "disconnect"
                    if let title = strongSelf.connectingApp.disconnectButtonTitleText {
                        disconnectTitle = title.lowercased()
                    }
                    
                    let alertController = UIAlertController(title:nil, message: String(format: "Ride Report cannot %@. Please try again later.", disconnectTitle), preferredStyle: UIAlertControllerStyle.actionSheet)
                    alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.destructive, handler: { (_) in
                        strongSelf.navigationController?.popViewController(animated: true)
                    }))
                    strongSelf.present(alertController, animated: true, completion: nil)
                }
            }
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc private func showPageLoadError() {
        var disconnectTitle = "disconnect"
        if let title = self.connectingApp.disconnectButtonTitleText {
            disconnectTitle = title.lowercased()
        }
        
        let alertController = UIAlertController(title:nil, message: String(format: "Ride Report cannot %@. Please try again later.", disconnectTitle), preferredStyle: UIAlertControllerStyle.actionSheet)
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
