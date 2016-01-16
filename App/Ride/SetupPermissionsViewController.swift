//
//  SetupPermissionsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

enum CurrentPermissionAsk {
    case AskForNotifications
    case AskedForNotifications
    case AskForLocations
    case AskedForLocations
    case AskForMotion
    case AskedForMotion
    case SayFinished
    case Finished
}

class SetupPermissionsViewController: SetupChildViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    @IBOutlet weak var notificationDetailsLabel: UILabel!
    @IBOutlet weak var batteryLifeLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    
    private var currentPermissionsAsk: CurrentPermissionAsk = .AskForNotifications
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func nextPermission() {
        if self.currentPermissionsAsk == .AskForNotifications {
            self.batteryLifeLabel.fadeOut()
            self.helperTextLabel.fadeOut()
            self.nextButton.fadeOut()
            self.notificationDetailsLabel.popIn()
            
            if (AppDelegate.appDelegate().notificationRegistrationStatus == .Unregistered) {
                self.currentPermissionsAsk = .AskedForNotifications
                self.notificationDetailsLabel.text = "1️⃣ Send notifications after your ride"

                var didShowShowPermissionDialog = false
                NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) { (_) -> Void in
                    // this is the only way to know whether or not they've been asked for permission or not – wait for the dialog to make our app resign active =/
                    didShowShowPermissionDialog = true
                    NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillResignActiveNotification, object: nil)
                    
                    NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) { (_) -> Void in
                        // they tapped a button and we are active again. advance!
                        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object: nil)
                        self.currentPermissionsAsk = .AskForLocations
                        dispatch_async(dispatch_get_main_queue()) {
                            // make sure its on the main thread
                            self.nextPermission()
                        }
                    }
                }
                
                let delay: NSTimeInterval = 1
                self.notificationDetailsLabel.delay(delay + 0.3, completionHandler: { () -> Void in
                    // timeout. this is for the case where they've already denied notification status.
                    if !didShowShowPermissionDialog {
                        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationWillResignActiveNotification, object: nil)
                        self.currentPermissionsAsk = .AskForLocations
                        self.nextPermission()
                    }
                })
                
                self.helperTextLabel.delay(delay) {
                    AppDelegate.appDelegate().startupNotifications()
                }
            } else {
                // they've already granted it
                self.currentPermissionsAsk = .AskForLocations
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .AskForLocations {
            if (RouteManager.authorizationStatus == .NotDetermined) {
                self.currentPermissionsAsk = .AskedForLocations
                self.notificationDetailsLabel.text = "✅ Send notifications after your ride"
                self.notificationDetailsLabel.delay(0.5) {
                    self.notificationDetailsLabel.text = "2️⃣ Use your location during your ride"
                    self.notificationDetailsLabel.popIn()
                }
                
                self.helperTextLabel.delay(1.5) {
                    NSNotificationCenter.defaultCenter().addObserverForName("appDidChangeManagerAuthorizationStatus", object: nil, queue: nil) { (_) -> Void in
                        NSNotificationCenter.defaultCenter().removeObserver(self, name: "appDidChangeManagerAuthorizationStatus", object: nil)
                        if RouteManager.authorizationStatus != .NotDetermined {
                            self.currentPermissionsAsk = .AskForMotion
                            dispatch_async(dispatch_get_main_queue()) {
                                // make sure its on the main thread
                                self.nextPermission()
                            }
                        }
                    }
                    AppDelegate.appDelegate().startupRouteManager(false)
                }
            } else {
                // they've already granted or denied it                
                self.currentPermissionsAsk = .AskForMotion
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .AskForMotion {
            if (MotionManager.authorizationStatus == .NotDetermined) {
                self.currentPermissionsAsk = .AskedForMotion
                self.notificationDetailsLabel.text = "✅ Use your location during your ride"
                self.notificationDetailsLabel.delay(0.5) {
                    self.notificationDetailsLabel.text = "3️⃣ Use your motion acitivity during your ride"
                    self.notificationDetailsLabel.popIn()
                }
                
                self.helperTextLabel.delay(1.5) {
                    AppDelegate.appDelegate().startupMotionManager()
                    NSNotificationCenter.defaultCenter().addObserverForName("appDidChangeManagerAuthorizationStatus", object: nil, queue: nil) { (_) -> Void in
                        NSNotificationCenter.defaultCenter().removeObserver(self, name: "appDidChangeManagerAuthorizationStatus", object: nil)
                        if MotionManager.authorizationStatus != .NotDetermined {
                            self.currentPermissionsAsk = .SayFinished
                            dispatch_async(dispatch_get_main_queue()) {
                                // make sure its on the main thread
                                self.nextPermission()
                            }
                        }
                    }
                }
            } else {
                // they've already granted or denied it
                self.currentPermissionsAsk = .SayFinished
                self.nextPermission()
            }
        } else if self.currentPermissionsAsk == .SayFinished {
            self.currentPermissionsAsk = .Finished
            self.notificationDetailsLabel.text = "✅ Use your motion acitivity during your ride"
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
    
    @IBAction func tappedDoneButton(sender: AnyObject) {
        self.next(self)
    }
    
    @IBAction func tappedDoItButton(sender: AnyObject) {
        self.nextPermission()
    }
}