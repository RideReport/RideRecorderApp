//
//  RouteMapViewController.swift
//  Ride Report
//
//  Created by Heather Buletti on 7/6/18.
//  Copyright © 2018 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder
import CocoaLumberjack
import Mapbox
import SwiftMessages

class RouteMapViewController: MapViewController {
    private let tripFeatureSourceIdentifier = "trip"
    
    private var selectedTripLineFeature : MGLShapeCollectionFeature?
    private var selectedTripLineSource : MGLShapeSource!
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    private var needsTripLoad : Bool = false
    private var _selectedTrip : Trip? = nil
    private var tripsAreLoaded = false
    private var isInitialAnimation = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.delegate = self
        self.mapView.isHidden = true
        
        self.centerMapButton?.isHidden = true
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
        
        // otherwise, use the local route locations if given
        
        
        guard let route = trip.route else {
            self.selectedTripLineSource = nil
            
            return
        }
        
        let locs = route.isClosed ? route.fetchOrGenerateSummaryLocations() : route.fetchLocations()
        
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
        
        let backingLine = MGLPolylineFeature(coordinates: &coordinates, count: count)
        backingLine.attributes = ["activityType": trip.activityType.numberValue, "role": "backing"]
        
        let line = MGLPolylineFeature(coordinates: &coordinates, count: count)
        line.attributes = ["activityType": trip.activityType.numberValue, "role": "track", "isImputed": false]
        
        self.selectedTripLineFeature = MGLShapeCollectionFeature(shapes: [backingLine, line])
        
        self.selectedTripLineSource.shape = self.selectedTripLineFeature
        
        DispatchQueue.main.async(execute: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if (strongSelf.isInitialAnimation) {
                strongSelf.mapView.fadeIn()
            }
            strongSelf.mapView.setVisibleCoordinates(coordinates, count: count, edgePadding: strongSelf.insets, animated: !strongSelf.isInitialAnimation)
            strongSelf.isInitialAnimation = false
        })
    }
    
    //
    // MARK: MGLMapViewDelegate methods
    //
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        var annotationImage: MGLAnnotationImage? = nil
        if let startPoint = self.startPoint, let pointAnnotation = annotation as? MGLPointAnnotation, pointAnnotation == startPoint {
            annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: "startMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinGreen")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "startMarker")
            }
        } else if let endPoint = self.endPoint, let pointAnnotation = annotation as? MGLPointAnnotation, pointAnnotation == endPoint {
            annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: "endMarker")
            if (annotationImage == nil) {
                let image = UIImage(named: "pinRed")
                annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "endMarker")
            }
        }
        
        return annotationImage
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
    
}
