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
    
    private var hasGivenFeedbackForReachedThreshold = false
    private var feedbackGenerator: NSObject!
    
    @IBOutlet weak var tripSummaryContainerView: UIView!
    
    weak var tripSummaryViewController: TripSummaryViewController? = nil
    weak var mapViewController: MapViewController? = nil
    
    var selectedTrip : Trip! {
        didSet {
            dispatch_async(dispatch_get_main_queue(), { [weak self] in
                guard let strongSelf = self, _ = strongSelf.tripSummaryViewController else {
                    return
                }
                
                if (strongSelf.selectedTrip != nil) {
                    if (!strongSelf.hasRequestedTripInfo && (strongSelf.selectedTrip.locationsNotYetDownloaded || !strongSelf.selectedTrip.summaryIsSynced)) {
                        strongSelf.hasRequestedTripInfo = true
                        APIClient.sharedClient.getTrip(strongSelf.selectedTrip).apiResponse({ [weak self] (_) -> Void in
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
            mapViewController.padFactorTop = 0.2
            mapViewController.padFactorBottom = 3 * Double((self.view.frame.size.height - self.tripSummaryContainerView.frame.origin.y) / (self.view.frame.size.height))
            
            mapViewController.setSelectedTrip(self.selectedTrip)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 10.0, *) {
            self.feedbackGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.Medium)
            (self.feedbackGenerator as! UIImpactFeedbackGenerator).prepare()
        }
        
        for viewController in self.childViewControllers {
            if (viewController.isKindOfClass(MapViewController)) {
                self.mapViewController = viewController as? MapViewController
            } else if (viewController.isKindOfClass(TripSummaryViewController)) {
                self.tripSummaryViewController = viewController as? TripSummaryViewController
                NSLayoutConstraint(item: self.tripSummaryContainerView, attribute: .Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: viewController.view.bounds.height).active = true
            }
        }
    }
    
    //
    // MARK: - UIVIewController
    //
    
    @IBAction func tappedShare(_: AnyObject) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let rideShareNavVC = storyBoard.instantiateViewControllerWithIdentifier("RideShareNavViewController") as! UINavigationController
        if let rideShareVC = rideShareNavVC.topViewController as? RideShareViewController {
            rideShareVC.trip = self.selectedTrip
        }
        self.presentViewController(rideShareNavVC, animated: true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.enabled = false
        
        if let tripSummaryViewController = self.tripSummaryViewController {
            let gesture = UIPanGestureRecognizer.init(target: self, action: #selector(TripViewController.panGesture))
            tripSummaryViewController.view.addGestureRecognizer(gesture)
            
            let blurRadius: CGFloat = 2
            let cornerRadius: CGFloat = 7
            let yOffset: CGFloat = 0.5
            
            let shadowLayer = CALayer();
            shadowLayer.shadowColor = UIColor.blackColor().CGColor
            shadowLayer.shadowOffset = CGSizeMake(0,yOffset)
            shadowLayer.shadowOpacity = 0.6
            shadowLayer.shadowRadius = blurRadius
            shadowLayer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: cornerRadius).CGPath
            
            // Shadow mask frame
            let frame = CGRectOffset(CGRectInset(view.layer.frame, 0, -2*blurRadius), 0, yOffset)
            
            var trans = CGAffineTransformMakeTranslation(-view.frame.origin.x,
                                                         -view.frame.origin.y - yOffset + 2*blurRadius)
            
            let path = CGPathCreateMutable()
            CGPathAddRoundedRect(path, nil, CGRectMake(0, 0, frame.size.width, frame.size.height), cornerRadius, cornerRadius)
            CGPathAddPath(path, &trans, shadowLayer.shadowPath!)
            CGPathCloseSubpath(path)
            
            let maskLayer = CAShapeLayer()
            maskLayer.frame = frame
            maskLayer.fillRule = kCAFillRuleEvenOdd
            maskLayer.path = path
            
            shadowLayer.mask = maskLayer
            tripSummaryContainerView.layer.insertSublayer(shadowLayer, above: view.layer)
            tripSummaryViewController.view.layer.cornerRadius = cornerRadius
            tripSummaryViewController.view.clipsToBounds = true
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName("TripSummaryViewDidChangeHeight", object: nil, queue: nil) {[weak self] (notification : NSNotification) -> Void in
            guard let strongSelf = self else {
                return
            }
            if let tripSummaryVC = strongSelf.tripSummaryViewController {
                tripSummaryVC.selectedTrip = strongSelf.selectedTrip
                let peakY = strongSelf.view.frame.size.height - tripSummaryVC.peakY
                strongSelf.tripSummaryContainerView.frame = CGRectMake(0, peakY, strongSelf.view.frame.width, strongSelf.view.frame.height)
            } else {
                return
            }
        }
    }
    
    func panGesture(recognizer: UIPanGestureRecognizer) {
        guard let tripSummaryViewController = self.tripSummaryViewController else {
            return
        }
        
        let translation = recognizer.translationInView(self.view)

        let velocity = recognizer.velocityInView(tripSummaryContainerView)
        let minY = self.view.frame.size.height - tripSummaryViewController.maxY
        let maxY = self.view.frame.size.height - tripSummaryViewController.peakY
        
        let locY = (tripSummaryContainerView.center.y + translation.y) - tripSummaryContainerView.frame.height/2.0
        if (locY <= maxY) && (locY >= minY) {
            hasGivenFeedbackForReachedThreshold = false
            tripSummaryContainerView.center = CGPointMake(tripSummaryContainerView.center.x, tripSummaryContainerView.center.y + translation.y)
            recognizer.setTranslation(CGPointZero, inView: self.view)
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
        
        if recognizer.state == .Ended {
            let speedConst: CGFloat = 300
            var duration =  velocity.y < 0 ? Double(speedConst / -velocity.y) : Double(speedConst / velocity.y )

            duration = min(duration, 0.3)
            
            UIView.animateWithDuration(duration, animations: { 
                if  velocity.y >= 0 {
                    self.tripSummaryContainerView.frame = CGRectMake(0, maxY, self.tripSummaryContainerView.frame.width, self.tripSummaryContainerView.frame.height)
                } else {
                    self.tripSummaryContainerView.frame = CGRectMake(0, minY, self.tripSummaryContainerView.frame.width, self.tripSummaryContainerView.frame.height)
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
                self.hasGivenFeedbackForReachedThreshold = false
            })
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextObjectsDidChangeNotification, object: CoreDataManager.sharedManager.managedObjectContext, queue: nil) {[weak self] (notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.selectedTrip != nil else {
                return
            }
            
            if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? NSSet {
                if updatedObjects.containsObject(strongSelf.selectedTrip) {
                    let trip = strongSelf.selectedTrip
                    strongSelf.selectedTrip = trip
                }
            }
            
            if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? NSSet {
                if deletedObjects.containsObject(strongSelf.selectedTrip) {
                    strongSelf.selectedTrip = nil
                }
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    
    //
    // MARK: - UI Actions
    //
    
    @IBAction func showRides(sender: AnyObject) {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
}
