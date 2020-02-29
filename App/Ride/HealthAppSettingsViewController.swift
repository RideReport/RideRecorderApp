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
            if WatchManager.shared.paired {
                // if a watch is paired
                self.detailLabel.text = "Ride automatically saves all your rides to your Apple Watch and the Health App."
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        CATransaction.begin()
        
        let growAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        let growScale: CGFloat = 1.1
        growAnimation.values = [
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(growScale, growScale, 1.0)),
            NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
        ]
        growAnimation.keyTimes = [0, 0.12, 0.50, 0.62, 1]
        growAnimation.isAdditive = true
        growAnimation.duration = 1.2
        growAnimation.timeOffset = 0.5
        
        self.heartLabel.layer.add(growAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    @IBAction func disconnect(_ sender: AnyObject) {
        var message = "Your rides will no longer automatically saved into the Health App."
        if #available(iOS 10.0, *) {
            if WatchManager.shared.paired {
                message = "Your rides will no longer automatically saved to your Apple Watch."
            }
        }
        let alertController = UIAlertController(title:nil, message: message, preferredStyle: UIAlertController.Style.actionSheet)
        alertController.addAction(UIAlertAction(title: "Disconnect", style: UIAlertAction.Style.destructive, handler: { (_) in
            HealthKitManager.shutdown()
            UserDefaults.standard.set(false, forKey: "healthKitIsSetup")
            UserDefaults.standard.synchronize()
            self.navigationController?.popViewController(animated: true)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
}
