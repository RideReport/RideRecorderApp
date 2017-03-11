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
    @IBInspectable var showStressMap : Bool = false
    
    private var tripsAreLoaded = false
    
    private let tripFeatureSourceIdentifier = "trip-polyline"
    
    private var selectedTripLineFeature : MGLPolylineFeature?
    private var selectedTripLineSource : MGLShapeSource!
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    
    var padFactorX : Double = 0.1
    var padFactorTop : Double = 0.1
    var padFactorBottom : Double = 0.1
    
    
    private var hasCenteredMap : Bool = false
    
    private var needsTripLoad : Bool = false
    
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

        let styleURL = showStressMap ? NSURL(string: "https://tiles.ride.report/styles/v8/heatmap-style.json") : NSURL(string: "mapbox://styles/quicklywilliam/cire41sgs0001ghme6posegq0")
        self.mapView.styleURL = styleURL
        
        self.mapView.tintColor = ColorPallete.sharedPallete.transitBlue
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = NSURLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        NSURLCache.setSharedURLCache(urlCache)
    }
    
    func mapView(mapView: MGLMapView, didFinishLoadingStyle style: MGLStyle) {
        if (self.selectedTripLineSource == nil) {
            self.selectedTripLineSource = MGLShapeSource(identifier: tripFeatureSourceIdentifier, shape: nil, options: nil)
            self.mapView.style?.addSource(self.selectedTripLineSource)
            
            let tripBackinglayer = MGLLineStyleLayer(identifier: "trip-backing", source: self.selectedTripLineSource!)
            tripBackinglayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            tripBackinglayer.lineWidth = MGLStyleValue(interpolationBase: 1.5, stops: [
                14: MGLStyleValue(rawValue: 2),
                18: MGLStyleValue(rawValue: 10),
                ])
            tripBackinglayer.lineOpacity = MGLStyleValue(rawValue: 1.0)
            tripBackinglayer.lineCap = MGLStyleValue(rawValue: MGLLineCap.Round.rawValue)
            tripBackinglayer.lineJoin = MGLStyleValue(rawValue: MGLLineJoin.Round.rawValue)
            tripBackinglayer.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.darkGrey)
            mapView.style?.addLayer(tripBackinglayer)
            
            let goodBikelayer = MGLLineStyleLayer(identifier: "good-bike", source: self.selectedTripLineSource!)
            goodBikelayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            goodBikelayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.Cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.Good.numberValue)])
            goodBikelayer.lineCap = tripBackinglayer.lineCap
            goodBikelayer.lineJoin = tripBackinglayer.lineJoin
            goodBikelayer.lineWidth = MGLStyleValue(interpolationBase: 1.5, stops: [
                14: MGLStyleValue(rawValue: 5),
                18: MGLStyleValue(rawValue: 20),
                ])
            tripBackinglayer.lineGapWidth = goodBikelayer.lineWidth // set the backinglayer's line gap width to the front layers' width
            goodBikelayer.lineOpacity = MGLStyleValue(rawValue: 0.9)
            goodBikelayer.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.goodGreen)
            mapView.style?.addLayer(goodBikelayer)
            
            let badBikelayer = MGLLineStyleLayer(identifier: "bad-bike", source: self.selectedTripLineSource!)
            badBikelayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            badBikelayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.Cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.Bad.numberValue)])
            badBikelayer.lineCap = tripBackinglayer.lineCap
            badBikelayer.lineJoin = tripBackinglayer.lineJoin
            badBikelayer.lineWidth = goodBikelayer.lineWidth
            badBikelayer.lineOpacity = goodBikelayer.lineOpacity
            badBikelayer.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.badRed)
            mapView.style?.addLayer(badBikelayer)
            
            let mixedBikelayerGreen = MGLLineStyleLayer(identifier: "mixed-bike-green", source: self.selectedTripLineSource!)
            mixedBikelayerGreen.sourceLayerIdentifier = tripFeatureSourceIdentifier
            mixedBikelayerGreen.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.Cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.Mixed.numberValue)])
            mixedBikelayerGreen.lineCap = tripBackinglayer.lineCap
            mixedBikelayerGreen.lineJoin = tripBackinglayer.lineJoin
            mixedBikelayerGreen.lineWidth = goodBikelayer.lineWidth
            mixedBikelayerGreen.lineOpacity = goodBikelayer.lineOpacity
            mixedBikelayerGreen.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.goodGreen)
            mapView.style?.addLayer(mixedBikelayerGreen)
            
            let mixedBikelayerRed = MGLLineStyleLayer(identifier: "mixed-bike-red", source: self.selectedTripLineSource!)
            mixedBikelayerRed.sourceLayerIdentifier = tripFeatureSourceIdentifier
            mixedBikelayerRed.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.Cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.Mixed.numberValue)])
            mixedBikelayerRed.lineCap = MGLStyleValue(rawValue: MGLLineCap.Round.rawValue)
            mixedBikelayerRed.lineJoin = MGLStyleValue(rawValue: MGLLineJoin.Round.rawValue)
            mixedBikelayerRed.lineWidth = MGLStyleValue(interpolationBase: 1.5, stops: [
                14: MGLStyleValue(rawValue: 2.5),
                18: MGLStyleValue(rawValue: 10),
                ])
            mixedBikelayerRed.lineOpacity = MGLStyleValue(rawValue: 1.0)
            mixedBikelayerRed.lineDashPattern = MGLStyleValue(rawValue:[0, 1.8])
            mixedBikelayerRed.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.badRed)
            mapView.style?.addLayer(mixedBikelayerRed)
            
            let unratedBikelayer = MGLLineStyleLayer(identifier: "unrated-bike", source: self.selectedTripLineSource!)
            unratedBikelayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            unratedBikelayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.Cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.NotSet.numberValue)])
            unratedBikelayer.lineCap = MGLStyleValue(rawValue: MGLLineCap.Round.rawValue)
            unratedBikelayer.lineJoin = tripBackinglayer.lineJoin
            unratedBikelayer.lineWidth = goodBikelayer.lineWidth
            unratedBikelayer.lineOpacity = goodBikelayer.lineOpacity
            unratedBikelayer.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.unknownGrey)
            mapView.style?.addLayer(unratedBikelayer)
            
            let buslayer = MGLLineStyleLayer(identifier: "bus-trip", source: self.selectedTripLineSource!)
            buslayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            buslayer.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.Bus.numberValue), NSPredicate(format: "%K == %@", "activityType", ActivityType.Rail.numberValue)])
            buslayer.lineCap = tripBackinglayer.lineCap
            buslayer.lineJoin = tripBackinglayer.lineJoin
            buslayer.lineWidth = goodBikelayer.lineWidth
            buslayer.lineOpacity = goodBikelayer.lineOpacity
            buslayer.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.transitBlue)
            mapView.style?.addLayer(buslayer)
            
            let otherTriplayer = MGLLineStyleLayer(identifier: "other-trip", source: self.selectedTripLineSource!)
            otherTriplayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            otherTriplayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K != %@", "activityType", ActivityType.Cycling.numberValue), NSPredicate(format: "%K != %@", "activityType", ActivityType.Bus.numberValue, NSPredicate(format: "%K != %@", "activityType", ActivityType.Rail.numberValue))])
            otherTriplayer.lineCap = tripBackinglayer.lineCap
            otherTriplayer.lineJoin = tripBackinglayer.lineJoin
            otherTriplayer.lineWidth = goodBikelayer.lineWidth
            otherTriplayer.lineOpacity = goodBikelayer.lineOpacity
            otherTriplayer.lineColor = MGLStyleValue(rawValue: ColorPallete.sharedPallete.autoBrown)
            mapView.style?.addLayer(otherTriplayer)
        }
        
        if (needsTripLoad) {
            needsTripLoad = false
            self.setSelectedTrip(_selectedTrip)
        }

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
        
        if self.selectedTripLineSource == nil {
            needsTripLoad = true
            return
        }
        
        if let startPoint = self.startPoint {
            self.mapView.removeAnnotation(startPoint)
        }
        if let endPoint = self.endPoint {
            self.mapView.removeAnnotation(endPoint)
        }
        
        guard _selectedTrip != nil else {
            self.selectedTripLineSource = nil
            
            return
        }
        
        guard let trip = _selectedTrip else {
            self.selectedTripLineSource = nil
            
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
        
        self.selectedTripLineFeature = MGLPolylineFeature(coordinates: &coordinates, count: count)
        self.selectedTripLineFeature!.attributes = ["activityType": trip.activityType.numberValue, "rating": trip.rating.choice.numberValue]
        self.selectedTripLineSource.shape = self.selectedTripLineFeature
        
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
        
        
        let sizeLong = (maxLong - minLong)
        let sizeLat = (maxLat - minLat)
        
        let bounds = MGLCoordinateBoundsMake(CLLocationCoordinate2DMake(minLat - (sizeLat * padFactorBottom), minLong - (sizeLong * padFactorX)), CLLocationCoordinate2DMake(maxLat + (sizeLat * padFactorTop),maxLong + (sizeLong * padFactorX)))
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
}
