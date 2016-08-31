//
//  HealthAppSettingsViewController.swift
//  Ride
//
//  Created by William Henderson on 5/2/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import WatchConnectivity

class HealthAppSettingsViewController : UIViewController{
    @IBOutlet weak var heartLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 10.0, *) {
            if WCSession.isSupported() {
                // if a watch is paired
                self.detailLabel.text = "Ride Report automatically saves all your rides to the Health App and your Apple Watch."
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        CATransaction.begin()
        
        let growAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        let growScale: CGFloat = 1.1
        growAnimation.values = [
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
        ]
        growAnimation.keyTimes = [0, 0.12, 0.50, 0.62, 1]
        growAnimation.additive = true
        growAnimation.duration = 1.2
        growAnimation.timeOffset = 0.5
        
        self.heartLabel.layer.addAnimation(growAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func disconnect(sender: AnyObject) {
        let alertController = UIAlertController(title:nil, message: "Your rides will no longer automatically saved into the Health App.", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Disconnect", style: UIAlertActionStyle.Destructive, handler: { (_) in
            HealthKitManager.shutdown()
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "healthKitIsSetup")
            NSUserDefaults.standardUserDefaults().synchronize()
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
}
