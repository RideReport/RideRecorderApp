//
//  IncidentEditorViewController.swift
//  Ride
//
//  Created by William Henderson on 4/29/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class IncidentEditorViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.toolbar.barStyle = UIBarStyle.BlackTranslucent
    }
    
    @IBAction func done(sender: AnyObject) {
        self.navigationController?.dismissViewControllerAnimated(true, completion: {})
    }
    
}
