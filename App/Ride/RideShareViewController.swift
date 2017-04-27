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
    
    private var dateFormatter: DateFormatter!
    private var dateTimeFormatter: DateFormatter!

    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var rideSummaryView: RideNotificationView!
    @IBOutlet weak var mapView:  MGLMapView!
    
    weak var mapViewController: MapViewController? = nil
    
    private var activityViewController: UIActivityViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM d"
        
        self.dateTimeFormatter = DateFormatter()
        self.dateTimeFormatter.locale = Locale.current
        self.dateTimeFormatter.dateFormat = "MMM d 'at' h:mm a"
        
        self.updateRideSummaryView()
        
        for viewController in self.childViewControllers {
            if (viewController.isKind(of: MapViewController.self)) {
                self.mapViewController = viewController as? MapViewController
                self.mapViewController!.insets.top = 50 + (self.rideSummaryView.frame.size.height)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    //
    // MARK: - Actions
    //
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func share(_ sender: AnyObject) {
        UIGraphicsBeginImageContextWithOptions(self.shareView.bounds.size, true, 0.0);
        self.shareView.drawHierarchy(in: self.shareView.bounds, afterScreenUpdates: false)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let instagramActivity = DMActivityInstagram()
        instagramActivity.presentingView = self.view
        instagramActivity.includeURL = false
        
        var excludedActivityTypes = [UIActivityType.print, UIActivityType.assignToContact, UIActivityType.airDrop, UIActivityType.addToReadingList]
        if #available(iOS 9.0, *) {
            excludedActivityTypes.append(UIActivityType.openInIBooks)
        }
        
        self.activityViewController = UIActivityViewController(activityItems: [image, trip.shareString()], applicationActivities: [instagramActivity])
        self.activityViewController.excludedActivityTypes = excludedActivityTypes
        self.activityViewController.completionWithItemsHandler = { (activityType, completed, _, _) -> Void in
            if completed {
                Mixpanel.sharedInstance().track(
                    "sharedTrip",
                    properties: ["Type": "Unknown"]
                )
                self.dismiss(animated: true, completion: nil)
            }
        }
        
        self.present(self.activityViewController, animated: true, completion: nil)
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
        
        self.rideSummaryView.dateString = String(format: "%@", self.dateTimeFormatter.string(from: trip.startDate as Date))

        self.rideSummaryView.body = trip.fullDisplayString()
        self.rideSummaryView.hideControls(false)

    }
    
}
