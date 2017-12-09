//
//  SetupPermissionsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder

enum CurrentPermissionAsk {
    case askForNotifications
    case askedForNotifications
    case askForLocations
    case askedForLocations
    case askForMotion
    case askedForMotion
    case sayFinished
    case finished
}

class SetupPermissionsViewController: SetupChildViewController {
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    @IBOutlet weak var notificationDetailsLabel: UILabel!
    @IBOutlet weak var batteryLifeLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    
    private var currentPermissionsAsk: CurrentPermissionAsk = .askForNotifications
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    private func requestNotificationsPermission() {
        self.helperTextLabel.delay(1.0) {
            NotificationManager.startup() { (status) in
                DispatchQueue.main.async {
                    let completionBlock = { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.currentPermissionsAsk = .askForLocations
                        strongSelf.nextPermission()
                    }
                    
                    if (status == .denied) {
                        let alertController = UIAlertController(title: "Notifications are disabled", message: "Ride Report needs permission to send notifications to deliver Ride reports to your lock screen.", preferredStyle: UIAlertControllerStyle.alert)
                        alertController.addAction(UIAlertAction(title: "Go to Notification Settings", style: UIAlertActionStyle.default) { (_) in
                            let url = URL(string: UIApplicationOpenSettingsURLString)
                            if url != nil && UIApplication.shared.canOpenURL(url!) {
                                UIApplication.shared.openURL(url!)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                completionBlock()
                            }
                        })
                        alertController.addAction(UIAlertAction(title: "Disable Lock Screen Reports", style: UIAlertActionStyle.destructive) { (_) in
                            completionBlock()
                        })
                        self.present(alertController, animated: true, completion: nil)
                    } else {
                        completionBlock()
                    }
                }
            }
        }
    }
    
    private func requestLocationsPermission() {
        self.currentPermissionsAsk = .askedForLocations
        
        self.helperTextLabel.delay(1.5) {
            RouteRecorder.shared.routeManager.startup(false) {
                let completionBlock = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.currentPermissionsAsk = .sayFinished // motion permission is not needed, for now
                    strongSelf.nextPermission()
                }
                
                if (RouteManager.authorizationStatus() == .denied || RouteManager.authorizationStatus() == .restricted) {
                    let alertController = UIAlertController(title: "Location Services are disabled", message: "In order to log your bike trips automatically, Ride Report needs permission to use your locations. We promise not to drain your battery!", preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "Go to Location Settings", style: UIAlertActionStyle.default) { (_) in
                        let url = URL(string: UIApplicationOpenSettingsURLString)
                        if url != nil && UIApplication.shared.canOpenURL(url!) {
                            UIApplication.shared.openURL(url!)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            completionBlock()
                        }
                    })
                    alertController.addAction(UIAlertAction(title: "Enable Ride Report Later", style: UIAlertActionStyle.destructive) { (_) in
                        completionBlock()
                    })
                    self.present(alertController, animated: true, completion: nil)
                } else if (RouteManager.authorizationStatus() == .authorizedWhenInUse ){
                    let alertController = UIAlertController(title: "Background Location Services are disabled", message: "In order to log your bike trips automatically, Ride Report needs permission to use your locations always. We promise not to drain your battery!", preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "Go to Location Settings", style: UIAlertActionStyle.default) { (_) in
                        let url = URL(string: UIApplicationOpenSettingsURLString)
                        if url != nil && UIApplication.shared.canOpenURL(url!) {
                            UIApplication.shared.openURL(url!)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            completionBlock()
                        }
                    })
                    alertController.addAction(UIAlertAction(title: "Enable Ride Report Later", style: UIAlertActionStyle.destructive) { (_) in
                        completionBlock()
                    })
                    self.present(alertController, animated: true, completion: nil)
                } else {
                    completionBlock()
                }
            }
        }
    }
    
    func requestMotionPermission() {
        self.currentPermissionsAsk = .askedForMotion
        
        self.helperTextLabel.delay(1.5) {
            RouteRecorder.shared.randomForestManager.startup()
            RouteRecorder.shared.classificationManager.startup() {
                let completionBlock = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.currentPermissionsAsk = .sayFinished
                    strongSelf.nextPermission()
                }
                
                if (SensorClassificationManager.authorizationStatus == .denied) {
                    let alertController = UIAlertController(title: "Motion & Fitness is disabled", message: "Ride Report needs permission to use your motion activity in order to log your bike trips automatically. We promise not to drain your battery!", preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "Go to Motion & Fitness Settings", style: UIAlertActionStyle.default) { (_) in
                        let url = URL(string: UIApplicationOpenSettingsURLString)
                        if url != nil && UIApplication.shared.canOpenURL(url!) {
                            UIApplication.shared.openURL(url!)
                        }
                        completionBlock()
                    })
                    alertController.addAction(UIAlertAction(title: "Enable Ride Report Later", style: UIAlertActionStyle.destructive) { (_) in
                        completionBlock()
                    })
                    self.present(alertController, animated: true, completion: nil)
                } else {
                    completionBlock()
                }
            }
        }
    }
    
    func nextPermission() {
        if self.currentPermissionsAsk == .askForNotifications {
            self.batteryLifeLabel.fadeOut()
            self.helperTextLabel.fadeOut()
            self.nextButton.fadeOut()
            self.notificationDetailsLabel.popIn()
            
            NotificationManager.checkAuthorized(handler: { (status) in
                DispatchQueue.main.async {
                    if status != .authorized {
                        self.notificationDetailsLabel.text = "1️⃣ Send notifications after your ride"
                        self.requestNotificationsPermission()
                    } else {
                        self.currentPermissionsAsk = .askForLocations
                        self.nextPermission()
                    }
                }
            })
        } else if self.currentPermissionsAsk == .askForLocations {
            self.notificationDetailsLabel.text = "✅ Send notifications after your ride"

            if RouteManager.authorizationStatus() != .authorizedAlways {
                self.notificationDetailsLabel.delay(0.5) {
                    self.notificationDetailsLabel.text = "2️⃣ Use your location when Ride Report is in the background"
                    self.notificationDetailsLabel.popIn()
                }
                
                self.requestLocationsPermission()
            } else {
                self.currentPermissionsAsk = .sayFinished // motion permission is not needed, for now
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .askForMotion { // currently gets skipped
            self.notificationDetailsLabel.text = "✅ Use your location when Ride Report is in the background"
 
            if (SensorClassificationManager.authorizationStatus != .authorized) {
                self.notificationDetailsLabel.delay(0.5) {
                    self.notificationDetailsLabel.text = "3️⃣ Use your motion activity during your ride"
                    self.notificationDetailsLabel.popIn()
                }
                
                self.requestMotionPermission()
            } else {
                // they've already granted or denied it
                self.currentPermissionsAsk = .sayFinished
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .sayFinished {
            self.currentPermissionsAsk = .finished
            
            self.notificationDetailsLabel.text = "✅ Use your location during your ride"
            //self.notificationDetailsLabel.text = "✅ Use your motion activity during your ride" <--- motion currently is skipped
            
            self.notificationDetailsLabel.delay(0.5) {
                self.notificationDetailsLabel.fadeOut()
            }
            self.notificationDetailsLabel.delay(0.75) {
                self.helperTextLabel.text = "Nice! You're a natural."
                self.helperTextLabel.popIn()
            }
            self.doneButton.delay(1) {
                self.doneButton.fadeIn()
            }
        }
    }
    
    @IBAction func tappedDoneButton(_ sender: AnyObject) {
        var skipInterval = 0
        if (RideReportAPIClient.shared.accountVerificationStatus == .verified) {
            skipInterval = 2 // skip setup profile and confirm
        }
        self.parentSetupViewController?.nextPage(sender: self, userInfo: nil, skipInterval: skipInterval)
    }
    
    @IBAction func tappedDoItButton(_ sender: AnyObject) {
        self.nextPermission()
    }
}
