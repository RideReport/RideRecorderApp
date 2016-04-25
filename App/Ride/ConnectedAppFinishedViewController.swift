//
//  ConnectedAppFinishedViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class ConnectedAppFinishedViewController : UIViewController {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(4 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.dismissViewControllerAnimated(true, completion: nil)
            return
        }
    }
}