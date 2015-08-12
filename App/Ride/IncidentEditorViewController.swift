//
//  IncidentEditorViewController.swift
//  Ride Report
//
//  Created by William Henderson on 4/29/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class IncidentEditorViewController: UIViewController  {
    var mainViewController: MainViewController! = nil
    var incident : Incident! = nil
    
    @IBOutlet weak var bodyTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
        
        self.refreshUI()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.bodyTextView.becomeFirstResponder()
    }
    
    func refreshUI() {
        self.bodyTextView.text = self.incident.body
        self.title = self.incident.title
    }
    
    @IBAction func done(sender: AnyObject) {
        self.incident.body = self.bodyTextView.text
        
        APIClient.sharedClient.saveAndSyncTripIfNeeded(self.incident.trip!, syncInBackground: false)
        
        self.navigationController?.popToRootViewControllerAnimated(true)
    }
    
    @IBAction func deleteIncident(sender: AnyObject) {
        UIActionSheet.showInView(self.view, withTitle: "This incident will be permanently deleted", cancelButtonTitle: "Cancel", destructiveButtonTitle: "Delete", otherButtonTitles: []) { (sheet, tappedIndex) -> Void in
            if (tappedIndex == 0) {
                self.incident.managedObjectContext?.deleteObject(self.incident)
                if (self.incident.trip != nil) {
                    APIClient.sharedClient.saveAndSyncTripIfNeeded(self.incident.trip!)
                    self.mainViewController.refreshSelectrTrip()
                }
                
                self.navigationController?.popToRootViewControllerAnimated(true)
            }
        }
    }
 }
