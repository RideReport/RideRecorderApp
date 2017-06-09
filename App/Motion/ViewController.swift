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

class ViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate {
    fileprivate var backgroundTaskID = UIBackgroundTaskInvalid
    
    var sensorComponent: SensorManagerComponent!

    fileprivate var isRecording: Bool = false
    fileprivate var activityManager: CMMotionActivityManager!
    fileprivate var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    fileprivate var sensorDataCollection : SensorDataCollection?
    fileprivate var sensorDataCollectionForQuery : SensorDataCollection?
    fileprivate var sensorDataCollectionForUpload : SensorDataCollection?
    
    fileprivate var locationManager : CLLocationManager!
    fileprivate var player: AVAudioPlayer!

    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var predictSwitch: UISwitch!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var activityLabel2: UILabel!
    
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var notesTextField: UITextField!
    @IBOutlet weak var modeSelectorView: ModeSelectorView!
    @IBOutlet weak var uploadButton: UIButton!
    
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
        
        self.notesTextField.delegate = self
        
        // hack to take control of remote
        self.player.play()
        self.player.pause()
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try! AVAudioSession.sharedInstance().setActive(true)
        
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget (handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.tappedStartPause(self)
            
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
    
    @IBAction func switchedModeSelectorView(_ sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            updateUI()
        }
    }
    
    @IBAction func tappedUploadButton(_ sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            var metadata: [String: Any] = [:]
            if let notes = self.notesTextField.text, notes.characters.count > 0 {
                metadata["notes"] = notes
            }
            
            if let identifier = UIDevice.current.identifierForVendor {
                metadata["identifier"] = identifier.uuidString
            }
            
            metadata["reportedActivityType"] = NSNumber(value: self.modeSelectorView.selectedMode.rawValue as Int16)
            
            CoreDataManager.shared.saveContext()

            APIClient.shared.uploadSensorDataCollection(collection, withMetadata: metadata)
            self.notesTextField.text = ""
            self.sensorDataCollectionForUpload = nil
            self.sensorDataCollection = nil
            self.notesTextField.resignFirstResponder()
            self.updateUI()
        }
    }
    
    func updateUI() {
        if (self.isRecording) {

            self.startStopButton.setTitle("Pause", for: UIControlState())
            self.uploadView.isHidden = true
            self.modeSelectorView.selectedSegmentIndex = -1
            self.activityLabel.isHidden = false
            self.startStopButton.isHidden = false
            self.cancelButton.isHidden = false
            self.finishButton.isHidden = false
            self.cancelButton.setTitle("Cancel", for: UIControlState())
        } else {
            if let collection = self.sensorDataCollectionForUpload {
                // prep for upload
                self.uploadView.isHidden = false
                self.startStopButton.isHidden = true
                self.activityLabel.isHidden = true
                self.cancelButton.isHidden = false
                self.finishButton.isHidden = true
                self.cancelButton.setTitle("Delete", for: UIControlState())
                
                guard self.modeSelectorView.selectedMode != .unknown else {
                    self.uploadButton.isEnabled = false
                    return
                }
                
                self.uploadButton.isEnabled = true
            } else if (self.sensorDataCollection != nil){
                // paused
                self.uploadView.isHidden = true
                self.modeSelectorView.selectedSegmentIndex = -1
                self.activityLabel.isHidden = false
                self.startStopButton.isHidden = false
                self.cancelButton.isHidden = false
                self.finishButton.isHidden = false
                
                self.startStopButton.setTitle("Resume", for: UIControlState())
                self.cancelButton.setTitle("Cancel", for: UIControlState())
            } else {
                // init state
                self.uploadView.isHidden = true
                self.modeSelectorView.selectedSegmentIndex = -1
                self.activityLabel.isHidden = false
                self.startStopButton.isHidden = false
                self.cancelButton.isHidden = true
                self.finishButton.isHidden = true
                
                self.startStopButton.setTitle("Start", for: UIControlState())
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func tappedFinish(_ sender: AnyObject) {
        if (self.isRecording) {
            // stop recording first
            self.tappedStartPause(self)
        }
        
        self.sensorDataCollectionForUpload = self.sensorDataCollection
        self.sensorDataCollection = nil
        
        self.updateUI()
    }
    
    @IBAction func tappedCancelDelete(_ sender: AnyObject) {
        if (self.isRecording) {
            // stop recording first
            self.tappedStartPause(self)
        }
        
        self.sensorDataCollectionForUpload = nil
        self.sensorDataCollection = nil
        
        self.updateUI()
    }
    
    @IBAction func tappedStartPause(_ sender: AnyObject) {
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

            
            //sensorComponent.classificationManager.gatherSensorData(toSensorDataCollection: self.sensorDataCollection!)
            self.locationManager.startUpdatingLocation()

            self.player.play()
        } else {
            // tapped pause
            self.isRecording = false
            CoreDataManager.shared.saveContext()
            
            //sensorComponent.classificationManager.stopGatheringSensorData()
            if (self.sensorDataCollectionForQuery == nil) {
                self.locationManager.stopUpdatingLocation()
            }
            self.player.pause()
            
            let utterance = AVSpeechUtterance(string: "Paused")
            utterance.rate = 0.6
            self.synth.speak(utterance)
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
    
    func runPredictionIfEnabled() {
        if (!self.predictSwitch.isOn) {
            return
        }
        
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
                activityString += String(format: " %1f", theActivity.confidence.rawValue)
                self.activityLabel2.text = activityString
            }
        }
        
        sensorComponent.classificationManager.queryCurrentActivityType(forSensorDataCollection: self.sensorDataCollectionForQuery!) {[weak self] (sensorDataCollection) -> Void in
            guard let strongSelf = self else {
            return
            }
            
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
            
            
            let activityString = activityType.noun + " " + String(confidence)
            
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

