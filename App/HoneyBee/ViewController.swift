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

class ViewController: UIViewController, MKMapViewDelegate, UIActionSheetDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var routeTitle: UIBarButtonItem!
    
    private var tripPolyLines : [Trip : MKPolyline]!
    private var tripAnnotations : [MKAnnotation]!
    private var hasCenteredMap : Bool = false
    private var selectedTrip : Trip!
    
    private var logsShowing : Bool = false
    
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        
        self.tripPolyLines = [:]
        
        NSNotificationCenter.defaultCenter().addObserverForName("RouteMachineDidUpdatePoints", object: nil, queue: nil) { (notification : NSNotification!) -> Void in
            self.refreshTrip(RouteMachine.sharedMachine.currentTrip)
        }
        
        for trip in Trip.allTrips()! {
            self.refreshTrip(trip as Trip)
        }
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
        
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: nil, destructiveButtonTitle: nil, otherButtonTitles: "Query Core Motion Acitivities", smoothButtonTitle, "Simulate Ride End")
        actionSheet.showFromToolbar(self.navigationController?.toolbar)
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == 0) {
            self.selectedTrip.clasifyActivityType({
                self.refreshTrip(self.selectedTrip)
            })
        } else if (buttonIndex == 1) {
            if (self.selectedTrip.hasSmoothed) {
                self.selectedTrip.undoSmoothWithCompletionHandler({
                    self.refreshTrip(self.selectedTrip)
                })
            } else {
                self.selectedTrip.smoothIfNeeded({
                    self.refreshTrip(self.selectedTrip)
                })
            }
        } else if (buttonIndex == 2) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                self.selectedTrip.sendTripCompletionNotification()
            })
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
        
        self.refreshTrip(trip)
        self.refreshSelectedTrip(trip)
    }
    
    func refreshSelectedTrip(trip : Trip!) {
        var title = ""
        if (trip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
            title = "Drove"
        } else if (trip.activityType.shortValue == Trip.ActivityType.Walking.rawValue) {
            title = "Walked"
        } else if (trip.activityType.shortValue == Trip.ActivityType.Running.rawValue) {
            title = "Ran"
        } else if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
            title = "Biked"
        } else {
            title = "Traveled"
        }
        if (trip.startDate != nil) {
            title = NSString(format: "%@ for %i minutes",title, Int(trip.duration())/60)
        } else {
            title = title + "for a while"
        }
        self.routeTitle.title = title

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
        
        if (trip.locations.count == 0) {
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
            annotationView.canShowCallout = true
            
            let circleRadius : CGFloat = 1.0
            let pointView = UIView(frame: CGRectMake(0, 0, circleRadius*2.0, circleRadius*2.0))
            pointView.backgroundColor = UIColor.blackColor()
            pointView.tag = textLabelTag
            pointView.alpha = 0.3;
            pointView.layer.cornerRadius = circleRadius;
            annotationView.addSubview(pointView)
            annotationView.frame = pointView.frame
        }
        annotationView.annotation = annotation
        
        return annotationView
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay.isKindOfClass(MKPolyline)) {
            let view = MKPolylineRenderer(polyline:(overlay as MKPolyline))
            
            let trip = ((self.tripPolyLines! as NSDictionary).allKeysForObject(overlay).first as Trip!)
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
        
            if (trip.activityType.shortValue == Trip.ActivityType.Walking.rawValue) {
                view.strokeColor = UIColor.yellowColor().colorWithAlphaComponent(opacity)
            } else if (trip.activityType.shortValue == Trip.ActivityType.Running.rawValue) {
                view.strokeColor = UIColor.orangeColor().colorWithAlphaComponent(opacity)
            } else if (trip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) {
                view.strokeColor = UIColor.greenColor().colorWithAlphaComponent(opacity)
            } else if (trip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue) {
                view.strokeColor = UIColor.redColor().colorWithAlphaComponent(opacity)
            } else {
                // unknown
                view.strokeColor = UIColor.grayColor().colorWithAlphaComponent(opacity)
            }
            view.lineWidth = lineWidth
            return view;
        } else {
            return nil;
        }
    }
}

