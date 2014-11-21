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

class ViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var smoothUnsmoothButton: UIButton!
    @IBOutlet weak var queryCMButton: UIButton!
    
    private var geofenceCircle : MKCircle!
    private var tripPolyLines : [MKPolyline]!
    private var tripAnnotations : [MKAnnotation]!
    private var hasCenteredMap : Bool = false
    private var selectedTrip : Trip!
    
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        
        NSNotificationCenter.defaultCenter().addObserverForName("RouteMachineDidUpdateGeofence", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.updateGeofenceUI()
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName("RouteMachineDidUpdatePoints", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.setSelectedTrip(RouteMachine.sharedMachine.currentTrip)
        }
        
        if (Trip.allTrips()?.count > 0) {
            self.setSelectedTrip(Trip.allTrips()!.first as Trip)
        } else {
            self.setSelectedTrip(nil)
        }
    }
    
    @IBAction func queryCM(sender: AnyObject) {
        self.queryCMButton.setTitle("....", forState: UIControlState.Normal)

        self.selectedTrip.clasifyActivityType({
            self.setSelectedTrip(self.selectedTrip)
        })
    }
    
    @IBAction func smoothUnSmooth(sender: AnyObject) {
        self.smoothUnsmoothButton.setTitle("....", forState: UIControlState.Normal)
        if (self.selectedTrip.hasSmoothed) {
            self.selectedTrip.undoSmoothWithCompletionHandler({
                self.setSelectedTrip(self.selectedTrip)
            })
        } else {
            self.selectedTrip.smoothIfNeeded({
                self.setSelectedTrip(self.selectedTrip)
            })
        }
    }
    
    @IBAction func logs(sender: AnyObject) {
        UIForLumberjack.sharedInstance().showLogInView(self.view)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Update Map UI
    func setSelectedTrip(trip : Trip!) {
        self.selectedTrip = trip
        
        if (trip == nil) {
            self.queryCMButton.hidden = true
            self.smoothUnsmoothButton.hidden = true
            return
        } else {
            self.queryCMButton.hidden = false
            self.queryCMButton.setTitle("Query CM", forState: UIControlState.Normal)
            
            self.smoothUnsmoothButton.hidden = false
        }
        
        if (trip.hasSmoothed) {
            self.smoothUnsmoothButton.setTitle("Unsmooth", forState: UIControlState.Normal)
        } else {
            self.smoothUnsmoothButton.setTitle("Smooth", forState: UIControlState.Normal)
        }
        
        if (self.tripPolyLines != nil) {
            self.mapView.removeAnnotations(self.tripAnnotations)
            self.mapView.removeOverlays(self.tripPolyLines)
        }
        
        self.tripPolyLines = []
        self.tripAnnotations = []
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        for location in trip.locations.array {
            let location = (location as Location)
            let coord = location.coordinate()
            coordinates.append(coord)
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
        
        let polyline = MKPolyline(coordinates: &coordinates, count: count)
        self.mapView.addOverlay(polyline)
        self.tripPolyLines.append(polyline)        
    }
    
    func updateGeofenceUI() {
        if (RouteMachine.sharedMachine.geofenceSleepRegion == nil) {
            return;
        }
        
        RouteMachine.sharedMachine.geofenceSleepRegion
        let geofenceRegion : CLCircularRegion = RouteMachine.sharedMachine.geofenceSleepRegion!
        
        if (self.geofenceCircle != nil) {
            self.mapView.removeOverlay(self.geofenceCircle!)
        }
        
        self.geofenceCircle = MKCircle(centerCoordinate: geofenceRegion.center, radius: geofenceRegion.radius)
        self.mapView.addOverlay(self.geofenceCircle!)
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
        }
        let reuseID = "ViewControllerMapReuseID"
        let textLabelTag = 59
        var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseID)
        if (annotationView == nil) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            let textLabel = UILabel(frame: CGRectMake(7.5, 0, 15, 5))
            textLabel.backgroundColor = UIColor.clearColor()
            textLabel.tag = textLabelTag
            textLabel.font = UIFont.systemFontOfSize(6)
            
            annotationView.addSubview(textLabel)
            annotationView.canShowCallout = true
            annotationView.frame = textLabel.frame
        }
        annotationView.annotation = annotation
        let textLabel = annotationView.viewWithTag(textLabelTag) as UILabel
        textLabel.text = annotation.title
        
        return annotationView
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay.isKindOfClass(MKPolyline)) {
            let view = MKPolylineRenderer(polyline:(overlay as MKPolyline))
        
            if (self.selectedTrip.activityType.shortValue == Trip.ActivityType.Walking.rawValue) {
                view.strokeColor = UIColor.yellowColor()
            } else if (self.selectedTrip.activityType.shortValue == Trip.ActivityType.Running.rawValue) {
                view.strokeColor = UIColor.orangeColor()
            } else if (self.selectedTrip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                view.strokeColor = UIColor.greenColor()
            } else if (self.selectedTrip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
                view.strokeColor = UIColor.redColor()
            } else {
                // unknown
                view.strokeColor = UIColor.grayColor()
            }
            view.lineWidth = 4
            return view;
        } else if (overlay.isKindOfClass(MKCircle)) {
            let view = MKCircleRenderer(circle: overlay as MKCircle)
            
            view.fillColor = UIColor.greenColor().colorWithAlphaComponent(0.3)
            view.strokeColor = UIColor.greenColor()
            view.lineWidth = 4
            return view;
        } else {
            return nil;
        }
    }
}

