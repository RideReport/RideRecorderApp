//
//  HealthKitSetupViewController.swift
//  Ride
//
//  Created by William Henderson on 4/12/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import WatchConnectivity
import RouteRecorder

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
        
        self.progressView.isHidden = true
        self.doneButton.isHidden = true
        
        if #available(iOS 10.0, *) {
            if WatchManager.shared.paired {
                // if a watch is paired
                self.titleLabel.text = "Save Rides to Apple Watch"
                self.detailLabel.text = "Trying to fill your rings? Ride Report can automatically log your rides as exercise on your Apple Watch and the Health App."
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func sync(_ sender: AnyObject) {
        self.progressView.progress = 0.0
        self.progressView.isHidden = false
        self.disclaimerLabel.isHidden = true
        self.titleLabel.text = "Saving Existing Rides"
        self.detailLabel.text = "We're saving all your rides into the Health App. Future rides will be saved automatically."
        if #available(iOS 10.0, *) {
            if WatchManager.shared.paired {
                self.detailLabel.text = "We're saving all your rides to your Apple Watch. Future rides will be saved automatically."
            }
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(HealthKitSetupViewController.cancel))
        
        self.startBeatingHeart()
        
        self.connectButton.isHidden = true
        
        UserDefaults.standard.set(true, forKey: "healthKitIsSetup")
        UserDefaults.standard.synchronize()

        HealthKitManager.startup() { success in 
            let context = CoreDataManager.shared.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
            fetchedRequest.predicate = NSPredicate(format: "activityTypeInteger == %i AND healthKitUuid == nil", ActivityType.cycling.rawValue)
            fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            
            let results: [AnyObject]?
            do {
                results = try context.fetch(fetchedRequest)
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
    
    @IBAction func cancel(_ sender: AnyObject) {
        var message = "Future rides will not be automatically saved to the Health App."
        if #available(iOS 10.0, *) {
            if WatchManager.shared.paired {
                message = "Future rides will not be automatically saved to your Apple Watch."
            }
        }
        let alertController = UIAlertController(title:nil, message: message, preferredStyle: UIAlertControllerStyle.actionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel Saving", style: UIAlertActionStyle.destructive, handler: { (_) in
            self.didCancel = true
            HealthKitManager.shutdown()
            UserDefaults.standard.set(false, forKey: "healthKitIsSetup")
            UserDefaults.standard.synchronize()
            
            self.dismiss(animated: true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: "Keep Saving", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func done(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func startBeatingHeart() {
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
        growAnimation.repeatCount = Float.infinity
        
        self.heartLabel.layer.add(growAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    func stopBeatingHeart() {
        self.heartLabel.layer.removeAnimation(forKey: "transform")
    }

    private func syncNextUnsyncedTrip() {
        guard !self.didCancel else {
            return
        }
        
        guard let nextTrip = self.tripsRemainingToSync?.first else {
            self.progressView.progress = 1.0
            self.progressView.isHidden = true
            self.doneButton.isHidden = false
            self.detailLabel.isHidden = false
            self.disclaimerLabel.isHidden = true
            
            self.stopBeatingHeart()
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.hidesBackButton = true
            
            self.titleLabel.text = "You're done!"
            
            if #available(iOS 10.0, *) {
                if WatchManager.shared.paired {
                    // if a watch is paired
                    self.detailLabel.text = "Your rides will be automatically saved to your Apple Watch and the Health App."
                }
            } else {
                self.detailLabel.text = "We've saved all your rides into the Health App. Future rides will be saved automatically."
            }
            
            return
        }
        HealthKitManager.shared.saveOrUpdateTrip(nextTrip) { _ in
            DispatchQueue.main.async {
                self.tripsRemainingToSync!.removeFirst()
                let progress = Float(self.totalTripsToSync - self.tripsRemainingToSync!.count) / Float(self.totalTripsToSync)
                self.progressView.setProgress(progress, animated: true)

                self.syncNextUnsyncedTrip()
            }
        }
    }
}
