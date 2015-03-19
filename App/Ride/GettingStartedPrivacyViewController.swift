//
//  GettingStartedPrivacyViewController.swift
//  Ride
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

class GettingStartedPrivacyViewController: GettingStartedChildViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var nextButton : UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var cancelButton : UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var setupPrivacyButton: UIButton!
    private var hasCenteredMap : Bool = false
    
    private var privacyCircle : MKCircle?
    private var privacyCircleRenderer : PrivacyCircleRenderer?
    private var isDraggingPrivacyCircle : Bool = false
    private var privacyCirclePanGesture : UIPanGestureRecognizer!
    
    override func viewDidLoad() {
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        
        self.privacyCirclePanGesture = UIPanGestureRecognizer(target: self, action: "respondToPrivacyCirclePanGesture:")
        self.privacyCirclePanGesture.delegate = self
        self.mapView.addGestureRecognizer(self.privacyCirclePanGesture)
        
        self.mapView.mapType = MKMapType.Satellite
        
        // set the size of the url cache for tile caching.
        let memoryCapacity = 1 * 1024 * 1024
        let diskCapacity = 40 * 1024 * 1024
        let urlCache = NSURLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        NSURLCache.setSharedURLCache(urlCache)
        
        MBXMapKit.setAccessToken("pk.eyJ1IjoicXVpY2tseXdpbGxpYW0iLCJhIjoibmZ3UkZpayJ9.8gNggPy6H5dpzf4Sph4-sA")
        let tiles = MBXRasterTileOverlay(mapID: "quicklywilliam.l4imi65m")
        self.mapView.addOverlay(tiles)
        
        setInitialUI()
    }
    
    func setInitialUI() {
        self.helperTextLabel.markdownStringValue = "You can hide Rides that pass near your house. Set up a **Privacy Circle**."
    }
    
    @IBAction func tappedSetupPrivacy(sender: AnyObject) {
        self.skipButton.fadeOut() {
            self.cancelButton.fadeIn()
            return
        }
        
        self.setupPrivacyButton.fadeOut() {
            self.saveButton.fadeIn()
            return
        }
        self.helperTextLabel.animatedSetMarkdownStringValue("Drag the circle to the area you want kept private. The beginnings and ends of Rides inside the circle **won't get logged**.")
        
        if (self.privacyCircle == nil) {
            if (PrivacyCircle.privacyCircle() == nil) {
                self.privacyCircle = MKCircle(centerCoordinate: mapView.userLocation.coordinate, radius: PrivacyCircle.defaultRadius())
            } else {
                self.privacyCircle = MKCircle(centerCoordinate: CLLocationCoordinate2DMake(PrivacyCircle.privacyCircle().latitude.doubleValue, PrivacyCircle.privacyCircle().longitude.doubleValue), radius: PrivacyCircle.privacyCircle().radius.doubleValue)
            }
            self.mapView.addOverlay(self.privacyCircle)
        }
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func respondToPrivacyCirclePanGesture(sender: AnyObject) {
        if (self.privacyCircle == nil || self.privacyCircleRenderer == nil) {
            return
        }
        
        if (sender.numberOfTouches() > 1) {
            return
        }
        
        if (sender.state == UIGestureRecognizerState.Began) {
            let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
            let gestureLocation = CLLocation(latitude: gestureCoord.latitude, longitude: gestureCoord.longitude)
            
            let circleLocation = CLLocation(latitude: self.privacyCircle!.coordinate.latitude, longitude: self.privacyCircle!.coordinate.longitude)
            
            if (gestureLocation.distanceFromLocation(circleLocation) <= self.privacyCircle!.radius) {
                self.mapView.scrollEnabled = false
                self.isDraggingPrivacyCircle = true
            } else {
                self.mapView.scrollEnabled = true
                self.isDraggingPrivacyCircle = false
            }
        } else if (sender.state == UIGestureRecognizerState.Changed) {
            if (self.isDraggingPrivacyCircle) {
                let gestureCoord = self.mapView.convertPoint(sender.locationInView(self.mapView), toCoordinateFromView: self.mapView)
                
                let oldPrivacyCircle = self.privacyCircle
                self.privacyCircle! = MKCircle(centerCoordinate: gestureCoord, radius: self.privacyCircle!.radius)
                self.mapView.addOverlay(self.privacyCircle, level: MKOverlayLevel.AboveLabels)
                self.mapView.removeOverlay(oldPrivacyCircle)
            }
        } else {
            self.mapView.scrollEnabled = true
            self.isDraggingPrivacyCircle = false
        }
    }
    
    @IBAction func cancelSetPrivacyCircle(sender: AnyObject) {
        self.mapView.removeOverlay(self.privacyCircle)
        self.mapView.setNeedsDisplay()
        self.privacyCircle = nil
        self.privacyCircleRenderer = nil
        
        setInitialUI()
        self.saveButton.fadeOut() {
            self.setupPrivacyButton.fadeIn()
            return
        }
        
        self.cancelButton.fadeOut() {
            self.skipButton.fadeIn()
            return
        }
    }
    
    @IBAction func saveSetPrivacyCircle(sender: AnyObject) {
        if (self.privacyCircle == nil || self.privacyCircleRenderer == nil) {
            return
        }
        
        PrivacyCircle.updateOrCreatePrivacyCircle(self.privacyCircle!)
        
        self.parent?.nextPage()
    }
    
    // MARK: - Map Kit
    func mapView(mapView: MKMapView!, didUpdateUserLocation userLocation: MKUserLocation!) {
        if (!self.hasCenteredMap) {
            let mapRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, span: MKCoordinateSpanMake(0.01, 0.01));
            mapView.setRegion(mapRegion, animated: false)
            
            self.hasCenteredMap = true
        }
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay.isKindOfClass(MBXRasterTileOverlay)) {
            let renderer = MBXRasterTileRenderer(overlay: overlay)
            return renderer
        } else if (overlay.isKindOfClass(MKCircle)) {
            self.privacyCircleRenderer = PrivacyCircleRenderer(circle: overlay as MKCircle)
            self.privacyCircleRenderer!.strokeColor = UIColor.redColor()
            self.privacyCircleRenderer!.fillColor = UIColor.redColor().colorWithAlphaComponent(0.3)
            self.privacyCircleRenderer!.lineWidth = 1.0
            self.privacyCircleRenderer!.lineDashPattern = [3,5]
            
            return self.privacyCircleRenderer
        } else {
            return nil;
        }
    }

}