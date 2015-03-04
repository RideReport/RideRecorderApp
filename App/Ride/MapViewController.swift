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
    private var tripAnnotations : [MKAnnotation]!
    private var incidentAnnotations : [Incident : MKAnnotation]!
    private var hasCenteredMap : Bool = false
    
    private var privacyCircle : MKCircle?
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

        let mapTapRecognizer = UITapGestureRecognizer(target: self, action: "mapTapGesture:")
        self.mapView.addGestureRecognizer(mapTapRecognizer)
        self.mapView.addGestureRecognizer(self.privacyCirclePanGesture)
        
        self.mapView.mapType = MKMapType.Satellite
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = NSURLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        NSURLCache.setSharedURLCache(urlCache)
        
        MBXMapKit.setAccessToken("pk.eyJ1IjoicXVpY2tseXdpbGxpYW0iLCJhIjoibmZ3UkZpayJ9.8gNggPy6H5dpzf4Sph4-sA")
        let tiles = MBXRasterTileOverlay(mapID: "quicklywilliam.l4imi65m")
        self.mapView.addOverlay(tiles)
        
        self.tripPolyLines = [:]
        self.incidentAnnotations = [:]
        

        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.loadTrips()
        }

        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.unloadTrips()
        }
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
        self.mainViewController = parent as MainViewController
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
            self.mapView.addOverlay(self.privacyCircle)
        }
        self.privacyCircleToolbar.hidden = false
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func mapTapGesture(sender: AnyObject) {
        if sender.numberOfTouches() > 1 {
            return
        }
        
        let point = sender.locationInView(self.mapView)
        
        let coord = self.mapView.convertPoint(point, toCoordinateFromView: self.mapView)
        let mapPoint = MKMapPointForCoordinate(coord)
        
        for (trip, polyLine) in self.tripPolyLines {
            let renderer = self.mapView.rendererForOverlay(polyLine)
            if (renderer == nil) {
                return
            }
            let polyLineRenderer = renderer as MKPolylineRenderer
            
            let pointInPolyline = polyLineRenderer.pointForMapPoint(mapPoint)
            let strokeWidth : CGFloat = 1000.0
            let path = CGPathCreateCopyByStrokingPath(polyLineRenderer.path, nil, strokeWidth, kCGLineCapRound, kCGLineJoinRound, 0.0)
            
            if (CGPathContainsPoint(path, nil, pointInPolyline, false)) {
                self.mainViewController.setSelectedTrip(trip, sender:self)
                return
            }
        }
        
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
                
                self.privacyCircle! = MKCircle(centerCoordinate: gestureCoord, radius: self.privacyCircle!.radius)
                self.privacyCircleRenderer!.coordinate = gestureCoord
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
    
    
    func loadTrips() {
        self.mainViewController.navigationItem.title = "Loading Trips…"
        
        if (self.tripsAreLoaded) {
            return
        }
        
        self.tripsAreLoaded = true
        
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            for trip in Trip.allTrips()! {
                self.refreshTrip(trip as Trip)
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                let miles = Trip.totalCycledMilesThisWeek
                var badgeString = ""
                if miles > 500 {
                    badgeString = "💩"
                } else if miles > 100 {
                    badgeString = "💗"
                } else if miles > 50 {
                    badgeString = "💖"
                } else if miles > 25 {
                    badgeString = "💜"
                } else if miles > 10 {
                    badgeString = "💙"
                } else if miles > 5 {
                    badgeString = "💚"
                } else if miles > 2 {
                    badgeString = "💛"
                } else {
                    badgeString = "❤️"
                }
                
                self.mainViewController.navigationItem.title = NSString(format: "%.0f miles  %@", Trip.totalCycledMiles, badgeString)
            })
        })
    }
    
    func unloadTrips() {
        self.setSelectedTrip(nil)
        
        for line in self.tripPolyLines.values {
            self.mapView.removeOverlay(line)
        }
        
        for annotation in self.tripAnnotations! {
            self.mapView.removeAnnotation(annotation)
        }
        
        for annotation in self.incidentAnnotations.values {
            self.mapView.removeAnnotation(annotation)
        }
        
        self.tripPolyLines.removeAll(keepCapacity: false)
        self.incidentAnnotations.removeAll(keepCapacity: false)
        self.tripAnnotations.removeAll(keepCapacity: false)
        self.tripsAreLoaded = false
    }
    
    func setSelectedTrip(trip : Trip!) {
        if (self.tripAnnotations != nil && self.tripAnnotations.count > 0) {
            let annotations = self.tripAnnotations
            dispatch_async(dispatch_get_main_queue(), {
                self.mapView.removeAnnotations(annotations)
            })
        }
        self.tripAnnotations = []
        
        if (trip == nil) {
            return
        }
        
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        
        for location in trip.simplifiedLocations.array {
            let location = (location as Location)
            if (location.isPrivate.boolValue) {
                continue
            }
            
            let coord = location.coordinate()
            count++
            let annotation = MKPointAnnotation()
            annotation.coordinate = coord
            
            if (location.isSmoothedLocation) {
                annotation.title = NSString(format: "%i**", count)
            } else {
                annotation.title = NSString(format: "%i", count)
            }
            if (location.date != nil) {
                annotation.subtitle = NSString(format: "%@, Speed: %f", self.dateFormatter.stringFromDate(location.date!), location.speed!.doubleValue)
            } else {
                annotation.subtitle = NSString(format: "Unknown, Speed: %f", location.speed!.doubleValue)
            }
            
            self.tripAnnotations.append(annotation)
            
            dispatch_async(dispatch_get_main_queue(), {
                self.mapView.addAnnotation(annotation)
            })
        }
        
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
        
        if (trip.deleted == true) {
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
            let location = (location as Location)
            
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
            let incident = item as Incident
            let annotation = MKPointAnnotation()
            annotation.coordinate = incident.location!.coordinate()
            
            annotation.title = incident.typeString
            annotation.subtitle = incident.body
            
            dispatch_async(dispatch_get_main_queue(), {
                self.mapView.addAnnotation(annotation)
            })
            
            self.incidentAnnotations[incident] = annotation
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
            // offset center to account for table view overlap
            let mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2DMake(mapView.userLocation.coordinate.latitude - 0.005, mapView.userLocation.coordinate.longitude), span: MKCoordinateSpanMake(0.028, 0.028));
            mapView.setRegion(mapRegion, animated: false)
            
            self.hasCenteredMap = true
        }
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if (annotation.isKindOfClass(MKUserLocation)) {
            return nil;
        } else if (annotation.isKindOfClass(MKPointAnnotation)) {
            if ((self.tripAnnotations! as NSArray).containsObject(annotation)) {
                let reuseID = "LocationAnnotationViewReuseID"
                var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseID)
                if (annotationView == nil) {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
                    annotationView.canShowCallout = true
                    
                    let circleRadius : CGFloat = 2.0
                    let pointView = UIView(frame: CGRectMake(0, 0, circleRadius*2.0, circleRadius*2.0))
                    pointView.backgroundColor = UIColor.blackColor()
                    pointView.alpha = 0.8;
                    pointView.layer.cornerRadius = circleRadius;
                    annotationView.addSubview(pointView)
                    annotationView.frame = pointView.frame
                    
                }
                
                annotationView.annotation = annotation
                
                return annotationView
            } else if ((self.incidentAnnotations.values.array as NSArray).containsObject(annotation)) {
                let reuseID = "IncidentAnnotationViewReuseID"
                var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseID) as MKPinAnnotationView?

                if (annotationView == nil) {
                    annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
                    annotationView!.pinColor = MKPinAnnotationColor.Red
                    annotationView!.canShowCallout = true
                }
                return annotationView
            }
        }
        
        return nil;
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay.isKindOfClass(MBXRasterTileOverlay)) {
            let renderer = MBXRasterTileRenderer(overlay: overlay)
            return renderer
        } else if (overlay.isKindOfClass(MKPolyline)) {
            let renderer = MKPolylineRenderer(polyline:(overlay as MKPolyline))
            
            var trip = ((self.tripPolyLines! as NSDictionary).allKeysForObject(overlay).first as Trip!)
            
            if (trip == nil) {
                return nil
            }
            
            var opacity : CGFloat
            var lineWidth : CGFloat
            
            if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
                opacity = 0.8
                lineWidth = 5
            } else {
                opacity = 0.3
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
                    renderer.strokeColor = UIColor.grayColor().colorWithAlphaComponent(opacity)
                }
            } else {
                renderer.strokeColor = UIColor.brownColor().colorWithAlphaComponent(opacity)
            }
            renderer.lineWidth = lineWidth
            return renderer;
        } else if (overlay.isKindOfClass(MKCircle)) {
            self.privacyCircleRenderer = PrivacyCircleRenderer(circle: overlay as MKCircle)
            self.privacyCircleRenderer!.strokeColor = UIColor.redColor()
            self.privacyCircleRenderer!.fillColor = UIColor.redColor().colorWithAlphaComponent(0.3)
            self.privacyCircleRenderer!.lineWidth = 1.0
            self.privacyCircleRenderer!.lineDashPattern = [3,5]
            
            return self.privacyCircleRenderer
        } else {
            return nil;
        }
    }
}

