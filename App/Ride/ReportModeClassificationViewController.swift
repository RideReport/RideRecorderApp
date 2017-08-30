//
//  ReportModeClassificationViewController.swift
//  Ride
//
//  Created by William Henderson on 12/11/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Mixpanel

class ReportModeClassificationViewController : UIViewController, MGLMapViewDelegate, UITextFieldDelegate {
    var trip: Trip! {
        didSet {
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self, let _ = strongSelf.view else {
                    return
                }

                strongSelf.updateTripPolylines()
                strongSelf.updateRideSummaryView()
            })
        }
    }
    
    private var tripBackingLine: MGLPolyline?
    private var tripLine: MGLPolyline?
    private var startPoint: MGLPointAnnotation?
    private var endPoint: MGLPointAnnotation?
    
    private var dateTimeFormatter: DateFormatter!

    @IBOutlet weak var notesTextField: UITextField!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var rideSummaryView: RideNotificationView!
    @IBOutlet weak var mapView:  MGLMapView!

    private var activityViewController: UIActivityViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.delegate = self
        self.mapView.logoView.isHidden = true
        self.mapView.attributionButton.isHidden = true
        self.mapView.isRotateEnabled = false
        self.mapView.backgroundColor = UIColor.darkGray
        
        self.notesTextField.delegate = self
        
        self.mapView.showsUserLocation = false
        
        self.dateTimeFormatter = DateFormatter()
        self.dateTimeFormatter.locale = Locale.current
        self.dateTimeFormatter.dateFormat = "MMM d 'at' h:mm a"
        
        let styleURL = URL(string: "https://tiles.ride.report/styles/v8/base-style.json")
        self.mapView.styleURL = styleURL
        
        self.updateTripPolylines()
        self.updateRideSummaryView()
    }
    
    
    //
    // MARK: - Actions
    //
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func upload(_ sender: AnyObject) {
        var metadata: [String: Any] = [:]

        if let notes = self.notesTextField.text, notes.characters.count > 0 {
            metadata["notes"] = notes
        }
        APIClient.shared.uploadSensorData(trip, withMetadata: metadata)
        
        self.dismiss(animated: true, completion: nil)
    }
    
    //
    // MARK: - UI Code
    //
    
    func updateRideSummaryView() {
        guard let trip = self.trip else {
            self.tripLine = nil
            self.tripBackingLine = nil
            
            return
        }
        
        self.rideSummaryView.dateString = String(format: "%@", self.dateTimeFormatter.string(from: trip.startDate as Date))

        self.rideSummaryView.body = trip.notificationString()
        self.rideSummaryView.hideControls(false)

    }
    
    func updateTripPolylines() {
        if let tripBackingLine = self.tripBackingLine {
            self.mapView.removeAnnotation(tripBackingLine)
        }
        if let tripLine = self.tripLine {
            self.mapView.removeAnnotation(tripLine)
        }
        if let startPoint = self.startPoint {
            self.mapView.removeAnnotation(startPoint)
        }
        if let endPoint = self.endPoint {
            self.mapView.removeAnnotation(endPoint)
        }
        
        guard let trip = self.trip else {
            self.tripLine = nil
            self.tripBackingLine = nil
            
            return
        }
        
        let locs = trip.generateSummaryLocations()
        
        if let startLoc = locs.first,
            let endLoc = locs.last {
            self.startPoint = MGLPointAnnotation()
            self.startPoint!.coordinate = startLoc.coordinate()
            mapView.addAnnotation(self.startPoint!)
            
            self.endPoint = MGLPointAnnotation()
            self.endPoint!.coordinate = endLoc.coordinate()
            mapView.addAnnotation(self.endPoint!)
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
        
        self.tripLine = MGLPolyline(coordinates: &coordinates, count: count)
        self.tripBackingLine = MGLPolyline(coordinates: &coordinates, count: count)
        
        self.mapView.add(self.tripBackingLine!)
        self.mapView.add(self.tripLine!)
        
        
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
        let padFactorTop : Double = 0.95
        let padFactorBottom : Double = 0.8

        let sizeLong = (maxLong - minLong)
        let sizeLat = (maxLat - minLat)
        
        let bounds = MGLCoordinateBoundsMake(CLLocationCoordinate2DMake(minLat - (sizeLat * padFactorBottom), minLong - (sizeLong * padFactorX)), CLLocationCoordinate2DMake(maxLat + (sizeLat * padFactorTop),maxLong + (sizeLong * padFactorX)))
        DispatchQueue.main.async(execute: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.mapView.setVisibleCoordinateBounds(bounds, animated: false)
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
    
    func mapView(_ mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        if (annotation == self.tripBackingLine) {
            return 14
        } else {
            return 8
        }
    }
    
    func mapView(_ mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        return 1.0
    }
    
    func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        if (annotation == self.tripBackingLine) {
            return ColorPallete.shared.almostWhite
        }
        
        if let trip = self.trip {
            if (trip.activityType == .cycling) {
                if(trip.rating.choice == RatingChoice.good) {
                    return ColorPallete.shared.goodGreen
                } else if(trip.rating.choice == RatingChoice.bad) {
                    return ColorPallete.shared.badRed
                } else {
                    return ColorPallete.shared.unknownGrey
                }
            } else if (trip.activityType == .bus || trip.activityType == .rail) {
                return ColorPallete.shared.transitBlue
            }
            
            return ColorPallete.shared.autoBrown
        }
        
        return UIColor.clear
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
