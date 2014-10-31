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
    
    private var geofenceCircle : MKCircle!
    private var tripPolyLines : [MKPolyline]!
    private var tripAnnotations : [MKAnnotation]!
    private var hasCenteredMap : Bool = false
    private var selectedTrip : Trip!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        }        
    }
    
    @IBAction func smoothUnSmooth(sender: AnyObject) {
        self.smoothUnsmoothButton.setTitle("....", forState: UIControlState.Normal)
        if (self.selectedTrip.hasSmoothed) {
            self.selectedTrip.undoSmoothWithCompletionHandler({
                self.setSelectedTrip(self.selectedTrip)
            })
        } else {
            self.selectedTrip.smoothIfNeededWithCompletionHandler({
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
    func setSelectedTrip(trip : Trip) {
        self.selectedTrip = trip
        
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
            let coord = (location as Location).coordinate()
            coordinates.append(coord)
            count++
            let annotation = MKPointAnnotation()
            annotation.coordinate = coord
            
            if ((location as Location).isSmoothedLocation) {
                annotation.title = NSString(format: "%i**", count)
            } else {
                annotation.title = NSString(format: "%i", count)
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
            let textLabel = UILabel(frame: CGRectMake(0, 0, 60, 25))
            textLabel.backgroundColor = UIColor.clearColor()
            textLabel.tag = textLabelTag
            
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
        
            view.strokeColor = UIColor.redColor()
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

