//
//  ReportModeClassificationViewController.swift
//  Ride
//
//  Created by William Henderson on 12/11/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder
import Mapbox

class ReportModeClassificationViewController : UIViewController, MGLMapViewDelegate, UITextFieldDelegate {
    var trip: Trip! {
        didSet {
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self, let _ = strongSelf.view else {
                    return
                }
                
                strongSelf.updateRideSummaryView()
                
                if let mapViewController = strongSelf.mapViewController {
                    mapViewController.setSelectedTrip(strongSelf.trip)
                }
            })
        }
    }
    
    private var dateTimeFormatter: DateFormatter!

    @IBOutlet weak var notesTextField: UITextField!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var rideSummaryView: RideNotificationView!
    weak var mapViewController: RouteMapViewController?

    private var activityViewController: UIActivityViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.notesTextField.delegate = self
        
        self.dateTimeFormatter = DateFormatter()
        self.dateTimeFormatter.locale = Locale.current
        self.dateTimeFormatter.dateFormat = "MMM d 'at' h:mm a"
        
        for viewController in self.children {
            if (viewController.isKind(of: MapViewController.self)) {
                self.mapViewController = viewController as? RouteMapViewController
            }
        }
        
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
        
        if let notes = self.notesTextField.text, notes.count > 0 {
            metadata["notes"] = notes
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    //
    // MARK: - UI Code
    //
    
    func updateRideSummaryView() {
        guard let trip = self.trip else {
            return
        }
        self.rideSummaryView.dateString = String(format: "%@", self.dateTimeFormatter.string(from: trip.startDate as Date))

        self.rideSummaryView.body = trip.notificationString()
        self.rideSummaryView.hideControls(false)

    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
