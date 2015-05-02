//
//  IncidentEditorViewController.swift
//  Ride
//
//  Created by William Henderson on 4/29/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class IncidentEditorViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    var mainViewController: MainViewController! = nil
    var incident : Incident! = nil
    
    @IBOutlet weak var bodyTextView: UITextView!
    @IBOutlet weak var typePicker: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.typePicker.dataSource = self
        self.typePicker.delegate = self
        
        self.refreshUI()
    }
    
    func refreshUI() {
        self.bodyTextView.text = self.incident.body
        
        if (self.incident.type.integerValue == Incident.IncidentType.Unknown.rawValue) {
            self.typePicker.selectRow(Incident.IncidentType.count - 1, inComponent: 0, animated: false)
        } else {
            self.typePicker.selectRow(self.incident.type.integerValue - 1, inComponent: 0, animated: false)
        }
    }
    
    @IBAction func done(sender: AnyObject) {
        self.incident.body = self.bodyTextView.text
        if (self.typePicker.selectedRowInComponent(0) == (Incident.IncidentType.count - 1)) {
            self.incident.type = NSNumber(integer: Incident.IncidentType.Unknown.rawValue)
        } else {
            self.incident.type = NSNumber(integer: self.typePicker.selectedRowInComponent(0) + 1)
        }
        
        NetworkManager.sharedManager.saveAndSyncTripIfNeeded(self.incident.trip!, syncInBackground: false)
        
        self.navigationController?.dismissViewControllerAnimated(true, completion: {})
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return Incident.IncidentType.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String {
        if row == (Incident.IncidentType.count - 1) {
            return "Other"
        }
        
        return Incident.IncidentType(rawValue: row + 1)!.text
    }
}
