//
//  DirectionsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import RouteRecorder

class DirectionsViewController: UIViewController, RideNotificationViewDelegate {
    @IBOutlet weak var counter: RCounter!
    @IBOutlet weak var mapInfoToolBar: UIView!
    @IBOutlet weak var mapInfoText: UILabel!
    @IBOutlet weak var counterText: UILabel!
    
    var mapInfoIsDismissed : Bool = false
    
    private var timeFormatter : DateFormatter!
    private var dateFormatter : DateFormatter!
    private var counterTimer : Timer?
    
    weak var mapViewController: MapViewController! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for viewController in self.childViewControllers {
            if (viewController.isKind(of: MapViewController.self)) {
                self.mapViewController = viewController as! MapViewController
                if let loc = RouteRecorder.shared.locationManager.location {
                    self.mapViewController.mapView.setCenter(loc.coordinate, zoomLevel: 14, animated: false)
                } else {
                    self.mapViewController.mapView.setCenter(CLLocationCoordinate2DMake(45.5215907, -122.654937), zoomLevel: 14, animated: false)
                }
                self.mapViewController.mapView.userTrackingMode = .follow
                self.mapViewController.mapView.showsUserLocation = true
            }
        }
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = DateFormatter()
        self.timeFormatter.locale = Locale.current
        self.timeFormatter.dateFormat = "h:mm a"
        
        // not sure why this is needed
        self.view.bringSubview(toFront: self.mapInfoToolBar)
    }
    
    //
    // MARK: - UIVIewController
    //
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadMapInfoToolBar()

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RideReportAPIClientAccountStatusDidGetArea"), object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reloadMapInfoToolBar()
        }

    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let timer = self.counterTimer {
            timer.invalidate()
            self.counterTimer = nil
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    //
    // MARK: - UI Actions
    //
    
    @IBAction func showHideMapInfo(_ sender: AnyObject) {
        self.mapInfoIsDismissed = !self.mapInfoIsDismissed
        self.reloadMapInfoToolBar()
    }
    
    @IBAction func showRides(_ sender: AnyObject) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    
    private func reloadMapInfoToolBar() {
        if let timer = self.counterTimer {
            timer.invalidate()
            self.counterTimer = nil
        }
        
        if (!self.mapInfoIsDismissed) {
            self.mapInfoToolBar.isHidden = false
            
            switch RideReportAPIClient.shared.area {
            case .unknown:
                self.mapInfoToolBar.isHidden = true
            case .nonArea:
                self.counter.isHidden = true
                self.counterText.isHidden = true
                
                self.mapInfoText.text = String(format: "Ride Report doesn't have enough trips to show a map in your area. Every ride you take get us closer!")
            case .area(let name, let count, _, let launched) where count < 1000 && !launched:
                self.counter.isHidden = true
                self.counterText.isHidden = true
                
                self.mapInfoText.text = String(format: "Ride Report doesn't have enough trips to show a map in %@. Every ride you take get us closer!", name)
            case .area(let name, let meters, let metersPerHour, let launched):
                self.counter.isHidden = false
                self.counterText.isHidden = false
                
                let milesOrKm = Meters(meters).localizedMajorUnit
                let milesOrKmPerHour = Meters(metersPerHour).localizedMajorUnit
                let isMiles = (milesOrKm == Meters(meters).miles)
                let duration = 3600.0/Double(Int(milesOrKmPerHour))
                
                self.counter.update(UInt(milesOrKm) - 1, animate: false)
                self.counter.animationDuration = duration - 0.1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.counter.update(UInt(milesOrKm), animate: true) //animate in the first mile
                })
                
                self.counterTimer = Timer.scheduledTimer(timeInterval: duration, target: self.counter, selector: #selector(RCounter.incrementCounter as (RCounter) -> () -> Void), userInfo: nil, repeats: true)
                self.counterText.text = String(format: "%@ Biked in %@", isMiles ? "Miles" : "KM", name)

                if (launched) {
                    self.mapInfoText.text = String(format: "Map shows average ratings from %@ riders. Better routes are green, stressful routes are red.", name)
                }  else {
                    self.mapInfoText.text = String(format: "Ride Report doesn't have enough trips to show a map in %@. Every ride you take get us closer!", name)
                }
            }
        } else {
            self.mapInfoToolBar.isHidden = true
        }
    }
}
