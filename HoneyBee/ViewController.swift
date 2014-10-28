//
//  ViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        
        var coordinates : [CLLocationCoordinate2D] = []
        var count : Int = 0
        for location in Location.allLocations()! {
            coordinates += [(location as Location).coordinate()]
            count++
        }
        
        let polyline = MKPolyline(coordinates: &coordinates, count: count)
        self.mapView.addOverlay(polyline)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Map Kit
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay.isKindOfClass(MKPolyline)) {
            let view = MKPolylineRenderer(polyline:(overlay as MKPolyline))
        
            view.fillColor = UIColor.blackColor()
            view.strokeColor = UIColor.blackColor()
            view.lineWidth = 4
            return view;
        } else {
            return nil;
        }
    }
}

