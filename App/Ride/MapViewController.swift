//
//  MapViewController.swift
//  Ride
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
    var mainViewController: MainViewController! = nil
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var privacyCircleToolbar: UIToolbar!
    
    private var tripsAreLoaded = false
    private var tripPolyLines : [Trip : MKPolyline]!
    private var hasCenteredMap : Bool = false
    
    private var privacyCircle : MKCircle?
    private var geofenceCircles : [MKCircle] = []
    private var privacyCircleRenderer : PrivacyCircleRenderer?
    private var isDraggingPrivacyCircle : Bool = false
    private var privacyCirclePanGesture : UIPanGestureRecognizer!
        
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        
        self.privacyCirclePanGesture = UIPanGestureRecognizer(target: self, action: "respondToPrivacyCirclePanGesture:")
        self.privacyCirclePanGesture.delegate = self
        
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true

        self.mapView.addGestureRecognizer(self.privacyCirclePanGesture)
        
        self.mapView.mapType = MKMapType.Satellite
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = NSURLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        NSURLCache.setSharedURLCache(urlCache)
        
        MBXMapKit.setAccessToken("pk.eyJ1IjoicXVpY2tseXdpbGxpYW0iLCJhIjoibmZ3UkZpayJ9.8gNggPy6H5dpzf4Sph4-sA")
        let tiles = MBXRasterTileOverlay(mapID: "quicklywilliam.3939fb5f")
        self.mapView.addOverlay(tiles)
        
        self.tripPolyLines = [:]

        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.loadTrips()
        }

        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.unloadTrips()
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
        if (self.privacyCircle == nil) {
            if (PrivacyCircle.privacyCircle() == nil) {
                self.privacyCircle = MKCircle(centerCoordinate: mapView.userLocation.coordinate, radius: PrivacyCircle.defaultRadius())
            } else {
                self.privacyCircle = MKCircle(centerCoordinate: CLLocationCoordinate2DMake(PrivacyCircle.privacyCircle().latitude.doubleValue, PrivacyCircle.privacyCircle().longitude.doubleValue), radius: PrivacyCircle.privacyCircle().radius.doubleValue)
            }
            self.mapView.addOverlay(self.privacyCircle, level: MKOverlayLevel.AboveLabels)
        }
        self.privacyCircleToolbar.hidden = false
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func respondToPrivacyCirclePanGesture(sender: AnyObject) {
        if (self.privacyCircle == nil || self.privacyCircleRenderer == nil) {
            return
        }
        
        if (sender.numberOfTouches() > 1) {
            return
        }
        
        if (sender.state == UIGestureRecognizerState.Began) {
            let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
            let gestureLocation = CLLocation(latitude: gestureCoord.latitude, longitude: gestureCoord.longitude)
            
            let circleLocation = CLLocation(latitude: self.privacyCircle!.coordinate.latitude, longitude: self.privacyCircle!.coordinate.longitude)
            
            if (gestureLocation.distanceFromLocation(circleLocation) <= self.privacyCircle!.radius) {
                self.mapView.scrollEnabled = false
                self.isDraggingPrivacyCircle = true
            } else {
                self.mapView.scrollEnabled = true
                self.isDraggingPrivacyCircle = false
            }
        } else if (sender.state == UIGestureRecognizerState.Changed) {
            if (self.isDraggingPrivacyCircle) {
                let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
                
                let oldPrivacyCircle = self.privacyCircle
                self.privacyCircle! = MKCircle(centerCoordinate: gestureCoord, radius: self.privacyCircle!.radius)
                self.mapView.addOverlay(self.privacyCircle, level: MKOverlayLevel.AboveLabels)
                self.mapView.removeOverlay(oldPrivacyCircle)
            }
        } else {
            self.mapView.scrollEnabled = true
            self.isDraggingPrivacyCircle = false
        }
    }
    
    @IBAction func cancelSetPrivacyCircle(sender: AnyObject) {
        self.privacyCircleToolbar.hidden = true
        
        self.mapView.removeOverlay(self.privacyCircle)
        self.mapView.setNeedsDisplay()
        self.privacyCircle = nil
        self.privacyCircleRenderer = nil
    }
    
    @IBAction func saveSetPrivacyCircle(sender: AnyObject) {
        if (self.privacyCircle == nil || self.privacyCircleRenderer == nil) {
            return
        }
        
        PrivacyCircle.updateOrCreatePrivacyCircle(self.privacyCircle!)
        
        self.privacyCircleToolbar.hidden = true
        
        self.mapView.removeOverlay(self.privacyCircle)
        self.mapView.setNeedsDisplay()
        self.privacyCircle = nil
        self.privacyCircleRenderer = nil
        
        self.unloadTrips()
        self.loadTrips()
    }
    
    @IBAction func addIncident(sender: AnyObject) {
        DDLogWrapper.logVerbose("Add incident")
    }
    
    
    //
    // MARK: - Update Map UI
    //
    
    func refreshGeofences() {
        for oldOverlay in self.geofenceCircles {
            self.mapView.removeOverlay(oldOverlay)
        }
        
        self.geofenceCircles = []
        
        for region in RouteManager.sharedManager.geofenceSleepRegions {
            let circle = MKCircle(centerCoordinate: region.center, radius: region.radius)
            self.geofenceCircles.append(circle)
            self.mapView.addOverlay(circle, level: MKOverlayLevel.AboveLabels)
        }
    }
    
    
    func loadTrips() {
        self.mainViewController.navigationItem.title = "Loading Trips…"
        
        if (self.tripsAreLoaded) {
            return
        }
        
        self.tripsAreLoaded = true
        
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            for trip in Trip.allTrips() {
                self.refreshTrip(trip as! Trip)
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.mainViewController.navigationItem.title = String(format: "%i trips", Trip.numberOfCycledTrips)
            })
        })
    }
    
    func unloadTrips() {
        self.setSelectedTrip(nil)
        
        for line in self.tripPolyLines.values {
            self.mapView.removeOverlay(line)
        }
    
        
        for annotation in self.mapView.annotations {
            self.mapView.removeAnnotation(annotation as! MKAnnotation)
        }
        
        self.tripPolyLines.removeAll(keepCapacity: false)
        self.tripsAreLoaded = false
    }
    
    func setSelectedTrip(trip : Trip!) {
        if (trip == nil) {
            return
        }
        
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        
        if (self.tripPolyLines[trip] == nil) {
            return
        }
        
        let overlay = self.tripPolyLines[trip]! as MKPolyline
        
        if (overlay.pointCount == 0) {
            return
        }
        
        var i = 1
        let point0 = overlay.points()[0]
        var minX : Double = point0.x
        var maxX : Double = point0.x
        var minY : Double = point0.y
        var maxY : Double = point0.y
        
        while i < overlay.pointCount {
            let point = overlay.points()[i]
            if (point.x < minX) {
                minX = point.x
            } else if (point.x > maxX) {
                maxX = point.x
            }
            
            if (point.y < minY) {
                minY = point.y
            } else if (point.y > maxY) {
                maxY = point.y
            }
            i++
        }
        
        let padFactor : Double = 0.1
        let sizeX = (maxX - minX)
        let sizeY = (maxY - minY)
        
        let mapRect = MKMapRectMake(minX - (sizeX * padFactor), minY - (sizeY * padFactor), sizeX * (1 + 2*padFactor), sizeY * (1 + 2*padFactor))
        dispatch_async(dispatch_get_main_queue(), {
            self.mapView.setVisibleMapRect(mapRect, animated: true)
        })
    }
    
    func refreshTrip(trip : Trip!) {
        if (self.tripPolyLines[trip] != nil) {
            let overlay = self.tripPolyLines[trip]
            dispatch_async(dispatch_get_main_queue(), {
                self.mapView.removeOverlay(overlay)
            })
        }
        
        for item in trip.incidents {
            let incident = item as! Incident
            self.mapView.removeAnnotation(incident)
        }
        
        if (trip.deleted == true || trip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
            self.tripPolyLines[trip] = nil
            return
        }
        
        
        if (trip.locations == nil || trip.locations.count == 0) {
            return
        }

        if (trip.simplifiedLocations == nil || trip.simplifiedLocations.count == 0) {
            dispatch_async(dispatch_get_main_queue(), {
                trip.simplify() {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                        if (trip.simplifiedLocations != nil && trip.simplifiedLocations.count > 0) {
                            self.refreshTrip(trip)
                        }
                    })
                }
            })
            return
        }
        
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        for location in trip.simplifiedLocations.array {
            let location = (location as! Location)
            
            let coord = location.coordinate()
            
            if (!location.isPrivate.boolValue) {
                coordinates.append(coord)
                count++
            }
        }

        let polyline = MKPolyline(coordinates: &coordinates, count: count)
        self.tripPolyLines[trip] = polyline

        dispatch_async(dispatch_get_main_queue(), {
            self.mapView.addOverlay(polyline)
        })
        
        for item in trip.incidents.array {
            let incident = item as! Incident
            
            self.mapView.addAnnotation(incident)
        }
        
        if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
            self.setSelectedTrip(trip)
        }
    }

    //
    // MARK: - Map Kit
    //
    
    func mapView(mapView: MKMapView!, didUpdateUserLocation userLocation: MKUserLocation!) {
        if (!self.hasCenteredMap) {
            if (self.mainViewController.selectedTrip == nil) {
                // don't recenter the map if the user has already selected a trip
                
                let mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2DMake(mapView.userLocation.coordinate.latitude - 0.005, mapView.userLocation.coordinate.longitude), span: MKCoordinateSpanMake(0.028, 0.028));
                // offset center to account for table view overlap
                mapView.setRegion(mapRegion, animated: false)
            }
        
            self.hasCenteredMap = true
        }
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if (annotation.isKindOfClass(MKUserLocation)) {
            return nil;
        } else if (annotation.isKindOfClass(Incident)) {
            let incident = annotation as! Incident
            
            let reuseID = "IncidentAnnotationViewReuseID"
            var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseID) as MKAnnotationView?
            
            if (annotationView == nil) {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
                annotationView!.image = Incident.IncidentType(rawValue: incident.type.integerValue)!.pinImage
                annotationView!.draggable = true
                annotationView!.canShowCallout = true
                
                let button = UIButton.buttonWithType(UIButtonType.DetailDisclosure) as! UIButton
                annotationView!.rightCalloutAccessoryView = button
            }
            return annotationView
        }
        
        return nil;
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        let incident = view.annotation as! Incident!
        self.mainViewController.performSegueWithIdentifier("presentIncidentEditor", sender: incident)
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState != .Ending {
            return
        }
        
        var nearestLocation = self.mainViewController.selectedTrip.closestLocationToCoordinate(view!.annotation.coordinate)
        if (nearestLocation == nil) {
            nearestLocation = self.mainViewController.selectedTrip.mostRecentLocation()
        }
        if (nearestLocation == nil) {
            // should never happen
            return
        }
        
        let incident = view!.annotation as! Incident
        incident.location = nearestLocation
        NetworkManager.sharedManager.saveAndSyncTripIfNeeded(self.mainViewController.selectedTrip)
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay.isKindOfClass(MBXRasterTileOverlay)) {
            let renderer = MBXRasterTileRenderer(overlay: overlay)
            return renderer
        } else if (overlay.isKindOfClass(MKPolyline)) {
            let renderer = MKPolylineRenderer(polyline:(overlay as! MKPolyline))
            
            var trip = ((self.tripPolyLines! as NSDictionary).allKeysForObject(overlay).first as! Trip!)
            
            if (trip == nil) {
                return nil
            }
            
            var opacity : CGFloat
            var lineWidth : CGFloat
            
            if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
                opacity = 0.8
                lineWidth = 8
            } else {
                opacity = 0.2
                lineWidth = 2
            }
            
            if (trip == nil) {
                return nil;
            }
        
            if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
                    renderer.strokeColor = UIColor.greenColor().colorWithAlphaComponent(opacity)
                } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
                    renderer.strokeColor = UIColor.redColor().colorWithAlphaComponent(opacity)
                } else {
                    renderer.strokeColor = UIColor.yellowColor().colorWithAlphaComponent(opacity)
                }
            } else {
                renderer.strokeColor = UIColor.brownColor().colorWithAlphaComponent(opacity)
            }
            renderer.lineWidth = lineWidth
            return renderer;
        } else if (overlay.isKindOfClass(MKCircle)) {
            let circleRenderer = PrivacyCircleRenderer(circle: overlay as! MKCircle)
            circleRenderer!.lineWidth = 1.0
            circleRenderer!.lineDashPattern = [3,5]

            if (self.privacyCircle != nil && (overlay as! MKCircle) == self.privacyCircle!) {
                circleRenderer!.strokeColor = UIColor.redColor()
                circleRenderer!.fillColor = UIColor.redColor().colorWithAlphaComponent(0.3)
                self.privacyCircleRenderer = circleRenderer
            } else {
                circleRenderer!.strokeColor = UIColor.purpleColor()
                circleRenderer!.fillColor = UIColor.purpleColor().colorWithAlphaComponent(0.3)
            }
            
            return circleRenderer
        } else {
            return nil;
        }
    }
}

