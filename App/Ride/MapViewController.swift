//
//  MapViewController.swift
//  Ride
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import MapboxGL

class MapViewController: UIViewController, MGLMapViewDelegate, UIGestureRecognizerDelegate {
    var mainViewController: MainViewController! = nil
    
    @IBOutlet weak var mapView:  MGLMapView!
    
    @IBOutlet weak var privacyCircleToolbar: UIToolbar!
    
    private var tripsAreLoaded = false
    private var tripPolyLines : [Trip : MGLPolyline]!
    private var hasCenteredMap : Bool = false
    
//    private var privacyCircle : MKCircle?
//    private var geofenceCircles : [MKCircle] = []
    private var privacyCircleRenderer : PrivacyCircleRenderer?
    private var isDraggingPrivacyCircle : Bool = false
    private var privacyCirclePanGesture : UIPanGestureRecognizer!
    
    private var selectedIncident : Incident? = nil
        
    private var dateFormatter : NSDateFormatter!
    
    private var annotationPopOverController : UIPopoverController? = nil
    
    override func viewDidLoad() {        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd"
        
        self.privacyCirclePanGesture = UIPanGestureRecognizer(target: self, action: "respondToPrivacyCirclePanGesture:")
        self.privacyCirclePanGesture.delegate = self
        
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        self.mapView.setCenterCoordinate(CLLocationCoordinate2DMake(45.5215907, -122.654937), zoomLevel: 14, animated: false)

        self.mapView.addGestureRecognizer(self.privacyCirclePanGesture)
        let styleURL = NSURL(string: "http://tiles.ride.report/styles/heatmap-style.json")
        self.mapView.styleURL = styleURL
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = NSURLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        NSURLCache.setSharedURLCache(urlCache)
    
        
        self.tripPolyLines = [:]
        
        if (RouteManager.sharedManager.currentTrip != nil) {
            self.mainViewController.selectedTrip = RouteManager.sharedManager.currentTrip
        }

        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.loadTrips()
        }

        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.unloadTrips()
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.unloadTrips()
        }
        
        if (CoreDataManager.sharedManager.isStartingUp) {
            NSNotificationCenter.defaultCenter().addObserverForName("CoreDataManagerDidStartup", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
                self.loadTrips()
            }
        } else {
            self.loadTrips()
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
        
        self.loadTrips()
        self.refreshTrip(self.mainViewController.selectedTrip)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        self.unloadTrips()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
                
        self.unloadTrips()
    }
    
    override func didMoveToParentViewController(parent: UIViewController?) {
        self.mainViewController = parent as! MainViewController
    }
    
    //
    // MARK: - UI Methods
    //
    
    func enterPrivacyCircleEditor() {
//        if (self.privacyCircle == nil) {
//            if (PrivacyCircle.privacyCircle() == nil) {
//                self.privacyCircle = MKCircle(centerCoordinate: mapView.userLocation.coordinate, radius: PrivacyCircle.defaultRadius())
//            } else {
//                self.privacyCircle = MKCircle(centerCoordinate: CLLocationCoordinate2DMake(PrivacyCircle.privacyCircle().latitude.doubleValue, PrivacyCircle.privacyCircle().longitude.doubleValue), radius: PrivacyCircle.privacyCircle().radius.doubleValue)
//            }
//            self.mapView.addOverlay(self.privacyCircle, level: MKOverlayLevel.AboveLabels)
//        }
//        self.privacyCircleToolbar.hidden = false
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func respondToPrivacyCirclePanGesture(sender: AnyObject) {
//        if (self.privacyCircle == nil || self.privacyCircleRenderer == nil) {
//            return
//        }
//        
//        if (sender.numberOfTouches() > 1) {
//            return
//        }
//        
//        if (sender.state == UIGestureRecognizerState.Began) {
//            let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
//            let gestureLocation = CLLocation(latitude: gestureCoord.latitude, longitude: gestureCoord.longitude)
//            
//            let circleLocation = CLLocation(latitude: self.privacyCircle!.coordinate.latitude, longitude: self.privacyCircle!.coordinate.longitude)
//            
//            if (gestureLocation.distanceFromLocation(circleLocation) <= self.privacyCircle!.radius) {
//                self.mapView.scrollEnabled = false
//                self.isDraggingPrivacyCircle = true
//            } else {
//                self.mapView.scrollEnabled = true
//                self.isDraggingPrivacyCircle = false
//            }
//        } else if (sender.state == UIGestureRecognizerState.Changed) {
//            if (self.isDraggingPrivacyCircle) {
//                let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
//                
//                let oldPrivacyCircle = self.privacyCircle
//                self.privacyCircle! = MKCircle(centerCoordinate: gestureCoord, radius: self.privacyCircle!.radius)
////                self.mapView.addOverlay(self.privacyCircle, level: MKOverlayLevel.AboveLabels)
////                self.mapView.removeOverlay(oldPrivacyCircle)
//            }
//        } else {
//            self.mapView.scrollEnabled = true
//            self.isDraggingPrivacyCircle = false
//        }
    }

    @IBAction func cancelSetPrivacyCircle(sender: AnyObject) {
//        self.privacyCircleToolbar.hidden = true
//        
////        self.mapView.removeOverlay(self.privacyCircle)
//        self.mapView.setNeedsDisplay()
//        self.privacyCircle = nil
//        self.privacyCircleRenderer = nil
//    }
//    
//    @IBAction func saveSetPrivacyCircle(sender: AnyObject) {
//        if (self.privacyCircle == nil || self.privacyCircleRenderer == nil) {
//            return
//        }
//        
//        PrivacyCircle.updateOrCreatePrivacyCircle(self.privacyCircle!)
//        
//        self.privacyCircleToolbar.hidden = true
//        
////        self.mapView.removeOverlay(self.privacyCircle)
//        self.mapView.setNeedsDisplay()
//        self.privacyCircle = nil
//        self.privacyCircleRenderer = nil
//        
//        self.unloadTrips()
//        self.loadTrips()
    }
    
    @IBAction func addIncident(sender: AnyObject) {
        DDLogVerbose("Add incident")
    }
    
    
    //
    // MARK: - Update Map UI
    //
    
    func refreshGeofences() {
//        for oldOverlay in self.geofenceCircles {
////            self.mapView.removeOverlay(oldOverlay)
//        }
//        
//        self.geofenceCircles = []
//        
//        for region in RouteManager.sharedManager.geofenceSleepRegions {
//            let circle = MKCircle(centerCoordinate: region.center, radius: region.radius)
//            self.geofenceCircles.append(circle)
////            self.mapView.addOverlay(circle, level: MKOverlayLevel.AboveLabels)
//        }
    }
    
    
    func loadTrips() {
        if (CoreDataManager.sharedManager.isStartingUp) {
            return
        }
                
        if (self.tripsAreLoaded) {
            return
        }
        
        self.tripsAreLoaded = true
        
        // important to perform fetch on main thread
//        let trips = Trip.allTrips()
//        
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
//            for trip in trips {
//                self.refreshTrip(trip as! Trip)
//            }
//        })
    }
    
    func unloadTrips() {
        self.setSelectedTrip(nil)
        
        for line in self.tripPolyLines.values {
            self.mapView.removeAnnotation(line)
        }
    
        
        self.tripPolyLines.removeAll(keepCapacity: false)
        self.tripsAreLoaded = false
    }
    
    func setSelectedTrip(trip : Trip!) {
        if (trip == nil) {
            return
        }
        
        if (self.tripPolyLines[trip] == nil) {
            return
        }
        
        let overlay = self.tripPolyLines[trip]! as MGLPolyline
        
        if (overlay.pointCount == 0) {
            return
        }
        
        var i = 1
        var pointCount = (Int)(overlay.pointCount)
        var coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.alloc(pointCount)
        overlay.getCoordinates(coordinates, range: NSMakeRange(0, pointCount))
        let point0 = coordinates[0]
        var minLong : Double = point0.longitude
        var maxLong : Double = point0.longitude
        var minLat : Double = point0.latitude
        var maxLat : Double = point0.latitude
        
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
        
        let padFactor : Double = 0.1
        let sizeLong = (maxLong - minLong)
        let sizeLat = (maxLat - minLat)
        
        let bounds = MGLCoordinateBoundsMake(CLLocationCoordinate2DMake(minLat - (sizeLat * padFactor), minLong - (sizeLong * padFactor)), CLLocationCoordinate2DMake(maxLat + (sizeLat * 3 * padFactor),maxLong + (sizeLong * padFactor))) // extra padding on the top so that it isn't under the notification bar.
        dispatch_async(dispatch_get_main_queue(), {
            self.mapView.setVisibleCoordinateBounds(bounds, animated: true)
        })
    }
    
    func refreshTrip(trip : Trip!) {
        dispatch_async(dispatch_get_main_queue(), {
            if (self.tripPolyLines[trip] != nil) {
                let polyline = self.tripPolyLines[trip]
                self.mapView.removeAnnotation(polyline!)
            }
            
            if (trip.deleted == true || (trip != self.mainViewController.selectedTrip && trip.activityType.shortValue != Trip.ActivityType.Cycling.rawValue)) {
                // only show a non-cycling trip if it is the selected route
                self.tripPolyLines[trip] = nil
                return
            }
            
            
            if (trip.locations == nil || trip.locations.count == 0) {
                return
            }
            
            if (trip.simplifiedLocations == nil || trip.simplifiedLocations.count == 0) {
                dispatch_async(dispatch_get_main_queue(), {
                    trip.simplify() {
                        if (trip.simplifiedLocations != nil && trip.simplifiedLocations.count > 0) {
                            self.refreshTrip(trip)
                        }
                    }
                })
                return
            }
            
            var coordinates : [CLLocationCoordinate2D] = []
            var count : UInt = 0
            for location in trip.simplifiedLocations.array {
                let location = (location as! Location)
                
                let coord = location.coordinate()
                
                if (!location.isPrivate.boolValue) {
                    coordinates.append(coord)
                    count++
                }
            }

            let polyline = MGLPolyline(coordinates: &coordinates, count: count)
            
            self.tripPolyLines[trip] = polyline
            if (coordinates.count == 0) {
                // can happen if all the points in simplifiedLocations are private
                return
            }
            
            self.mapView.addAnnotation(polyline)
            
            for annotation in self.mapView.annotations! {
                if (annotation.isKindOfClass(Incident)) {
                    let incident = annotation as! Incident
                    if (incident.fault || incident.deleted) {
                        self.mapView.removeAnnotation(incident)
                    }
                }
            }
            
            for item in trip.incidents.array {
                let incident = item as! Incident
                
                
                self.mapView.addAnnotation(incident)
            }
            
            if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
                self.setSelectedTrip(trip)
            }
        })
    }
    
    func addIncidentToMap(incident: Incident) {
        self.mapView.addAnnotation(incident)
        self.mapView.selectAnnotation(incident, animated: true)
    }

    //
    // MARK: - Map Kit
    //
    
//    func mapView(mapView: MGLMapView, didUpdateUserLocation userLocation: MGLUserLocation?) {
//        if (!self.hasCenteredMap && userLocation != nil) {
////            if (self.mainViewController.selectedTrip == nil) {
//                // don't recenter the map if the user has already selected a trip
//                
//                self.mapView.setCenterCoordinate(userLocation!.coordinate, zoomLevel: 14, animated: false)
////            }
//        
//            self.hasCenteredMap = true
//        }
//    }
    

    func mapView(mapView: MGLMapView, imageForAnnotation annotation: MGLAnnotation) -> MGLAnnotationImage? {
        if (annotation.isKindOfClass(Incident)) {
            let incident = annotation as! Incident

            let reuseID = "IncidentAnnotationViewReuseID" + incident.type.stringValue
            var annotationView = self.mapView.dequeueReusableAnnotationImageWithIdentifier(reuseID) as MGLAnnotationImage?

            if (annotationView == nil) {
                annotationView = MGLAnnotationImage(image: Incident.IncidentType(rawValue: incident.type.integerValue)!.pinImage, reuseIdentifier: reuseID)
            }
            return annotationView
        }

        return nil;
    }
    
    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        if (annotation.isKindOfClass(Incident)) {
            return true
        }
        
        return false
    }
    
    func mapView(mapView: MGLMapView, rightCalloutAccessoryViewForAnnotation annotation: MGLAnnotation) -> UIView? {
        let view = UIButton.buttonWithType(UIButtonType.DetailDisclosure) as! UIButton
        
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
    
//
//    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
//        if (newState == .Starting) {
//            view.dragState = .Dragging
//        } else if (newState == .Ending) {
//            view.dragState = .None
//            let incident = view.annotation as! Incident!
//            
//            NetworkManager.sharedManager.saveAndSyncTripIfNeeded(incident.trip!)
//        } else if (newState == .Canceling) {
//            view.dragState = .None
//        }
//    }
    func mapView(mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        var trip = ((self.tripPolyLines! as NSDictionary).allKeysForObject(annotation).first as! Trip!)
        
        if (trip != nil) {
            if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
                return 16
            } else {
                return 8
            }
        } // else if (overlay.isKindOfClass(MKCircle)) {
        //        let circleRenderer = PrivacyCircleRenderer(circle: overlay as! MKCircle)
        //        circleRenderer!.lineWidth = 1.0
        //        circleRenderer!.lineDashPattern = [3,5]
        //
        //        if (self.privacyCircle != nil && (overlay as! MKCircle) == self.privacyCircle!) {
        //            circleRenderer!.strokeColor = UIColor.redColor()
        //            circleRenderer!.fillColor = UIColor.redColor().colorWithAlphaComponent(0.3)
        //            self.privacyCircleRenderer = circleRenderer
        //        } else {
        //            circleRenderer!.strokeColor = UIColor.purpleColor()
        //            circleRenderer!.fillColor = UIColor.purpleColor().colorWithAlphaComponent(0.3)
        //        }
        //
        //    }
        return 0
    }
    
    func mapView(mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        var trip = ((self.tripPolyLines! as NSDictionary).allKeysForObject(annotation).first as! Trip!)
        
        if (trip != nil) {
            if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
                return 0.8
            } else {
                return 0.2
            }
        } // else if (overlay.isKindOfClass(MKCircle)) {
        //        let circleRenderer = PrivacyCircleRenderer(circle: overlay as! MKCircle)
        //        circleRenderer!.lineWidth = 1.0
        //        circleRenderer!.lineDashPattern = [3,5]
        //
        //        if (self.privacyCircle != nil && (overlay as! MKCircle) == self.privacyCircle!) {
        //            circleRenderer!.strokeColor = UIColor.redColor()
        //            circleRenderer!.fillColor = UIColor.redColor().colorWithAlphaComponent(0.3)
        //            self.privacyCircleRenderer = circleRenderer
        //        } else {
        //            circleRenderer!.strokeColor = UIColor.purpleColor()
        //            circleRenderer!.fillColor = UIColor.purpleColor().colorWithAlphaComponent(0.3)
        //        }
        //
        //    }
        return 0
    }
    
    func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        var trip = ((self.tripPolyLines! as NSDictionary).allKeysForObject(annotation).first as! Trip!)

        if (trip != nil) {
            if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
                    return UIColor.greenColor()
                } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
                    return UIColor.redColor()
                } else {
                    return UIColor.yellowColor()
                }
            }
            
            return UIColor.brownColor()
        } // else if (overlay.isKindOfClass(MKCircle)) {
        //        let circleRenderer = PrivacyCircleRenderer(circle: overlay as! MKCircle)
        //        circleRenderer!.lineWidth = 1.0
        //        circleRenderer!.lineDashPattern = [3,5]
        //
        //        if (self.privacyCircle != nil && (overlay as! MKCircle) == self.privacyCircle!) {
        //            circleRenderer!.strokeColor = UIColor.redColor()
        //            circleRenderer!.fillColor = UIColor.redColor().colorWithAlphaComponent(0.3)
        //            self.privacyCircleRenderer = circleRenderer
        //        } else {
        //            circleRenderer!.strokeColor = UIColor.purpleColor()
        //            circleRenderer!.fillColor = UIColor.purpleColor().colorWithAlphaComponent(0.3)
        //        }
        //
        //    }
        return UIColor.clearColor()
    }
}