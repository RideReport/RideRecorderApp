//
//  RideReportTabBarController.swift
//  Ride Report
//
//  Created by William Henderson on 11/30/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder

class RideReportTabBarController : UITabBarController {
    var popupView: PopupView!
    var xPositionConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.popupView = PopupView(frame: CGRect.zero)
        self.popupView.strokeColor = ColorPallete.shared.primaryDark
        self.popupView.fillColor = ColorPallete.shared.almostWhite
        self.popupView.translatesAutoresizingMaskIntoConstraints = false
        self.popupView.isHidden = true
        self.view.addSubview(self.popupView)

        self.popupView.addConstraint(NSLayoutConstraint(item: self.popupView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.greaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 45.0))
        self.view.addConstraint(NSLayoutConstraint(item: self.view, attribute: NSLayoutAttribute.bottomMargin, relatedBy: NSLayoutRelation.equal, toItem: self.popupView, attribute: NSLayoutAttribute.bottom, multiplier: 1.0, constant: self.tabBar.frame.size.height + 8))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.refreshHelperPopupUI()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.reachabilityChanged, object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.refreshHelperPopupUI()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RouteManagerDidPauseOrResume"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.refreshHelperPopupUI()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) {[weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.refreshHelperPopupUI()
        }
    }
    
    @objc func resumeRideReport() {
        RouteRecorder.shared.routeManager.resumeTracking()
        refreshHelperPopupUI()
    }
    
    @objc func launchPermissions() {
        if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
            UIApplication.shared.openURL(appSettings)
        }
    }
    
    func refreshHelperPopupUI() {
        if let oldConstraint = xPositionConstraint {
            self.view.removeConstraint(oldConstraint)
            xPositionConstraint = nil
        }
        
        
        var furthestRightBarButtonView: UIView? = nil
        for tabBarItem in self.tabBar.subviews {
            if tabBarItem.isKind(of: NSClassFromString("UITabBarButton")!) {
                if furthestRightBarButtonView == nil || furthestRightBarButtonView!.frame.origin.x < tabBarItem.frame.origin.x {
                    furthestRightBarButtonView = tabBarItem
                }
            }
        }
        var tabBarPositionX = self.popupView.arrowBaseWidth/2 + self.popupView.arrowInset - self.popupView.strokeWidth
        if let lastView = furthestRightBarButtonView {
            tabBarPositionX += lastView.frame.origin.y
        }
        xPositionConstraint = NSLayoutConstraint(item: self.view, attribute: NSLayoutAttribute.rightMargin, relatedBy: NSLayoutRelation.equal, toItem: self.popupView, attribute: NSLayoutAttribute.right, multiplier: 1.0, constant: tabBarPositionX)
        self.view.addConstraint(xPositionConstraint!)
        
        popupView.removeTarget(self, action: nil, for: UIControlEvents.allEvents)
        
        if (RouteRecorder.shared.routeManager.isPaused()) {
            if (self.popupView.isHidden) {
                self.popupView.popIn()
            }
            if (RouteManager.authorizationStatus() == .authorizedWhenInUse) {
                self.popupView.text = "Ride Report needs permission to run in the background"
                popupView.addTarget(self, action: #selector(RideReportTabBarController.launchPermissions), for: UIControlEvents.touchUpInside)
            } else if (RouteManager.authorizationStatus() != .authorizedAlways) {
                self.popupView.text = "Ride Report needs permission to run"
                popupView.addTarget(self, action: #selector(RideReportTabBarController.launchPermissions), for: UIControlEvents.touchUpInside)
            } else {
                popupView.addTarget(self, action: #selector(RideReportTabBarController.resumeRideReport), for: UIControlEvents.touchUpInside)
                
                if let pausedUntilDate = RouteRecorder.shared.routeManager.pausedUntilDate() {
                    self.popupView.text = "Ride Report is paused until " + pausedUntilDate.colloquialDate()
                } else {
                    self.popupView.text = "Ride Report is paused"
                }
            }
        } else {
            if (!UIDevice.current.isWiFiEnabled) {
                if (self.popupView.isHidden) {
                    self.popupView.popIn()
                }
                self.popupView.text = "Ride Report works best when Wi-Fi is on"
            } else if (!self.popupView.isHidden) {
                self.popupView.fadeOut()
            }
        }
    }
}
