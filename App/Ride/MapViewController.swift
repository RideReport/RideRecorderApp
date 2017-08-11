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
#if DEBUG
    import CoreMotion
#endif

class MapViewController: UIViewController, MGLMapViewDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var mapView:  MGLMapView!
    @IBInspectable var showStressMap : Bool = false
    
    private var tripsAreLoaded = false
    
    private let tripFeatureSourceIdentifier = "trip-polyline"
    
    private var selectedTripLineFeature : MGLPolylineFeature?
    private var selectedTripLineSource : MGLShapeSource!
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    
    var insets = UIEdgeInsetsMake(50, 20, 20, 20)
    
    private var hasCenteredMap : Bool = false
    
    private var needsTripLoad : Bool = false
    
    private var _selectedTrip : Trip? = nil
        
    private var dateFormatter : DateFormatter!
    
    private var tempBackgroundView : UIView?
    private var hasInsertedTempBackgroundView = false
    
    override func viewDidLoad() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MM/dd"
        
        
        self.mapView.delegate = self
        self.mapView.logoView.isHidden = true
        self.mapView.attributionButton.isHidden = true
        self.mapView.isRotateEnabled = false
        self.mapView.backgroundColor = UIColor(red: 249/255, green: 255/255, blue: 247/255, alpha: 1.0)

        let styleURL = showStressMap ? URL(string: "https://tiles.ride.report/styles/v8/heatmap-style.json") : URL(string: "mapbox://styles/quicklywilliam/cire41sgs0001ghme6posegq0")
        self.mapView.styleURL = styleURL
        
        self.mapView.tintColor = ColorPallete.shared.transitBlue
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        URLCache.shared = urlCache
    }
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
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
            tripBackinglayer.lineCap = MGLStyleValue(rawValue: NSValue(mglLineCap: .round))
            tripBackinglayer.lineJoin = MGLStyleValue(rawValue: NSValue(mglLineJoin: .round))
            tripBackinglayer.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.darkGrey)
            mapView.style?.addLayer(tripBackinglayer)
            
            let goodBikelayer = MGLLineStyleLayer(identifier: "good-bike", source: self.selectedTripLineSource!)
            goodBikelayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            goodBikelayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.good.numberValue)])
            goodBikelayer.lineCap = tripBackinglayer.lineCap
            goodBikelayer.lineJoin = tripBackinglayer.lineJoin
            goodBikelayer.lineWidth = MGLStyleValue(interpolationBase: 1.5, stops: [
                14: MGLStyleValue(rawValue: 5),
                18: MGLStyleValue(rawValue: 20),
                ])
            tripBackinglayer.lineGapWidth = goodBikelayer.lineWidth // set the backinglayer's line gap width to the front layers' width
            goodBikelayer.lineOpacity = MGLStyleValue(rawValue: 0.9)
            goodBikelayer.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.goodGreen)
            mapView.style?.addLayer(goodBikelayer)
            
            let badBikelayer = MGLLineStyleLayer(identifier: "bad-bike", source: self.selectedTripLineSource!)
            badBikelayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            badBikelayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.bad.numberValue)])
            badBikelayer.lineCap = tripBackinglayer.lineCap
            badBikelayer.lineJoin = tripBackinglayer.lineJoin
            badBikelayer.lineWidth = goodBikelayer.lineWidth
            badBikelayer.lineOpacity = goodBikelayer.lineOpacity
            badBikelayer.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.badRed)
            mapView.style?.addLayer(badBikelayer)
            
            let mixedBikelayerGreen = MGLLineStyleLayer(identifier: "mixed-bike-green", source: self.selectedTripLineSource!)
            mixedBikelayerGreen.sourceLayerIdentifier = tripFeatureSourceIdentifier
            mixedBikelayerGreen.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.mixed.numberValue)])
            mixedBikelayerGreen.lineCap = tripBackinglayer.lineCap
            mixedBikelayerGreen.lineJoin = tripBackinglayer.lineJoin
            mixedBikelayerGreen.lineWidth = goodBikelayer.lineWidth
            mixedBikelayerGreen.lineOpacity = goodBikelayer.lineOpacity
            mixedBikelayerGreen.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.goodGreen)
            mapView.style?.addLayer(mixedBikelayerGreen)
            
            let mixedBikelayerRed = MGLLineStyleLayer(identifier: "mixed-bike-red", source: self.selectedTripLineSource!)
            mixedBikelayerRed.sourceLayerIdentifier = tripFeatureSourceIdentifier
            mixedBikelayerRed.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.mixed.numberValue)])
            mixedBikelayerRed.lineCap = MGLStyleValue(rawValue: NSValue(mglLineCap: .round))
            mixedBikelayerRed.lineJoin = MGLStyleValue(rawValue: NSValue(mglLineJoin: .round))
            mixedBikelayerRed.lineWidth = MGLStyleValue(interpolationBase: 1.5, stops: [
                14: MGLStyleValue(rawValue: 2.5),
                18: MGLStyleValue(rawValue: 10),
                ])
            mixedBikelayerRed.lineOpacity = MGLStyleValue(rawValue: 1.0)
            mixedBikelayerRed.lineDashPattern = MGLStyleValue(rawValue:[0, 1.8])
            mixedBikelayerRed.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.badRed)
            mapView.style?.addLayer(mixedBikelayerRed)
            
            let unratedBikelayer = MGLLineStyleLayer(identifier: "unrated-bike", source: self.selectedTripLineSource!)
            unratedBikelayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            unratedBikelayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.cycling.numberValue), NSPredicate(format: "%K == %@", "rating", RatingChoice.notSet.numberValue)])
            unratedBikelayer.lineCap = MGLStyleValue(rawValue: NSValue(mglLineCap: .round))
            unratedBikelayer.lineJoin = tripBackinglayer.lineJoin
            unratedBikelayer.lineWidth = goodBikelayer.lineWidth
            unratedBikelayer.lineOpacity = goodBikelayer.lineOpacity
            unratedBikelayer.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.unknownGrey)
            mapView.style?.addLayer(unratedBikelayer)
            
            let buslayer = MGLLineStyleLayer(identifier: "bus-trip", source: self.selectedTripLineSource!)
            buslayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            buslayer.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.bus.numberValue), NSPredicate(format: "%K == %@", "activityType", ActivityType.rail.numberValue)])
            buslayer.lineCap = tripBackinglayer.lineCap
            buslayer.lineJoin = tripBackinglayer.lineJoin
            buslayer.lineWidth = goodBikelayer.lineWidth
            buslayer.lineOpacity = goodBikelayer.lineOpacity
            buslayer.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.transitBlue)
            mapView.style?.addLayer(buslayer)
            
            let otherTriplayer = MGLLineStyleLayer(identifier: "other-trip", source: self.selectedTripLineSource!)
            otherTriplayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
            otherTriplayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K != %@", "activityType", ActivityType.cycling.numberValue), NSPredicate(format: "%K != %@", "activityType", ActivityType.bus.numberValue, NSPredicate(format: "%K != %@", "activityType", ActivityType.rail.numberValue))])
            otherTriplayer.lineCap = tripBackinglayer.lineCap
            otherTriplayer.lineJoin = tripBackinglayer.lineJoin
            otherTriplayer.lineWidth = goodBikelayer.lineWidth
            otherTriplayer.lineOpacity = goodBikelayer.lineOpacity
            otherTriplayer.lineColor = MGLStyleValue(rawValue: ColorPallete.shared.autoBrown)
            mapView.style?.addLayer(otherTriplayer)
        }
        
        if (needsTripLoad) {
            needsTripLoad = false
            self.setSelectedTrip(_selectedTrip)
        }

    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
            self.mapView.insertSubview(self.tempBackgroundView!, at: 0)
            self.mapView.bringSubview(toFront: self.tempBackgroundView!)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
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
    
    @IBAction func addIncident(_ sender: AnyObject) {
        DDLogVerbose("Add incident")
    }
    
    
    //
    // MARK: - Update Map UI
    //
    
    func setSelectedTrip(_ selectedTrip : Trip?) {
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
        
        var locs = trip.fetchOrderedLocations(simplified: true)

        if !trip.isClosed || locs.isEmpty {
            locs = trip.fetchOrderedLocations(simplified: false)
        }
        
        if let startLoc = locs.first,
            let endLoc = locs.last {
                self.startPoint = MGLPointAnnotation()
                self.startPoint!.coordinate = startLoc.coordinate()
                mapView.addAnnotation(self.startPoint!)
            
            if (trip.isClosed) {
                self.endPoint = MGLPointAnnotation()
                self.endPoint!.coordinate = endLoc.coordinate()
                mapView.addAnnotation(self.endPoint!)
            }
        }

        var coordinates : [CLLocationCoordinate2D] = []
        var count : UInt = 0
        for location in locs {
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
        
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "DebugContinousMode") {
                for prediction in trip.predictions {
                    self.mapView.addAnnotation(prediction)
                }
            } else {
                CMMotionActivityManager().queryActivityStarting(from: trip.startDate, to: trip.endDate, to: OperationQueue.main) { (activities, error) in
                        guard let activities = activities else {
                            return
                        }
                        for activity in activities {
                            self.mapView.addAnnotation(CMMotionActivityAnnotationWrapper(activity: activity, trip: trip))
                        }
                    }
            }
        #endif
        
        DispatchQueue.main.async(execute: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.mapView.setVisibleCoordinates(coordinates, count: count, edgePadding: strongSelf.insets, animated: true)
        })
    }
    
    //
    // MARK: - Map Kit
    //
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        var annotationImage: MGLAnnotationImage? = nil
        if let startPoint = self.startPoint, let pointAnnotation = annotation as? MGLPointAnnotation, pointAnnotation == startPoint {
            annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: "startMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinGreen.png")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "startMarker")
            }
        } else if let endPoint = self.endPoint, let pointAnnotation = annotation as? MGLPointAnnotation, pointAnnotation == endPoint {
            annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: "endMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinRed.png")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "endMarker")
            }
        }
        
        #if DEBUG
            if let prediction = annotation as? Prediction {
                return MGLAnnotationImage(image: prediction.pinImage, reuseIdentifier: prediction.title ?? "")
            } else if let motionActivity = annotation as? CMMotionActivityAnnotationWrapper {
                return MGLAnnotationImage(image: motionActivity.pinImage, reuseIdentifier: motionActivity.title ?? "")
            }
        #endif
        
        return annotationImage
    }
    
    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        if (!self.hasCenteredMap && userLocation != nil) {
            if _selectedTrip == nil {
                self.mapView.setCenter(userLocation!.coordinate, zoomLevel: 14, animated: false)
            }
        
            self.hasCenteredMap = true
        }
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        #if DEBUG
            if annotation is Prediction {
                return true
            } else if annotation is CMMotionActivityAnnotationWrapper {
                return true
            }
        #endif
        
        return false
    }
    
    func mapView(_ mapView: MGLMapView, rightCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        let view = UIButton(type: UIButtonType.detailDisclosure)
        
        return view
    }
}
