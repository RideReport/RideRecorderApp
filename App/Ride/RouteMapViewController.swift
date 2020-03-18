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
    private let tripFeatureSourceIdentifier = "trip-polyline"
    
    private var selectedTripLineFeature : MGLPolylineFeature?
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
        self.mapView.styleURL = MGLStyle.darkStyleURL
        
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
           self.selectedTripLineFeature!.attributes = ["activityType": trip.activityType.numberValue]
           self.selectedTripLineSource.shape = self.selectedTripLineFeature
           
           DispatchQueue.main.async(execute: { [weak self] in
               guard let strongSelf = self else {
                   return
               }
               strongSelf.mapView.setVisibleCoordinates(coordinates, count: count, edgePadding: strongSelf.insets, animated: true)
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
           if (self.selectedTripLineSource == nil) {
               self.selectedTripLineSource = MGLShapeSource(identifier: tripFeatureSourceIdentifier, shape: nil, options: nil)
               self.mapView.style?.addSource(self.selectedTripLineSource)
               
               let tripBackinglayer = MGLLineStyleLayer(identifier: "trip-backing", source: self.selectedTripLineSource!)
               tripBackinglayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
               tripBackinglayer.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
               [14: 2, 18: 20])
               tripBackinglayer.lineOpacity = NSExpression(forConstantValue: 1.0)
               tripBackinglayer.lineCap = NSExpression(forConstantValue: "round")
               tripBackinglayer.lineJoin = NSExpression(forConstantValue: "round")
               tripBackinglayer.lineColor = NSExpression(forConstantValue: ColorPallete.shared.unknownGrey)
               mapView.style?.addLayer(tripBackinglayer)
               
               let bikelayer = MGLLineStyleLayer(identifier: "unrated-bike", source: self.selectedTripLineSource!)
               bikelayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
               bikelayer.predicate = NSPredicate(format: "%K == %@", "activityType", ActivityType.cycling.numberValue)
               bikelayer.lineCap = tripBackinglayer.lineCap
               bikelayer.lineJoin = tripBackinglayer.lineJoin
               bikelayer.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
               [14: 5, 18: 20])
            bikelayer.lineOpacity = NSExpression(forConstantValue: 0.9)
               bikelayer.lineColor = NSExpression(forConstantValue: ColorPallete.shared.goodGreen)
               mapView.style?.addLayer(bikelayer)
               
               let buslayer = MGLLineStyleLayer(identifier: "bus-trip", source: self.selectedTripLineSource!)
               buslayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
               buslayer.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", "activityType", ActivityType.bus.numberValue), NSPredicate(format: "%K == %@", "activityType", ActivityType.rail.numberValue)])
               buslayer.lineCap = tripBackinglayer.lineCap
               buslayer.lineJoin = tripBackinglayer.lineJoin
               buslayer.lineWidth = bikelayer.lineWidth
               buslayer.lineOpacity = bikelayer.lineOpacity
               buslayer.lineColor = NSExpression(forConstantValue: ColorPallete.shared.transitBlue)
               mapView.style?.addLayer(buslayer)
               
               let otherTriplayer = MGLLineStyleLayer(identifier: "other-trip", source: self.selectedTripLineSource!)
               otherTriplayer.sourceLayerIdentifier = tripFeatureSourceIdentifier
               otherTriplayer.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K != %@", "activityType", ActivityType.cycling.numberValue), NSPredicate(format: "%K != %@", "activityType", ActivityType.bus.numberValue, NSPredicate(format: "%K != %@", "activityType", ActivityType.rail.numberValue))])
               otherTriplayer.lineCap = tripBackinglayer.lineCap
               otherTriplayer.lineJoin = tripBackinglayer.lineJoin
               otherTriplayer.lineWidth = bikelayer.lineWidth
               otherTriplayer.lineOpacity = bikelayer.lineOpacity
               otherTriplayer.lineColor = NSExpression(forConstantValue: ColorPallete.shared.autoBrown)
               mapView.style?.addLayer(otherTriplayer)
           }
           
           if (needsTripLoad) {
               needsTripLoad = false
               self.setSelectedTrip(_selectedTrip)
           }

       }

    
}
