//
//  RideShareToImageView.swift
//  Ride
//
//  Created by William Henderson on 12/11/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Mixpanel

class RideShareViewController : UIViewController {
    var trip: Trip! {
        didSet {
            guard self.view != nil else {
                // view has not loaded yet.
                return
            }
            
            if let mapViewController = self.mapViewController {
                mapViewController.setSelectedTrip(self.trip)
            }
            
            self.updateRideSummaryView()
        }
    }
    
    private var tripBackingLine: MGLPolyline?
    private var tripLine: MGLPolyline?
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    
    private var dateFormatter: NSDateFormatter!
    private var dateTimeFormatter: NSDateFormatter!

    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var rideSummaryView: RideSummaryView!
    @IBOutlet weak var mapView:  MGLMapView!
    
    weak var mapViewController: MapViewController? = nil
    
    private var activityViewController: UIActivityViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.dateTimeFormatter = NSDateFormatter()
        self.dateTimeFormatter.locale = NSLocale.currentLocale()
        self.dateTimeFormatter.dateFormat = "MMM d 'at' h:mm a"
        
        self.updateRideSummaryView()
        
        for viewController in self.childViewControllers {
            if (viewController.isKindOfClass(MapViewController)) {
                self.mapViewController = viewController as? MapViewController
                self.mapViewController!.padFactorX = 0.1
                self.mapViewController!.padFactorTop = 1.0
                self.mapViewController!.padFactorBottom = 0.2
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    //
    // MARK: - Actions
    //
    
    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func share(sender: AnyObject) {
        UIGraphicsBeginImageContextWithOptions(self.shareView.bounds.size, true, 0.0);
        self.shareView.drawViewHierarchyInRect(self.shareView.bounds, afterScreenUpdates: false)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let instagramActivity = DMActivityInstagram()
        instagramActivity.presentingView = self.view
        instagramActivity.includeURL = false
        
        var excludedActivityTypes = [UIActivityTypePrint, UIActivityTypeAssignToContact, UIActivityTypeAirDrop, UIActivityTypeAddToReadingList]
        if #available(iOS 9.0, *) {
            excludedActivityTypes.append(UIActivityTypeOpenInIBooks)
        }
        
        self.activityViewController = UIActivityViewController(activityItems: [image, trip.shareString()], applicationActivities: [instagramActivity])
        self.activityViewController.excludedActivityTypes = excludedActivityTypes
        self.activityViewController.completionWithItemsHandler = { (activityType, completed, _, _) -> Void in
            if completed {
                Mixpanel.sharedInstance().track(
                    "sharedTrip",
                    properties: ["Type": activityType ?? "Unknown"]
                )
                self.dismissViewControllerAnimated(true, completion: nil)
            }
        }
        
        self.presentViewController(self.activityViewController, animated: true, completion: nil)
    }
    
    //
    // MARK: - UI Code
    //
    
    func updateRideSummaryView() {
        guard let trip = self.trip else {
            self.tripLine = nil
            self.tripBackingLine = nil
            
            return
        }
        
        self.rideSummaryView.dateString = String(format: "%@", self.dateTimeFormatter.stringFromDate(trip.startDate))

        self.rideSummaryView.body = trip.fullDisplayString()
        self.rideSummaryView.hideControls(false)

    }
    
}
