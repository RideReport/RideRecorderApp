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
import CocoaLumberjack
import RouteRecorder
#if DEBUG
    import CoreMotion
#endif

class MapViewController: UIViewController, MGLMapViewDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var mapView:  MGLMapView!
    @IBInspectable var showStressMap : Bool = false
    
    private var tripsAreLoaded = false
    
    private let tripFeatureSourceIdentifier = "trip"
    
    private var selectedTripLineFeature : MGLPolylineFeature?
    private var selectedTripLineSource : MGLShapeSource!
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    
    var insets = UIEdgeInsetsMake(50, 20, 20, 20)
    
    private var hasCenteredMap : Bool = false
    
    private var needsTripLoad : Bool = false
    
    private var _selectedTrip : Trip? = nil
        
    private var dateFormatter : DateFormatter!
    
    override func viewDidLoad() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MM/dd"
        
        
        self.mapView.delegate = self
        self.mapView.logoView.isHidden = true
        self.mapView.attributionButton.isHidden = true
        self.mapView.isRotateEnabled = false
        self.mapView.backgroundColor = UIColor(red: 249/255, green: 255/255, blue: 247/255, alpha: 1.0)

        let styleURL = showStressMap ? URL(string: "https://tiles.ride.report/styles/v8/heatmap-style.json") : URL(string: AuthenticatedAPIRequest.serverAddress + "styles/v8/trip-display-style.json")
        self.mapView.styleURL = styleURL
        
        self.mapView.tintColor = ColorPallete.shared.transitBlue
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        URLCache.shared = urlCache
    }
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        if let style = self.mapView.style, let source = style.source(withIdentifier: tripFeatureSourceIdentifier) as? MGLShapeSource {
            self.selectedTripLineSource = source
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
    // MARK: - Update Map UI
    //
    
    private var isRequestingDisplayData = false
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
        
        // if we have a displayDataURLString, use that
        
        if let displayDataURLString = trip.displayDataURLString {
            if !isRequestingDisplayData {
                isRequestingDisplayData = true
                RideReportAPIClient.shared.getTripDisplayData(displayDataURL: displayDataURLString) { (data) in
                    self.isRequestingDisplayData = false
                    guard let data = data else {
                        let alertController = UIAlertController(title: "Error loading map", message: "Ride Report could not download the map for this trip. Please try again later.", preferredStyle: UIAlertControllerStyle.alert)
                        alertController.addAction(UIAlertAction(title: "We're so sorry ☹️", style: UIAlertActionStyle.cancel, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                        
                        return
                    }
                    
                    if let shape = try? MGLShape(data: data, encoding: String.Encoding.utf8.rawValue) {
                        self.selectedTripLineSource.shape = shape
                        if let shape = self.selectedTripLineSource.shape as? MGLShapeCollectionFeature {
                            self.mapView.showAnnotations(shape.shapes, edgePadding: self.insets, animated: true)
                        }
                    } else {
                        DDLogWarn("Error parsing display data JSON!")
                    }
                }
            }

            return
        }
        
        // otherwise, use the local route locations if given
        
        
        guard let route = trip.route else {
            self.selectedTripLineSource = nil
            
            return
        }
        
        let locs = route.fetchOrGenerateSummaryLocations()
        
        if let startLoc = locs.first,
            let endLoc = locs.last {
                self.startPoint = MGLPointAnnotation()
                self.startPoint!.coordinate = startLoc.coordinate()
                mapView.addAnnotation(self.startPoint!)
            
            if (!trip.isInProgress) {
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
        
        return false
    }
    
    func mapView(_ mapView: MGLMapView, rightCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        let view = UIButton(type: UIButtonType.detailDisclosure)
        
        return view
    }
}
