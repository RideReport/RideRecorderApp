//
//  StressMapViewController.swift
//  Ride Report
//
//  Created by Heather Buletti on 7/6/18.
//  Copyright © 2018 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import RouteRecorder

class StressMapViewController: MapViewController {
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let loc = RouteRecorder.shared.locationManager.location {
            self.mapView.setCenter(loc.coordinate, zoomLevel: 14, animated: false)
        } else {
            self.mapView.setCenter(CLLocationCoordinate2DMake(45.5215907, -122.654937), zoomLevel: 14, animated: false)
        }
    }
}
