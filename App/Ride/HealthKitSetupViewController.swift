//
//  HealthKitSetupViewController.swift
//  Ride
//
//  Created by William Henderson on 4/12/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class HealthKitSetupViewController : UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var disclaimerLabel: UILabel!
    
    @IBOutlet weak var heartLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!

    var tripsRemainingToSync: [Trip]?
    var totalTripsToSync = 0
    private var didCancel = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.progressView.hidden = true
        self.doneButton.hidden = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func sync(sender: AnyObject) {
        self.progressView.progress = 0.0
        self.progressView.hidden = false
        self.disclaimerLabel.hidden = true
        self.titleLabel.text = "Saving Existing Rides"
        self.detailLabel.text = "We're saving all your rides into the Health App. Future rides will be saved automatically."
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(HealthKitSetupViewController.cancel))
        
        self.startBeatingHeart()
        
        self.connectButton.hidden = true
        
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "healthKitIsSetup")
        NSUserDefaults.standardUserDefaults().synchronize()

        HealthKitManager.startup() { success in 
            let context = CoreDataManager.sharedManager.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest(entityName: "Trip")
            fetchedRequest.predicate = NSPredicate(format: "activityType == %i AND healthKitUuid == nil", ActivityType.Cycling.rawValue)
            fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let results: [AnyObject]?
            do {
                results = try context.executeFetchRequest(fetchedRequest)
            } catch let error {
                DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
                return
            }
            guard let theTrips = results as? [Trip] else {
                return
            }

            self.tripsRemainingToSync = theTrips
            self.totalTripsToSync = theTrips.count
            self.syncNextUnsyncedTrip()
        }
    }
    
    @IBAction func cancel(sender: AnyObject) {
        let alertController = UIAlertController(title:nil, message: "Future rides will not be automatically saved to the Health App.", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel Saving", style: UIAlertActionStyle.Destructive, handler: { (_) in
            self.didCancel = true
            HealthKitManager.shutdown()
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "healthKitIsSetup")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: "Keep Saving", style: UIAlertActionStyle.Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    @IBAction func done(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func startBeatingHeart() {
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
        growAnimation.repeatCount = Float.infinity
        
        self.heartLabel.layer.addAnimation(growAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    func stopBeatingHeart() {
        self.heartLabel.layer.removeAnimationForKey("transform")
    }

    private func syncNextUnsyncedTrip() {
        guard !self.didCancel else {
            return
        }
        
        guard let nextTrip = self.tripsRemainingToSync?.first else {
            self.progressView.progress = 1.0
            self.progressView.hidden = true
            self.doneButton.hidden = false
            self.detailLabel.hidden = false
            self.disclaimerLabel.hidden = true
            
            self.stopBeatingHeart()
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.hidesBackButton = true
            
            self.titleLabel.text = "You're done!"
            self.detailLabel.text = "We've saved all your rides into the Health App. Future rides will be saved automatically."
            
            return
        }
        HealthKitManager.sharedManager.saveOrUpdateTrip(nextTrip) { _ in
            dispatch_async(dispatch_get_main_queue()) {
                self.tripsRemainingToSync!.removeFirst()
                let progress = Float(self.totalTripsToSync - self.tripsRemainingToSync!.count) / Float(self.totalTripsToSync)
                self.progressView.setProgress(progress, animated: true)

                self.syncNextUnsyncedTrip()
            }
        }
    }
}