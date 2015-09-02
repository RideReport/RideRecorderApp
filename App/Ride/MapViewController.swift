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
    var mainViewController: MainViewController! = nil
    
    @IBOutlet weak var mapView:  MGLMapView!
        
    private var tripsAreLoaded = false
    private var tripPolyLines : [Trip : MGLPolyline]!
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

        let styleURL = NSURL(string: "https://tiles.ride.report/styles/heatmap-style.json")
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
                self.runTripsMigrationIfNeeded()
            }
        } else {
            self.loadTrips()
            self.runTripsMigrationIfNeeded()
        }
    }
    
    private func runTripsMigrationIfNeeded() {
        if (!NSUserDefaults.standardUserDefaults().boolForKey("hasRunMigration2")) {
            let context = CoreDataManager.sharedManager.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest(entityName: "Trip")
            fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = NSLocale.currentLocale()
            dateFormatter.dateFormat = "MM/dd/yyyy"
            
            let date = dateFormatter.dateFromString("07/15/2015")
            fetchedRequest.predicate = NSPredicate(format: "creationDate > %@", date!)
            
            var error : NSError?
            let results = context.executeFetchRequest(fetchedRequest, error: &error)
            
            if (results != nil && results?.count > 0) {
                let actionSheet = UIActionSheet(title: "Ride Report needs to upgrade your trip database with the server. Ride Report may be unresponsive for several seconds.", delegate: nil, cancelButtonTitle:"Later", destructiveButtonTitle: nil, otherButtonTitles: "Continue")
                actionSheet.tapBlock = {(actionSheet, buttonIndex) -> Void in
                    if (buttonIndex == 1) {
                        for trip in results! {
                            (trip as! Trip).isSynced = false
                        }
                        CoreDataManager.sharedManager.saveContext()
                        APIClient.sharedClient.syncTrips()
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasRunMigration2")
                        NSUserDefaults.standardUserDefaults().synchronize()
                        
                    }
                }
                
                actionSheet.showFromToolbar(self.navigationController?.toolbar)
            } else {
                NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasRunMigration2")
                NSUserDefaults.standardUserDefaults().synchronize()
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
    
    @IBAction func addIncident(sender: AnyObject) {
        DDLogVerbose("Add incident")
    }
    
    
    //
    // MARK: - Update Map UI
    //
    
    
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
            if (trip == nil) {
                return
            }
            
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
                
                coordinates.append(coord)
                count++
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
    
    func mapView(mapView: MGLMapView, didUpdateUserLocation userLocation: MGLUserLocation?) {
        if (!self.hasCenteredMap && userLocation != nil) {
            if (self.mainViewController.selectedTrip == nil) {
                // don't recenter the map if the user has already selected a trip
                
                self.mapView.setCenterCoordinate(userLocation!.coordinate, zoomLevel: 14, animated: false)
            }
        
            self.hasCenteredMap = true
        }
    }
    

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
    
    func mapView(mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        var trip = ((self.tripPolyLines! as NSDictionary).allKeysForObject(annotation).first as! Trip!)
        
        if (trip != nil) {
            if (self.mainViewController.selectedTrip != nil && trip == self.mainViewController.selectedTrip) {
                return 16
            } else {
                return 8
            }
        }
        
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
        }
        
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
        }
        
        return UIColor.clearColor()
    }
}