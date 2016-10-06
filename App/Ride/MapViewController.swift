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
    @IBOutlet weak var mapView:  MGLMapView!
        
    private var tripsAreLoaded = false
    
    private var selectedTripLine : MGLPolyline?
    private var selectedTripBackingLine : MGLPolyline?
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    
    private var hasCenteredMap : Bool = false
    
    private var _selectedTrip : Trip? = nil
        
    private var dateFormatter : NSDateFormatter!
    
    private var tempBackgroundView : UIView?
    private var hasInsertedTempBackgroundView = false
    
    override func viewDidLoad() {
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM/dd"
        
        
        self.mapView.delegate = self
        self.mapView.logoView.hidden = true
        self.mapView.attributionButton.hidden = true
        self.mapView.rotateEnabled = false
        self.mapView.backgroundColor = UIColor(red: 249/255, green: 255/255, blue: 247/255, alpha: 1.0)

        let styleURL = NSURL(string: "https://tiles.ride.report/styles/v8/heatmap-style.json")
        self.mapView.styleURL = styleURL
        
        self.mapView.tintColor = ColorPallete.sharedPallete.transitBlue
        
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = NSURLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        NSURLCache.setSharedURLCache(urlCache)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //
    // MARK: - UIViewController
    //
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !hasInsertedTempBackgroundView {
            self.hasInsertedTempBackgroundView = true
            self.tempBackgroundView = UIView(frame: self.view.bounds)
            self.tempBackgroundView!.backgroundColor = self.view.backgroundColor
            self.mapView.insertSubview(self.tempBackgroundView!, atIndex: 0)
            self.mapView.bringSubviewToFront(self.tempBackgroundView!)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.delay(0.2) { () -> Void in
            if let view = self.tempBackgroundView {
                view.fadeOut({ () -> Void in
                    view.removeFromSuperview()
                    self.tempBackgroundView = nil                    
                })
            }
        }
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
    
    func setSelectedTrip(selectedTrip : Trip?) {
        _selectedTrip = selectedTrip
        
        if let tripBackingLine = self.selectedTripLine {
            self.mapView.removeAnnotation(tripBackingLine)
        }
        if let tripLine = self.selectedTripBackingLine {
            self.mapView.removeAnnotation(tripLine)
        }
        if let startPoint = self.startPoint {
            self.mapView.removeAnnotation(startPoint)
        }
        if let endPoint = self.endPoint {
            self.mapView.removeAnnotation(endPoint)
        }
        
        guard _selectedTrip != nil else {
            self.selectedTripLine = nil
            self.selectedTripBackingLine = nil
            
            return
        }
        
        guard let trip = _selectedTrip else {
            self.selectedTripLine = nil
            self.selectedTripBackingLine = nil
            
            return
        }
        
        var locs = trip.locations
        
        // if the trip is closed, use the simplified locations for efficiency
        if trip.isClosed {
            guard trip.simplifiedLocations != nil && trip.simplifiedLocations.count > 0 else {
                dispatch_async(dispatch_get_main_queue(), { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    trip.simplify() {
                        if (trip.simplifiedLocations != nil && trip.simplifiedLocations.count > 0) {
                            strongSelf.setSelectedTrip(trip)
                        }
                    }
                    })
                return
            }
            
            locs = trip.simplifiedLocations
        }
        
        if let startLoc = locs.firstObject as? Location,
            endLoc = locs.lastObject as? Location {
                self.startPoint = MGLPointAnnotation()
                self.startPoint!.coordinate = startLoc.coordinate()
                mapView.addAnnotation(self.startPoint!)
                
                self.endPoint = MGLPointAnnotation()
                self.endPoint!.coordinate = endLoc.coordinate()
                mapView.addAnnotation(self.endPoint!)
        }

        var coordinates : [CLLocationCoordinate2D] = []
        var count : UInt = 0
        for location in locs.array {
            let location = (location as! Location)
            
            let coord = location.coordinate()
            
            coordinates.append(coord)
            count += 1
        }
        
        guard coordinates.count > 0 else {
            return
        }
        
        self.selectedTripLine = MGLPolyline(coordinates: &coordinates, count: count)
        self.selectedTripBackingLine = MGLPolyline(coordinates: &coordinates, count: count)

        self.mapView.addOverlay(self.selectedTripBackingLine!)
        self.mapView.addOverlay(self.selectedTripLine!)
        
        let point0 = coordinates[0]
        var minLong : Double = point0.longitude
        var maxLong : Double = point0.longitude
        var minLat : Double = point0.latitude
        var maxLat : Double = point0.latitude
        
        var i = 1
        let pointCount = (Int)(count)

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
            i += 1
        }
        
        let padFactorX : Double = 0.1
        let padFactorTop : Double = 0.2
        let padFactorBottom : Double = 0.5
        
        let sizeLong = (maxLong - minLong)
        let sizeLat = (maxLat - minLat)
        
        let bounds = MGLCoordinateBoundsMake(CLLocationCoordinate2DMake(minLat - (sizeLat * padFactorBottom), minLong - (sizeLong * padFactorX)), CLLocationCoordinate2DMake(maxLat + (sizeLat * padFactorTop),maxLong + (sizeLong * padFactorX))) // extra padding on the top so that it isn't under the notification bar.
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.mapView.setVisibleCoordinateBounds(bounds, animated: true)
        })
    }
    
    //
    // MARK: - Map Kit
    //
    
    func mapView(mapView: MGLMapView, imageForAnnotation annotation: MGLAnnotation) -> MGLAnnotationImage? {
        var annotationImage: MGLAnnotationImage? = nil
        if let startPoint = self.startPoint, pointAnnotation = annotation as? MGLPointAnnotation where pointAnnotation == startPoint {
            annotationImage = mapView.dequeueReusableAnnotationImageWithIdentifier("startMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinGreen.png")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "startMarker")
            }
        } else if let endPoint = self.endPoint, pointAnnotation = annotation as? MGLPointAnnotation where pointAnnotation == endPoint {
            annotationImage = mapView.dequeueReusableAnnotationImageWithIdentifier("endMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinRed.png")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "endMarker")
            }
        }
        
        return annotationImage
    }
    
    func mapView(mapView: MGLMapView, didUpdateUserLocation userLocation: MGLUserLocation?) {
        if (!self.hasCenteredMap && userLocation != nil) {
            if _selectedTrip == nil {
                self.mapView.setCenterCoordinate(userLocation!.coordinate, zoomLevel: 14, animated: false)
            }
        
            self.hasCenteredMap = true
        }
    }
    
    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        if (annotation.isKindOfClass(Incident)) {
            return true
        }
        
        return false
    }
    
    func mapView(mapView: MGLMapView, rightCalloutAccessoryViewForAnnotation annotation: MGLAnnotation) -> UIView? {
        let view = UIButton(type: UIButtonType.DetailDisclosure)
        
        return view
    }
    
    func mapView(mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        if (annotation == self.selectedTripBackingLine) {
            return 14
        } else if (annotation == self.selectedTripLine) {
            return 8
        }

        return 0
    }
    
    func mapView(mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        if (annotation == self.selectedTripBackingLine) {
            return 1.0
        } else if (annotation == self.selectedTripLine) {
            return 1.0
        }
        
        return 0
    }
    
    func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        if (annotation == self.selectedTripBackingLine) {
            return UIColor(red: 115/255, green: 123/255, blue: 102/255, alpha: 1.0)
        }
        
        if let trip = _selectedTrip {
            if (trip.activityType == .Cycling) {
                if(trip.rating.shortValue == Trip.Rating.Good.rawValue) {
                    return ColorPallete.sharedPallete.goodGreen
                } else if(trip.rating.shortValue == Trip.Rating.Bad.rawValue) {
                    return ColorPallete.sharedPallete.badRed
                } else {
                    return ColorPallete.sharedPallete.unknownGrey
                }
            } else if (trip.activityType == .Bus) {
                return ColorPallete.sharedPallete.transitBlue
            }
            
            return ColorPallete.sharedPallete.autoBrown
        }
        
        return UIColor.clearColor()
    }
}
