//
//  RideShareToImageView.swift
//  Ride
//
//  Created by William Henderson on 12/11/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Mixpanel

class RideShareViewController : UIViewController, MGLMapViewDelegate {
    var trip: Trip! {
        didSet {
            guard self.view != nil else {
                // view has not loaded yet.
                return
            }
            
            self.updateTripPolylines()
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
    @IBOutlet weak var statsFirstLineLabel:  UILabel!
    @IBOutlet weak var statsSecondLineLabel:  UILabel!
    
    private var activityViewController: UIActivityViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.delegate = self
        self.mapView.logoView.hidden = true
        self.mapView.attributionButton.hidden = true
        self.mapView.rotateEnabled = false
        self.mapView.backgroundColor = UIColor.darkGrayColor()
        
        self.mapView.showsUserLocation = false
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MMM d"
        
        self.dateTimeFormatter = NSDateFormatter()
        self.dateTimeFormatter.locale = NSLocale.currentLocale()
        self.dateTimeFormatter.dateFormat = "MMM d 'at' h:mm a"
        
        let styleURL = NSURL(string: "https://tiles.ride.report/styles/v8/base-style.json")
        self.mapView.styleURL = styleURL
        
        self.updateTripPolylines()
        self.updateRideSummaryView()
        
        let formatter = NSNumberFormatter()
        formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        formatter.maximumFractionDigits = 0

        if let firstTripDate = Profile.profile().firstTripDate {
            self.statsFirstLineLabel.text = String(format: "%@%@ miles biked since %@", Profile.profile().milesBikedJewel, formatter.stringFromNumber(NSNumber(float: Profile.profile().milesBiked))!, dateFormatter.stringFromDate(firstTripDate))
        } else {
            self.statsFirstLineLabel.text = ""
        }
        
        if let longestStreak = Profile.profile().longestStreakLength?.integerValue, longestStreakLengthDate = Profile.profile().longestStreakStartDate {
            self.statsSecondLineLabel.text = String(format: "%@  Longest streak: %i days on %@", Profile.profile().longestStreakJewel, longestStreak, dateFormatter.stringFromDate(longestStreakLengthDate))
        } else {
            self.statsSecondLineLabel.text = ""
        }
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
        let image = UIGraphicsGetImageFromCurrentImageContext()
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

        self.rideSummaryView.body = trip.notificationString()!
        self.rideSummaryView.hideControls(false)

    }
    
    func updateTripPolylines() {
        if let tripBackingLine = self.tripBackingLine {
            self.mapView.removeAnnotation(tripBackingLine)
        }
        if let tripLine = self.tripLine {
            self.mapView.removeAnnotation(tripLine)
        }
        if let startPoint = self.startPoint {
            self.mapView.removeAnnotation(startPoint)
        }
        if let endPoint = self.endPoint {
            self.mapView.removeAnnotation(endPoint)
        }
        
        guard let trip = self.trip else {
            self.tripLine = nil
            self.tripBackingLine = nil
            
            return
        }
        
        if let startLoc = trip.simplifiedLocations.firstObject as? Location,
        endLoc = trip.simplifiedLocations.lastObject as? Location {
            self.startPoint = MGLPointAnnotation()
            self.startPoint!.coordinate = startLoc.coordinate()
            mapView.addAnnotation(self.startPoint!)
            
            self.endPoint = MGLPointAnnotation()
            self.endPoint!.coordinate = endLoc.coordinate()
            mapView.addAnnotation(self.endPoint!)
        }
        
        var coordinates : [CLLocationCoordinate2D] = []
        var count : UInt = 0
        for location in trip.simplifiedLocations.array {
            let location = (location as! Location)
            
            let coord = location.coordinate()
            
            coordinates.append(coord)
            count += 1
        }
        
        self.tripLine = MGLPolyline(coordinates: &coordinates, count: count)
        self.tripBackingLine = MGLPolyline(coordinates: &coordinates, count: count)
        
        self.mapView.addOverlay(self.tripBackingLine!)
        self.mapView.addOverlay(self.tripLine!)
        
        
        let point0 = coordinates[0]
        var minLong : Double = point0.longitude
        var maxLong : Double = point0.longitude
        var minLat : Double = point0.latitude
        var maxLat : Double = point0.latitude
        
        var i = 1
        let pointCount = (Int)(count)
        while i < pointCount {
            let point = coordinates[i]
            if (point.longitude < minLong) {
                minLong = point.longitude
            } else if (point.longitude > maxLong) {
                maxLong = point.longitude
            }
            
            if (point.latitude < minLat) {
                minLat = point.latitude
            } else if (point.latitude > maxLat) {
                maxLat = point.latitude
            }
            i += 1
        }
        
        let padFactorX : Double = 0.1
        let padFactorTop : Double = 0.95
        let padFactorBottom : Double = 0.8

        let sizeLong = (maxLong - minLong)
        let sizeLat = (maxLat - minLat)
        
        let bounds = MGLCoordinateBoundsMake(CLLocationCoordinate2DMake(minLat - (sizeLat * padFactorBottom), minLong - (sizeLong * padFactorX)), CLLocationCoordinate2DMake(maxLat + (sizeLat * padFactorTop),maxLong + (sizeLong * padFactorX)))
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.mapView.setVisibleCoordinateBounds(bounds, animated: false)
        })
    }

    
    //
    // MARK: - Map Kit
    //
    
    func mapView(mapView: MGLMapView, imageForAnnotation annotation: MGLAnnotation) -> MGLAnnotationImage? {
        var annotationImage: MGLAnnotationImage? = nil
        if let startPoint = self.startPoint, pointAnnotation = annotation as? MGLPointAnnotation where pointAnnotation == startPoint {
            annotationImage = mapView.dequeueReusableAnnotationImageWithIdentifier("startMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinGreen.png")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "startMarker")
            }
        } else if let endPoint = self.endPoint, pointAnnotation = annotation as? MGLPointAnnotation where pointAnnotation == endPoint {
            annotationImage = mapView.dequeueReusableAnnotationImageWithIdentifier("endMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinRed.png")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "endMarker")
            }
        }

        
        return annotationImage
    }
    
    func mapView(mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        if (annotation == self.tripBackingLine) {
            return 14
        } else {
            return 8
        }
    }
    
    func mapView(mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        return 1.0
    }
    
    func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        if (annotation == self.tripBackingLine) {
            return UIColor.whiteColor()
        }
        
        if let trip = self.trip {
            if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
                    return ColorPallete.sharedPallete.goodGreen
                } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
                    return ColorPallete.sharedPallete.badRed
                } else {
                    return ColorPallete.sharedPallete.unknownGrey
                }
            } else if (trip.activityType.shortValue == Trip.ActivityType.Transit.rawValue) {
                return ColorPallete.sharedPallete.transitBlue
            }
            
            return ColorPallete.sharedPallete.autoBrown
        }
        
        return UIColor.clearColor()
    }
    
}