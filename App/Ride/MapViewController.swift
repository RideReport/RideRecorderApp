//
//  MapViewController.swift
//  Ride Report
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

class MapViewController: UIViewController, MGLMapViewDelegate, UIGestureRecognizerDelegate {
    var mainViewController: MainViewController? = nil
    
    @IBOutlet weak var mapView:  MGLMapView!
        
    private var tripsAreLoaded = false
    
    private var selectedTripLine : MGLPolyline?
    private var selectedTripBackingLine : MGLPolyline?
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    
    private var hasCenteredMap : Bool = false
    
    private var selectedIncident : Incident? = nil
        
    private var dateFormatter : NSDateFormatter!
    
    private var annotationPopOverController : UIPopoverController? = nil
    
    override func viewDidLoad() {        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd"
        
        
        self.mapView.delegate = self
        self.mapView.logoView.hidden = true
        self.mapView.attributionButton.hidden = true
        self.mapView.rotateEnabled = false
        self.mapView.backgroundColor = UIColor.darkGrayColor()
        
        self.mapView.showsUserLocation = true
        self.mapView.setCenterCoordinate(CLLocationCoordinate2DMake(45.5215907, -122.654937), zoomLevel: 14, animated: false)

        let styleURL = NSURL(string: "https://tiles.ride.report/styles/v8/heatmap-style.json")
        self.mapView.styleURL = styleURL
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = NSURLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        NSURLCache.setSharedURLCache(urlCache)
        
        if (CoreDataManager.sharedManager.isStartingUp || APIClient.sharedClient.accountVerificationStatus == .Unknown) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                if let mainVC = self.mainViewController {
                    self.setSelectedTrip(mainVC.selectedTrip)
                }

                if APIClient.sharedClient.accountVerificationStatus != .Unknown {
                    self.runCreateAccountOfferIfNeeded()
                }
            }
            NSNotificationCenter.defaultCenter().addObserverForName("APIClientAccountStatusDidChange", object: nil, queue: nil) { (notification : NSNotification) -> Void in
                NSNotificationCenter.defaultCenter().removeObserver(self, name: "APIClientAccountStatusDidChange", object: nil)
                if !CoreDataManager.sharedManager.isStartingUp {
                    self.runCreateAccountOfferIfNeeded()
                }
            }
        } else {
            if let mainVC = self.mainViewController {
                self.setSelectedTrip(mainVC.selectedTrip)
            }
        }
    }
    
    private func runCreateAccountOfferIfNeeded() {
        if (Trip.tripCount() > 10 && !NSUserDefaults.standardUserDefaults().boolForKey("hasBeenOfferedCreateAccountAfter10Trips")) {
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasBeenOfferedCreateAccountAfter10Trips")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            if (APIClient.sharedClient.accountVerificationStatus == .Unverified) {
                let actionSheet = UIActionSheet(title: "You've logged over 10 trips! Would you like to create an account so you can recover your trips if your phone is lost?", delegate: nil, cancelButtonTitle:"Nope", destructiveButtonTitle: nil, otherButtonTitles: "Create Account")
                actionSheet.tapBlock = {(actionSheet, buttonIndex) -> Void in
                    if (buttonIndex == 1) {
                        AppDelegate.appDelegate().transitionToCreatProfile()
                        
                    }
                }
                actionSheet.showFromToolbar((self.navigationController?.toolbar)!)
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //
    // MARK: - UIViewController
    //
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let mainVC = self.mainViewController {
            self.setSelectedTrip(mainVC.selectedTrip)
        }
    }
    
    override func didMoveToParentViewController(parent: UIViewController?) {
        self.mainViewController = parent as? MainViewController
    }
    
    //
    // MARK: - UI Methods
    //
    
    @IBAction func addIncident(sender: AnyObject) {
        DDLogVerbose("Add incident")
    }
    
    
    //
    // MARK: - Update Map UI
    //
    
    func setSelectedTrip(selectedTrip : Trip?) {
        if let tripBackingLine = self.selectedTripLine {
            self.mapView.removeAnnotation(tripBackingLine)
        }
        if let tripLine = self.selectedTripBackingLine {
            self.mapView.removeAnnotation(tripLine)
        }
        if let startPoint = self.startPoint {
            self.mapView.removeAnnotation(startPoint)
        }
        if let endPoint = self.endPoint {
            self.mapView.removeAnnotation(endPoint)
        }
        
        guard let trip = selectedTrip else {
            self.selectedTripLine = nil
            self.selectedTripBackingLine = nil
            
            return
        }
        
        guard trip.simplifiedLocations != nil && trip.simplifiedLocations.count > 0 else {
            dispatch_async(dispatch_get_main_queue(), {
                trip.simplify() {
                    if (trip.simplifiedLocations != nil && trip.simplifiedLocations.count > 0) {
                        self.setSelectedTrip(trip)
                    }
                }
            })
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
            count++
        }
        
        self.selectedTripLine = MGLPolyline(coordinates: &coordinates, count: count)
        self.selectedTripBackingLine = MGLPolyline(coordinates: &coordinates, count: count)

        self.mapView.addOverlay(self.selectedTripBackingLine!)
        self.mapView.addOverlay(self.selectedTripLine!)
        
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
            i++
        }
        
        let padFactorX : Double = 0.1
        let padFactorTop : Double = 0.45
        let padFactorBottom : Double = 0.3
        
        let sizeLong = (maxLong - minLong)
        let sizeLat = (maxLat - minLat)
        
        let bounds = MGLCoordinateBoundsMake(CLLocationCoordinate2DMake(minLat - (sizeLat * padFactorBottom), minLong - (sizeLong * padFactorX)), CLLocationCoordinate2DMake(maxLat + (sizeLat * padFactorTop),maxLong + (sizeLong * padFactorX))) // extra padding on the top so that it isn't under the notification bar.
        dispatch_async(dispatch_get_main_queue(), {
            self.mapView.setVisibleCoordinateBounds(bounds, animated: true)
        })
    }
    
    func addIncidentToMap(incident: Incident) {
        self.mapView.addAnnotation(incident)
        self.mapView.selectAnnotation(incident, animated: true)
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
    
    func mapView(mapView: MGLMapView, didUpdateUserLocation userLocation: MGLUserLocation?) {
        if (!self.hasCenteredMap && userLocation != nil) {
            if let mainVC = self.mainViewController {
                if (mainVC.selectedTrip == nil) {
                    // don't recenter the map if the user has already selected a trip
                    
                    self.mapView.setCenterCoordinate(userLocation!.coordinate, zoomLevel: 14, animated: false)
                }
            }
        
            self.hasCenteredMap = true
        }
    }
    
    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        if (annotation.isKindOfClass(Incident)) {
            return true
        }
        
        return false
    }
    
    func mapView(mapView: MGLMapView, rightCalloutAccessoryViewForAnnotation annotation: MGLAnnotation) -> UIView? {
        let view = UIButton(type: UIButtonType.DetailDisclosure)
        
        return view
    }
    
    func mapView(mapView: MGLMapView, annotation: MGLAnnotation, calloutAccessoryControlTapped control: UIControl) {
        self.mainViewController!.performSegueWithIdentifier("showIncidentEditor", sender: self.selectedIncident)
    }
    
    func mapView(mapView: MGLMapView, didSelectAnnotation annotation: MGLAnnotation) {
        self.selectedIncident = annotation as? Incident
    }
    
    func mapView(mapView: MGLMapView, didDeselectAnnotation annotation: MGLAnnotation) {
        self.selectedIncident = nil
    }
    
    func mapView(mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        if (annotation == self.selectedTripBackingLine) {
            return 14
        } else if (annotation == self.selectedTripLine) {
            return 8
        }

        return 0
    }
    
    func mapView(mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        if (annotation == self.selectedTripBackingLine) {
            return 1.0
        } else if (annotation == self.selectedTripLine) {
            return 1.0
        }
        
        return 0
    }
    
    func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        if (annotation == self.selectedTripBackingLine) {
            return UIColor.whiteColor()
        }
        
        if let mainVC = self.mainViewController, trip = mainVC.selectedTrip {
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