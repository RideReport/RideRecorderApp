//
//  DirectionsViewController.swift
//  Ride Report
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class DirectionsViewController: UIViewController, RideSummaryViewDelegate {
    @IBOutlet weak var counter: RCounter!
    @IBOutlet weak var mapInfoToolBar: UIView!
    @IBOutlet weak var mapInfoText: UILabel!
    @IBOutlet weak var counterText: UILabel!
    
    var mapInfoIsDismissed : Bool = false
    
    private var timeFormatter : NSDateFormatter!
    private var dateFormatter : NSDateFormatter!
    private var counterTimer : NSTimer?
    
    weak var mapViewController: MapViewController! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for viewController in self.childViewControllers {
            if (viewController.isKindOfClass(MapViewController)) {
                self.mapViewController = viewController as! MapViewController
            }
        }
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.locale = NSLocale.currentLocale()
        self.timeFormatter.dateFormat = "h:mm a"
        
        // not sure why this is needed
        self.view.bringSubviewToFront(self.mapInfoToolBar)
    }
    
    //
    // MARK: - UIVIewController
    //
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadMapInfoToolBar()
        self.counter.updateCounter(0, animate: false) // we're going to animate it instead.

        NSNotificationCenter.defaultCenter().addObserverForName("APIClientAccountStatusDidGetArea", object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.reloadMapInfoToolBar()
        }

    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // animate the counter up to its current value
        if case .Area(_, let count, _, _) = APIClient.sharedClient.area {
            if !self.counter.hidden {
                var j = 0
                for var i = 0; i < Int(count); i+=499 {
                    let c = UInt(i)
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(j)*0.0167 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.counter.updateCounter(c, animate: false)
                    }
                    j += 1
                }
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(j)*0.0167 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.counter.updateCounter(count, animate: false)
                }
            }
        }
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let timer = self.counterTimer {
            timer.invalidate()
            self.counterTimer = nil
        }
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //
    // MARK: - UI Actions
    //
    
    @IBAction func showHideMapInfo(sender: AnyObject) {
        self.mapInfoIsDismissed = !self.mapInfoIsDismissed
        self.reloadMapInfoToolBar()
    }
    
    @IBAction func showRides(sender: AnyObject) {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    private func reloadMapInfoToolBar() {
        if let timer = self.counterTimer {
            timer.invalidate()
            self.counterTimer = nil
        }
        
        if (!self.mapInfoIsDismissed) {
            self.mapInfoToolBar.hidden = false
            
            switch APIClient.sharedClient.area {
            case .Unknown:
                self.mapInfoToolBar.hidden = true
            case .NonArea:
                self.counter.hidden = true
                self.counterText.hidden = true
                
                self.mapInfoText.text = String(format: "Ride Report is not yet available in your area. Every ride you take get us closer to launching!")
            case .Area(let name, let count, _, let launched) where count < 1000 && !launched:
                self.counter.hidden = true
                self.counterText.hidden = true
                
                self.mapInfoText.text = String(format: "Ride Report is not yet available in %@. Every ride you take gets us closer to launching!", name)
            case .Area(let name, let count, let countPerHour, let launched):
                self.counter.hidden = false
                self.counterText.hidden = false
                
                self.counter.updateCounter(count, animate: true)
                self.counterTimer = NSTimer.scheduledTimerWithTimeInterval(3600.0/Double(countPerHour), target: self.counter, selector: "incrementCounter", userInfo: nil, repeats: true)
                self.counterText.text = String(format: "Rides in %@", name)

                if (launched) {
                    self.mapInfoText.text = String(format: "Map shows average ratings from %@ riders. Better routes are green, stressful routes are red.", name)
                }  else {
                    self.mapInfoText.text = String(format: "Ride Report is not yet available in %@. Every ride you take gets us closer to launching!", name)
                }
            }
        } else {
            self.mapInfoToolBar.hidden = true
        }
    }
}