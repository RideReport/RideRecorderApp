//
//  ViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class ViewController: UIViewController, MKMapViewDelegate, UIActionSheetDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    private var tripPolyLines : [Trip : MKPolyline]!
    private var tripAnnotations : [MKAnnotation]!
    private var hasCenteredMap : Bool = false
    private var selectedTrip : Trip!
    
    private var privacyCircleRadius = 300.0
    private var privacyCircle : MKCircle!
    private var privacyCircleRenderer : PrivacyCircleRenderer!
    private var isDraggingPrivacyCircle : Bool = false
    private var privacyCirclePanGesture : UIPanGestureRecognizer!
    
    private var logsShowing : Bool = false
    
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        let routesController = (self.storyboard!.instantiateViewControllerWithIdentifier("RoutesViewController") as RoutesViewController)
        routesController.mapViewController = self
        routesController.title = "Rides"
        
        self.navigationController?.viewControllers = [routesController, self]
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        
        self.tripPolyLines = [:]
        
        self.privacyCirclePanGesture = UIPanGestureRecognizer(target: self, action: "respondToPrivacyCirclePanGesture:")
        self.privacyCirclePanGesture.delegate = self
        self.mapView.addGestureRecognizer(self.privacyCirclePanGesture)
        
        NSNotificationCenter.defaultCenter().addObserverForName("RouteMachineDidUpdatePoints", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.setSelectedTrip(RouteMachine.sharedMachine.currentTrip)
        }
        
        for trip in Trip.allTrips()! {
            self.refreshTrip(trip as Trip)
        }
        
        self.setSelectedTrip(Trip.mostRecentTrip())
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func respondToPrivacyCirclePanGesture(sender: AnyObject) {
        if (self.privacyCircle == nil) {
            return
        }
        
        if (sender.state == UIGestureRecognizerState.Began) {
            let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
            let gestureLocation = CLLocation(latitude: gestureCoord.latitude, longitude: gestureCoord.longitude)
            
            let circleLocation = CLLocation(latitude: self.privacyCircle.coordinate.latitude, longitude: self.privacyCircle.coordinate.longitude)
            
            if (gestureLocation.distanceFromLocation(circleLocation) <= self.privacyCircle.radius) {
                self.mapView.scrollEnabled = false
                self.isDraggingPrivacyCircle = true
            } else {
                self.mapView.scrollEnabled = true
                self.isDraggingPrivacyCircle = false
            }
        } else if (sender.state == UIGestureRecognizerState.Changed) {
            if (self.isDraggingPrivacyCircle) {
                let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
                
                self.privacyCircle = MKCircle(centerCoordinate: gestureCoord, radius: self.privacyCircleRadius)
                self.privacyCircleRenderer.coordinate = gestureCoord
            }
        } else {
            self.mapView.scrollEnabled = true
            self.isDraggingPrivacyCircle = false
        }
    }
    
    @IBAction func addIncident(sender: AnyObject) {
        DDLogWrapper.logVerbose("Add incident")
    }
    
    @IBAction func rateBad(sender: AnyObject) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Bad.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.refreshTrip(self.selectedTrip)
    }
    
    @IBAction func rateGood(sender: AnyObject) {
        self.selectedTrip.rating = NSNumber(short: Trip.Rating.Good.rawValue)
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.refreshTrip(self.selectedTrip)
    }
    
    @IBAction func tools(sender: AnyObject) {
        if (self.selectedTrip == nil) {
            return;
        }
        
        var smoothButtonTitle = ""
        if (self.selectedTrip.hasSmoothed) {
            smoothButtonTitle = "Unsmooth"
        } else {
            smoothButtonTitle = "Smooth"
        }
        
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle:"Dismiss", destructiveButtonTitle: nil, otherButtonTitles: "Query Core Motion Acitivities", smoothButtonTitle, "Simulate Ride End", "Mark as Bike Ride", "Close Trip", "Send to Server")
        actionSheet.showFromToolbar(self.navigationController?.toolbar)
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            self.selectedTrip.clasifyActivityType({
                self.refreshTrip(self.selectedTrip)
            })
        } else if (buttonIndex == 2) {
            if (self.selectedTrip.hasSmoothed) {
                self.selectedTrip.undoSmoothWithCompletionHandler({
                    self.refreshTrip(self.selectedTrip)
                })
            } else {
                self.selectedTrip.smoothIfNeeded({
                    self.refreshTrip(self.selectedTrip)
                })
            }
        } else if (buttonIndex == 3) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                self.selectedTrip.sendTripCompletionNotification()
            })
        } else if (buttonIndex == 4) {
            self.selectedTrip.activityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            CoreDataController.sharedCoreDataController.saveContext()
            
            self.refreshTrip(self.selectedTrip)
        } else if (buttonIndex == 5) {
            self.selectedTrip.closeTrip()
            
            self.refreshTrip(self.selectedTrip)
        } else if (buttonIndex == 6) {
            self.selectedTrip.syncToServer()
        } else {
            //
        }
    }
    
    @IBAction func logs(sender: AnyObject) {
        if (self.logsShowing) {
            UIForLumberjack.sharedInstance().showLogInView(self.view)
        } else {
            UIForLumberjack.sharedInstance().hideLog()
        }
        
        self.logsShowing = !self.logsShowing
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setSelectedTrip(trip : Trip!) {
        let oldTrip = self.selectedTrip
        
        self.selectedTrip = trip
        
        if (oldTrip != nil) {
            self.refreshTrip(oldTrip)
        }
        
        if (trip != nil) {
            self.refreshTrip(trip)
        }
        
        self.refreshSelectedTrip(trip)
    }
    
    func refreshSelectedTrip(trip : Trip!) {
        var title = ""
        if (trip != nil) {
            if (trip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
                title = "🚗"
            } else if (trip.activityType.shortValue == Trip.ActivityType.Walking.rawValue) {
                title = "🚶"
            } else if (trip.activityType.shortValue == Trip.ActivityType.Running.rawValue) {
                title = "🏃"
            } else if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                title = "🚲"
            } else {
                title = "Traveled"
            }
            title = NSString(format: "%@ %.1f miles",title, trip.lengthMiles)
        }

        self.title = title

        if (trip == nil) {
            return
        } else {
            self.mapView.removeAnnotations(self.tripAnnotations)
        }
        
        self.tripAnnotations = []
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        
        for location in trip.locations.array {
            let location = (location as Location)
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
                annotation.subtitle = NSString(format: "%@, Speed: %f", self.dateFormatter.stringFromDate(location.date), location.speed.doubleValue)
            } else {
                annotation.subtitle = NSString(format: "Unknown, Speed: %f", location.speed.doubleValue)
            }
            
            self.mapView.addAnnotation(annotation)
            self.tripAnnotations.append(annotation)
        }
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
            let coord = location.coordinate()
            coordinates.append(coord)
            count++
        }
        
        let polyline = MKPolyline(coordinates: &coordinates, count: count)
        self.tripPolyLines[trip] = polyline
        self.mapView.addOverlay(polyline)
        
        if (self.selectedTrip != nil && trip == self.selectedTrip) {
            self.refreshSelectedTrip(trip)
        }
    }
    
    // MARK: - Map Kit
    func mapView(mapView: MKMapView!, didUpdateUserLocation userLocation: MKUserLocation!) {
        if (!self.hasCenteredMap) {
            let mapRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, span: MKCoordinateSpanMake(0.005, 0.005));
            mapView.setRegion(mapRegion, animated: false)
            
            self.hasCenteredMap = true
        }
        
        if (self.privacyCircle == nil) {
            self.privacyCircle = MKCircle(centerCoordinate: mapView.userLocation.coordinate, radius: self.privacyCircleRadius)
            self.mapView.addOverlay(self.privacyCircle)
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
            
            if (self.selectedTrip.rating.shortValue == Trip.Rating.Bad.rawValue) {
                let button = UIButton(frame: CGRectMake(0, 0, 60, 20))
                button.setTitle("Incident", forState: UIControlState.Normal)
                button.titleLabel?.font = UIFont.systemFontOfSize(12)
                button.backgroundColor = UIColor.redColor()
                button.addTarget(self, action:"addIncident:", forControlEvents:UIControlEvents.TouchUpInside)
                annotationView.rightCalloutAccessoryView = button
            } else {
                annotationView.rightCalloutAccessoryView = nil
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
            
            if (self.selectedTrip != nil && trip == self.selectedTrip) {
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
                    renderer.strokeColor = UIColor(red: 204.0/255.0, green: 1.0, blue: 51.0/255.0, alpha: opacity)
                }
            } else {
                // unknown
                renderer.strokeColor = UIColor.grayColor().colorWithAlphaComponent(opacity)
            }
            renderer.lineWidth = lineWidth
            return renderer;
        } else if (overlay.isKindOfClass(MKCircle)) {
            self.privacyCircleRenderer = PrivacyCircleRenderer(circle: overlay as MKCircle)
            self.privacyCircleRenderer.strokeColor = UIColor.redColor()
            self.privacyCircleRenderer.lineWidth = 3.0
            
            return self.privacyCircleRenderer
        } else {
            return nil;
        }
    }
}

