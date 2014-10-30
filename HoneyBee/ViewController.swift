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
    @IBOutlet var mapView: MKMapView!
    @IBOutlet weak var logView: UIView!
    
    private var geofenceCircle : MKCircle!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        
        NSNotificationCenter.defaultCenter().addObserverForName("RouteMachineDidUpdateGeofence", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.updateGeofenceUI()
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName("RouteMachineDidUpdatePoints", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.updatePointsUI()
        }
        
        self.updatePointsUI()
        
        UIForLumberjack.sharedInstance().showLogInView(self.logView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Update Map UI
    func updatePointsUI() {
        for trip in Trip.allTrips()! {
            var coordinates : [CLLocationCoordinate2D] = []
            var count : Int = 0
            for location in trip.locations! {
                coordinates += [(location as Location).coordinate()]
                count++
            }
            
            let polyline = MKPolyline(coordinates: &coordinates, count: count)
            self.mapView.addOverlay(polyline)
        }
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
        let mapRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, span: MKCoordinateSpanMake(0.005, 0.005));
        
        mapView.setRegion(mapRegion, animated: false)
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

