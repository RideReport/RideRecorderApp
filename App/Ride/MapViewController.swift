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
import SwiftMessages
import Mapbox

#if DEBUG
    import CoreMotion
#endif

class MapViewController: UIViewController, MGLMapViewDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var mapView:  MGLMapView!
    @IBOutlet weak var centerMapButton: UIButton?
    
    var insets = UIEdgeInsets(top: 50, left: 20, bottom: 20, right: 20)
        
    private var dateFormatter : DateFormatter!
    
    override func viewDidLoad() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MM/dd"
        
        self.mapView.logoView.isHidden = true
        self.mapView.attributionButton.isHidden = true
        self.mapView.isRotateEnabled = false
        self.mapView.backgroundColor = UIColor(red: 249/255, green: 255/255, blue: 247/255, alpha: 1.0)
        
        self.mapView.tintColor = ColorPallete.shared.transitBlue
    
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        URLCache.shared = urlCache
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    @IBAction func centerMap(_ sender: AnyObject) {
        if let loc = RouteRecorder.shared.locationManager.location {
            self.mapView.setCenter(loc.coordinate, animated: true)
        }
    }
    
    //
    // MARK: - Map Kit
    //
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        
        return false
    }
    
    func mapView(_ mapView: MGLMapView, rightCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        let view = UIButton(type: UIButton.ButtonType.detailDisclosure)
        
        return view
    }
}
