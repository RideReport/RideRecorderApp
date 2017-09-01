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
    
    func nextPermission() {
        if self.currentPermissionsAsk == .askForNotifications {
            self.batteryLifeLabel.fadeOut()
            self.helperTextLabel.fadeOut()
            self.nextButton.fadeOut()
            self.notificationDetailsLabel.popIn()
            
            if (AppDelegate.appDelegate().notificationRegistrationStatus == .unregistered) {
                self.currentPermissionsAsk = .askedForNotifications
                self.notificationDetailsLabel.text = "1️⃣ Send notifications after your ride"

                var didShowShowPermissionDialog = false
                NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil) {[weak self] (_) -> Void in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    // this is the only way to know whether or not they've been asked for permission or not – wait for the dialog to make our app resign active =/
                    didShowShowPermissionDialog = true
                    NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) { (_) -> Void in
                        // they tapped a button and we are active again. advance!
                        NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
                        strongSelf.currentPermissionsAsk = .askForLocations
                        DispatchQueue.main.async {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            // make sure its on the main thread
                            strongSelf.nextPermission()
                        }
                    }
                }
                
                let delay: TimeInterval = 1
                self.notificationDetailsLabel.delay(delay + 0.3, completionHandler: { () -> Void in
                    // timeout. this is for the case where they've already denied notification status.
                    if !didShowShowPermissionDialog {
                        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
                        self.currentPermissionsAsk = .askForLocations
                        self.nextPermission()
                    }
                })
                
                self.helperTextLabel.delay(delay) {
                    NotificationManager.startup()
                }
            } else {
                // they've already granted it
                self.currentPermissionsAsk = .askForLocations
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .askForLocations {
            if (RouteManager.authorizationStatus == .notDetermined) {
                self.currentPermissionsAsk = .askedForLocations
                self.notificationDetailsLabel.text = "✅ Send notifications after your ride"
                self.notificationDetailsLabel.delay(0.5) {
                    self.notificationDetailsLabel.text = "2️⃣ Use your location during your ride"
                    self.notificationDetailsLabel.popIn()
                }
                
                self.helperTextLabel.delay(1.5) {
                    NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: nil, queue: nil) {[weak self] (_) -> Void in
                        guard let strongSelf = self else {
                            return
                        }
                        NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: nil)
                        if RouteManager.authorizationStatus != .notDetermined {
                            strongSelf.currentPermissionsAsk = .askForMotion
                            DispatchQueue.main.async {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                // make sure its on the main thread
                                strongSelf.nextPermission()
                            }
                        }
                    }
                    RouteRecorder.shared.routeManager.startup(false)
                }
            } else {
                // they've already granted or denied it                
                self.currentPermissionsAsk = .askForMotion
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .askForMotion {
            if (RouteRecorder.shared.classificationManager.authorizationStatus == .notDetermined) {
                self.currentPermissionsAsk = .askedForMotion
                self.notificationDetailsLabel.text = "✅ Use your location during your ride"
                self.notificationDetailsLabel.delay(0.5) {
                    self.notificationDetailsLabel.text = "3️⃣ Use your motion activity during your ride"
                    self.notificationDetailsLabel.popIn()
                }
                
                self.helperTextLabel.delay(1.5) {
                    RouteRecorder.shared.randomForestManager.startup()
                    RouteRecorder.shared.classificationManager.startup()
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: nil, queue: nil) {[weak self] (_) -> Void in
                        guard let strongSelf = self else {
                            return
                        }
                        NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: nil)
                        if RouteRecorder.shared.classificationManager.authorizationStatus != .notDetermined {
                            strongSelf.currentPermissionsAsk = .sayFinished
                            DispatchQueue.main.async {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                // make sure its on the main thread
                                strongSelf.nextPermission()
                            }
                        }
                    }
                }
            } else {
                // they've already granted or denied it
                self.currentPermissionsAsk = .sayFinished
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .sayFinished {
            self.currentPermissionsAsk = .finished
            self.notificationDetailsLabel.text = "✅ Use your motion activity during your ride"
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
        self.next(self)
    }
    
    @IBAction func tappedDoItButton(_ sender: AnyObject) {
        self.nextPermission()
    }
}
