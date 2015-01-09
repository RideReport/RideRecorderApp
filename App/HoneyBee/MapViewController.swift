//
//  MapViewController.swift
//  HoneyBee
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
    
    private var tripPolyLines : [Trip : MKPolyline]!
    private var tripAnnotations : [MKAnnotation]!
    private var hasCenteredMap : Bool = false
    
    private var defaultPrivacyCircleRadius = 300.0
    private var privacyCircle : MKCircle?
    private var privacyCircleRenderer : PrivacyCircleRenderer?
    private var isDraggingPrivacyCircle : Bool = false
    private var privacyCirclePanGesture : UIPanGestureRecognizer!
        
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        self.mapView.pitchEnabled = true
        self.mapView.showsBuildings = true
        
        let mapTapRecognizer = UITapGestureRecognizer(target: self, action: "mapTapGesture:")
        self.mapView.addGestureRecognizer(mapTapRecognizer)
        
        self.tripPolyLines = [:]
        
        self.privacyCirclePanGesture = UIPanGestureRecognizer(target: self, action: "respondToPrivacyCirclePanGesture:")
        self.privacyCirclePanGesture.delegate = self
        self.mapView.addGestureRecognizer(self.privacyCirclePanGesture)
        
        NSNotificationCenter.defaultCenter().addObserverForName("RouteMachineDidUpdatePoints", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            let state = UIApplication.sharedApplication().applicationState
            if (state == UIApplicationState.Background || state == UIApplicationState.Inactive) {
               return
            }
            
            let currentTrip : Trip! = RouteMachine.sharedMachine.currentTrip!
            if currentTrip == nil {
                return
            }
            self.refreshTrip(currentTrip)
            
            if (currentTrip.locations.count <= 1) {
                return
            }

            let lastLoc = currentTrip.locations.lastObject as Location
            var secondToLastLoc = currentTrip.locations[currentTrip.locations.count - 2] as Location

            let camera = MKMapCamera(lookingAtCenterCoordinate: CLLocationCoordinate2DMake(lastLoc.latitude.doubleValue, lastLoc.longitude.doubleValue), fromEyeCoordinate: CLLocationCoordinate2DMake(secondToLastLoc.latitude.doubleValue, secondToLastLoc.longitude.doubleValue), eyeAltitude: 0)
            camera.pitch = 80
            self.mapView.setCamera(camera, animated: true)
        }
    }
    
    override func didMoveToParentViewController(parent: UIViewController?) {
        self.mainViewController = parent as MainViewController
        
        for trip in Trip.allTrips()! {
            self.refreshTrip(trip as Trip)
        }
    }
    
    func enterPrivacyCircleEditor() {
        if (self.privacyCircle == nil) {
            if (PrivacyCircle.privacyCircle() == nil) {
                self.privacyCircle = MKCircle(centerCoordinate: mapView.userLocation.coordinate, radius: self.defaultPrivacyCircleRadius)
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
        
        for trip in Trip.allTrips()! {
            self.refreshTrip(trip as Trip)
        }
    }
    
    @IBAction func addIncident(sender: AnyObject) {
        DDLogWrapper.logVerbose("Add incident")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setSelectedTrip(trip : Trip!) {
        self.mapView.removeAnnotations(self.tripAnnotations)
        self.tripAnnotations = []

        if (trip == nil) {
            return
        }
        
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        
        for location in trip.locations.array {
            let location = (location as Location)
            if (location.isPrivate) {
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
                annotation.subtitle = NSString(format: "%@, Speed: %f", self.dateFormatter.stringFromDate(location.date!), location.speed.doubleValue)
            } else {
                annotation.subtitle = NSString(format: "Unknown, Speed: %f", location.speed.doubleValue)
            }
            
            self.mapView.addAnnotation(annotation)
            self.tripAnnotations.append(annotation)
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
        self.mapView.setVisibleMapRect(mapRect, animated: true)
    }
    
    // MARK: - Update Map UI
    func refreshTrip(trip : Trip!) {
        if (self.tripPolyLines[trip] != nil) {
            self.mapView.removeOverlay(self.tripPolyLines[trip])
        }

        if (trip.deleted == true) {
            self.tripPolyLines[trip] = nil
            return
        }
        
        if (trip.locations == nil || trip.locations.count == 0) {
            return
        }
        
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        for location in trip.locations.array {
            let location = (location as Location)
            if (location.isPrivate) {
                continue
            }
            
            let coord = location.coordinate()
            coordinates.append(coord)
            count++
        }
        
        let polyline = MKPolyline(coordinates: &coordinates, count: count)
        self.tripPolyLines[trip] = polyline
        self.mapView.addOverlay(polyline)
        
        if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
            self.setSelectedTrip(trip)
        }
    }
    
    // MARK: - Map Kit
    func mapView(mapView: MKMapView!, didUpdateUserLocation userLocation: MKUserLocation!) {
        if (!self.hasCenteredMap) {
            let mapRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, span: MKCoordinateSpanMake(0.005, 0.005));
            mapView.setRegion(mapRegion, animated: false)
            
            self.hasCenteredMap = true
        }
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if (annotation.isKindOfClass(MKUserLocation)) {
            return nil;
        } else if (annotation.isKindOfClass(MKPointAnnotation)) {
            let reuseID = "PointAnnotationViewReuseID"
            var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseID)
            if (annotationView == nil) {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
                annotationView.canShowCallout = true
                
                let circleRadius : CGFloat = 1.0
                let pointView = UIView(frame: CGRectMake(0, 0, circleRadius*2.0, circleRadius*2.0))
                pointView.backgroundColor = UIColor.blackColor()
                pointView.alpha = 0.1;
                pointView.layer.cornerRadius = circleRadius;
                annotationView.addSubview(pointView)
                annotationView.frame = pointView.frame
                
            }
            
            annotationView.annotation = annotation
            
            return annotationView
        }
        
        return nil;
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay.isKindOfClass(MKPolyline)) {
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
