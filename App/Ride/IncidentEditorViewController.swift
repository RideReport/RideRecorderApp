//
//  IncidentEditorViewController.swift
//  Ride
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
        self.navigationController?.title = self.incident.title
    }
    
    @IBAction func done(sender: AnyObject) {
        self.incident.body = self.bodyTextView.text
        
        NetworkManager.sharedManager.saveAndSyncTripIfNeeded(self.incident.trip!, syncInBackground: false)
        
        self.navigationController?.dismissViewControllerAnimated(true, completion: {})
    }
 }
