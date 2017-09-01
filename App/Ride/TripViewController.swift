//
//  TripViewController.swift
//  Ride Report
//
//  Created by William Henderson on 12/16/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class TripViewController: UIViewController {
    var mapInfoIsDismissed : Bool = false
    var isInitialTripUpdate = true
    var hasRequestedTripInfo : Bool = false
    
    private var hasGivenFeedbackForReachedThreshold = true
    private var feedbackGenerator: NSObject!
    
    @IBOutlet weak var tripSummaryContainerView: UIView!
    
    weak var tripSummaryViewController: TripSummaryViewController? = nil
    weak var mapViewController: MapViewController? = nil
    
    var selectedTrip : Trip! {
        didSet {
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self, let _ = strongSelf.tripSummaryViewController else {
                    return
                }
                
                if (strongSelf.selectedTrip != nil) {
                    if (!strongSelf.hasRequestedTripInfo && (strongSelf.selectedTrip.areLocationsNotYetDownloaded || !strongSelf.selectedTrip.isSummarySynced)) {
                        strongSelf.hasRequestedTripInfo = true
                        RideReportAPIClient.shared.getTrip(strongSelf.selectedTrip).apiResponse({ [weak self] (_) -> Void in
                            guard let reallyStrongSelf = self else {
                                return
                            }
                            
                            reallyStrongSelf.updateChildViews()
                        })
                    }
                    
                    strongSelf.updateChildViews()
                } else {
                    if let mapViewController = strongSelf.mapViewController {
                        mapViewController.setSelectedTrip(strongSelf.selectedTrip)
                    }
                }
            })
        }
    }
    
    private func updateChildViews() {
        if let tripSummaryViewController = self.tripSummaryViewController {
            tripSummaryViewController.selectedTrip = self.selectedTrip
        }
        
        self.updateMapViewDisplayBounds()
    }
    
    private func updateMapViewDisplayBounds() {
        if let mapViewController = self.mapViewController {
            mapViewController.insets.bottom = 20 + (self.view.frame.size.height - self.tripSummaryContainerView.frame.origin.y)
            
            mapViewController.setSelectedTrip(self.selectedTrip)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.medium)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
        
        for viewController in self.childViewControllers {
            if (viewController.isKind(of: MapViewController.self)) {
                self.mapViewController = viewController as? MapViewController
            } else if (viewController.isKind(of: TripSummaryViewController.self)) {
                self.tripSummaryViewController = viewController as? TripSummaryViewController
                NSLayoutConstraint(item: self.tripSummaryContainerView, attribute: .height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: viewController.view.bounds.height).isActive = true
            }
        }
    }
    
    //
    // MARK: - UIVIewController
    //
    
    @IBAction func tappedShare(_: AnyObject) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let rideShareNavVC = storyBoard.instantiateViewController(withIdentifier: "RideShareNavViewController") as! UINavigationController
        if let rideShareVC = rideShareNavVC.topViewController as? RideShareViewController {
            rideShareVC.trip = self.selectedTrip
        }
        self.present(rideShareNavVC, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "TripSummaryViewDidChangeHeight"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            if let tripSummaryVC = strongSelf.tripSummaryViewController {
                tripSummaryVC.selectedTrip = strongSelf.selectedTrip
                let peakY = strongSelf.view.frame.size.height - tripSummaryVC.peakY
                strongSelf.tripSummaryContainerView.frame = CGRect(x: 0, y: peakY, width: strongSelf.view.frame.width, height: strongSelf.view.frame.height)
            } else {
                return
            }
        }
    }
    
    func panGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let tripSummaryViewController = self.tripSummaryViewController else {
            return
        }
        
        let translation = recognizer.translation(in: self.view)

        let velocity = recognizer.velocity(in: tripSummaryContainerView)
        let minY = self.view.frame.size.height - tripSummaryViewController.maxY
        let maxY = self.view.frame.size.height - tripSummaryViewController.minY
        
        let locY = (tripSummaryContainerView.center.y + translation.y) - tripSummaryContainerView.frame.height/2.0
        if (locY <= maxY) && (locY >= minY) {
            let feedbackBufferHeight: CGFloat = 10
            if (locY < maxY - feedbackBufferHeight && locY > minY + feedbackBufferHeight) {
                hasGivenFeedbackForReachedThreshold = false
            }
            tripSummaryContainerView.center = CGPoint(x: tripSummaryContainerView.center.x, y: tripSummaryContainerView.center.y + translation.y)
            recognizer.setTranslation(CGPoint.zero, in: self.view)
        } else {
            if (!hasGivenFeedbackForReachedThreshold) {
                hasGivenFeedbackForReachedThreshold = true
                if #available(iOS 10.0, *) {
                    if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                        feedbackGenerator.impactOccurred()
                    }
                }
            }
        }
        
        if recognizer.state == .ended {
            let speedConst: CGFloat = 300
            var duration =  velocity.y < 0 ? Double(speedConst / -velocity.y) : Double(speedConst / velocity.y )

            duration = min(duration, 0.3)
            
            UIView.animate(withDuration: duration, animations: { 
                if  velocity.y >= 0 {
                    self.tripSummaryContainerView.frame = CGRect(x: 0, y: maxY, width: self.tripSummaryContainerView.frame.width, height: self.tripSummaryContainerView.frame.height)
                } else {
                    self.tripSummaryContainerView.frame = CGRect(x: 0, y: minY, width: self.tripSummaryContainerView.frame.width, height: self.tripSummaryContainerView.frame.height)
                }
            }, completion: { (didComplete) in
                self.updateMapViewDisplayBounds()
                
                if (didComplete && !self.hasGivenFeedbackForReachedThreshold) {
                    self.hasGivenFeedbackForReachedThreshold = true
                    if #available(iOS 10.0, *) {
                        if let feedbackGenerator = self.feedbackGenerator as? UIImpactFeedbackGenerator {
                            feedbackGenerator.impactOccurred()
                        }
                    }
                }
                self.hasGivenFeedbackForReachedThreshold = true
            })
        }
    }
    
    private var hasLaidOutShadown = false
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let tripSummaryViewController = self.tripSummaryViewController, !hasLaidOutShadown {
            hasLaidOutShadown = true
            let gesture = UIPanGestureRecognizer.init(target: self, action: #selector(TripViewController.panGesture))
            tripSummaryViewController.view.addGestureRecognizer(gesture)
            
            let blurRadius: CGFloat = 2
            let cornerRadius: CGFloat = 7
            let yOffset: CGFloat = 0.5
            
            let shadowLayer = CALayer();
            shadowLayer.shadowColor = UIColor.black.cgColor
            shadowLayer.shadowOffset = CGSize(width: 0,height: yOffset)
            shadowLayer.shadowOpacity = 0.6
            shadowLayer.shadowRadius = blurRadius
            shadowLayer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: cornerRadius).cgPath
            
            // Shadow mask frame
            let frame = view.layer.frame.insetBy(dx: 0, dy: -2*blurRadius).offsetBy(dx: 0, dy: yOffset)
            
            let trans = CGAffineTransform(translationX: -view.frame.origin.x,
                                          y: -view.frame.origin.y - yOffset + 2*blurRadius)
            
            let path = CGMutablePath()
            path.__addRoundedRect(transform: nil, rect: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius)
            path.addPath(shadowLayer.shadowPath!, transform: trans)
            path.closeSubpath()
            
            let maskLayer = CAShapeLayer()
            maskLayer.frame = frame
            maskLayer.fillRule = kCAFillRuleEvenOdd
            maskLayer.path = path
            
            shadowLayer.mask = maskLayer
            tripSummaryContainerView.layer.insertSublayer(shadowLayer, above: view.layer)
            tripSummaryViewController.view.layer.cornerRadius = cornerRadius
            tripSummaryViewController.view.clipsToBounds = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: CoreDataManager.shared.managedObjectContext, queue: nil) {[weak self] (notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.selectedTrip != nil else {
                return
            }
            
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? NSSet {
                if updatedObjects.contains(strongSelf.selectedTrip) {
                    let trip = strongSelf.selectedTrip
                    strongSelf.selectedTrip = trip
                }
            }
            
            if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? NSSet {
                if deletedObjects.contains(strongSelf.selectedTrip) {
                    strongSelf.selectedTrip = nil
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }

    
    //
    // MARK: - UI Actions
    //
    
    @IBAction func showRides(_ sender: AnyObject) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}
