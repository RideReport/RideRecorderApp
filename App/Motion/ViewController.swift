//
//  ViewController.swift
//  Motion
//
//  Created by William Henderson on 3/2/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation
import CoreMotion
import MediaPlayer
import SwiftyJSON

class ViewController: UIViewController, CLLocationManagerDelegate {
    fileprivate var backgroundTaskID = UIBackgroundTaskInvalid
    
    var sensorComponent: SensorManagerComponent!

    fileprivate var isRecording: Bool = false
    fileprivate var activityManager: CMMotionActivityManager!
    fileprivate var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    fileprivate var sensorDataCollectionForUpload : SensorDataCollection?
    fileprivate var sensorDataCollection : SensorDataCollection?
    fileprivate var sensorDataCollectionForQuery : SensorDataCollection?
    
    fileprivate var locationManager : CLLocationManager!
    fileprivate var player: AVAudioPlayer!

    @IBOutlet weak var helperText: UILabel!
    @IBOutlet weak var startStopButton: UIBarButtonItem!
    @IBOutlet weak var pauseDeleteButton: UIBarButtonItem!
    @IBOutlet weak var predictSwitch: UISwitch!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var activityLabel2: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sensorComponent = SensorManagerComponent.shared
        
        self.predictSwitch.isOn = false
        
        self.activityManager = CMMotionActivityManager()
        
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        let url = Bundle.main.url(forResource: "silence", withExtension: ".mp3")
        try! self.player = AVAudioPlayer(contentsOf: url!)
        self.player.numberOfLoops = -1
                
        // hack to take control of remote
        self.player.play()
        self.player.pause()
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try! AVAudioSession.sharedInstance().setActive(true)
        
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget (handler: { (event) -> MPRemoteCommandHandlerStatus in
            if (self.isRecording) {
                self.tappedPauseDelete(self)
            } else {
                self.tappedStartFinish(self)
            }
            
            return MPRemoteCommandHandlerStatus.success
        })
        
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget (handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.predictSwitch.isOn = !self.predictSwitch.isOn

            var utteranceString = ""
            if self.predictSwitch.isOn {
                utteranceString = "Prediction enabled"
            } else {
                utteranceString = "Prediction disabled"
            }
            let utterance = AVSpeechUtterance(string: utteranceString)
            utterance.rate = 0.6
            self.synth.speak(utterance)
            
            self.runPredictionIfEnabled()
            
            return MPRemoteCommandHandlerStatus.success
        })
        
        self.updateUI()
    }
    
    func updateUI() {
        if (self.isRecording) {
            self.startStopButton.title = "Finish"
            self.helperText.text = "Tap 'Finish' when you end your trip, change modes or change the position of your phone (for example, taking it out of your bag)."
            self.pauseDeleteButton.title = "Pause"
            self.pauseDeleteButton.isEnabled = true
        } else {
            if (self.sensorDataCollection != nil){
                // paused
                self.pauseDeleteButton.title = "Delete"
                self.pauseDeleteButton.tintColor = UIColor.red
                self.startStopButton.title = "Resume"
                self.helperText.text = "Tap 'Resume' to keep recording this trip, or 'Delete' to discard it."
                self.pauseDeleteButton.isEnabled = true
            } else {
                // init state
                self.pauseDeleteButton.title = "Pause"
                self.pauseDeleteButton.tintColor = UIColor.gray
                self.helperText.text = "Tap 'Start' when you begin your trip."
                self.startStopButton.title = "Start"
                self.pauseDeleteButton.isEnabled = false
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateUI()
    }
    
    private func stopRecording() {
        self.isRecording = false
        CoreDataManager.shared.saveContext()
        
        sensorComponent.classificationManager.stopGatheringSensorData()
        if (self.sensorDataCollectionForQuery == nil) {
            self.locationManager.stopUpdatingLocation()
        }
        self.player.pause()
    }
    
    @IBAction func tappedPauseDelete(_ sender: AnyObject) {
        if (self.isRecording) {
            // tapped pause
            stopRecording()
            
            let utterance = AVSpeechUtterance(string: "Paused")
            utterance.rate = 0.6
            self.synth.speak(utterance)
        } else {
            self.sensorDataCollectionForUpload = nil
            self.sensorDataCollection = nil
        }
        
        self.updateUI()
    }
    
    @IBAction func tappedStartFinish(_ sender: AnyObject) {
        if (!self.isRecording) {
            // tapped start or resume
            self.isRecording = true
            var utterance = AVSpeechUtterance(string: "Resumed")

            if self.sensorDataCollection == nil {
                self.sensorDataCollection = SensorDataCollection()
                utterance = AVSpeechUtterance(string: "Started")
            }
            utterance.rate = 0.6
            self.synth.speak(utterance)

            sensorComponent.classificationManager.gatherSensorData(toSensorDataCollection: self.sensorDataCollection!)
            self.locationManager.startUpdatingLocation()

            self.player.play()
        } else {
            // tapped finish
            stopRecording()
            
            self.sensorDataCollectionForUpload = self.sensorDataCollection
            self.sensorDataCollection = nil
            let utterance = AVSpeechUtterance(string: "Finished")
            utterance.rate = 0.6
            self.synth.speak(utterance)
            self.performSegue(withIdentifier: "showUpload", sender: self)
        }
        
        self.updateUI()
    }
    
    @IBAction func toggledPredictSwitch(_ sender: AnyObject) {
        self.runPredictionIfEnabled()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let collection = self.sensorDataCollection {
            for loc in locations {
                collection.addLocationIfSufficientlyAccurate(loc)
            }
        }
        if let collection = self.sensorDataCollectionForQuery {
            for loc in locations {
                collection.addLocationIfSufficientlyAccurate(loc)
            }
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    fileprivate var isPredicting: Bool = false
    
    func runPredictionIfEnabled() {
        guard self.predictSwitch.isOn else {
            return
        }
        guard !isPredicting else {
            return
        }
        
        isPredicting = true
        
        self.sensorDataCollectionForQuery = SensorDataCollection()
        self.locationManager.startUpdatingLocation()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending run prediction Background task!")
            
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
        
        activityManager.queryActivityStarting(from: Date(), to: Date().secondsFrom(2), to: OperationQueue.main) { (activity, error) in
            if let theActivity = activity?.first {
                var activityString = ""
                if theActivity.stationary {
                    activityString += "Stationary "
                }
                if theActivity.walking {
                    activityString += "Walking "
                }
                if theActivity.running {
                    activityString += "Running "
                }
                if theActivity.automotive {
                    activityString += "Automotive "
                }
                if theActivity.cycling {
                    activityString += "Cycling "
                }
                if theActivity.unknown {
                    activityString += "Unknown "
                }
                
                switch theActivity.confidence {
                case .high:
                    activityString += "High"
                case .medium:
                    activityString += "Medium"
                case .low:
                    activityString += "Low"
                }
                
                self.activityLabel2.text = activityString
            }
        }
        
        sensorComponent.classificationManager.queryCurrentActivityType(forSensorDataCollection: self.sensorDataCollectionForQuery!) {[weak self] (sensorDataCollection) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPredicting = false
            
            guard let prediction = sensorDataCollection.topActivityTypePrediction else {
                // this should not ever happen.
                DDLogVerbose("No activity type prediction found, continuing to monitor…")
                return
            }
            
            let activityType = prediction.activityType
            let confidence = prediction.confidence.floatValue
            
            strongSelf.sensorDataCollectionForQuery = nil
            if (!strongSelf.isRecording) {
                strongSelf.locationManager.stopUpdatingLocation()
            }
            
            
            let activityString = String(format: "%@ %.1f", activityType.noun, confidence)
            
            strongSelf.activityLabel.text = activityString
            
            let utterance = AVSpeechUtterance(string: activityString)
            utterance.rate = 0.6
            strongSelf.synth.speak(utterance)
            
            let notif = UILocalNotification()
            notif.alertBody = activityString
            notif.category = "generalCategory"
            UIApplication.shared.presentLocalNotificationNow(notif)
            
            if (strongSelf.predictSwitch.isOn) {
                DDLogInfo("Beginning run prediction Background task!")
                strongSelf.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    strongSelf.backgroundTaskID = UIBackgroundTaskInvalid
                })
                
                strongSelf.perform(Selector("runPredictionIfEnabled"), with: nil, afterDelay: 2.0)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showUpload") {
            if let vc = segue.destination as? UploadViewController,
                let sensorData = self.sensorDataCollectionForUpload {
                vc.sensorDataCollection = sensorData
            }
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)
            self.sensorDataCollectionForUpload = nil
            self.sensorDataCollection = nil
            self.updateUI()
        }
    }
}

