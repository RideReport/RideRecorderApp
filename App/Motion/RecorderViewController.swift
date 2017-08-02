//
//  RecorderViewController.swift
//  Ride
//
//  Created by William Henderson on 7/31/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import CoreLocation
import CoreMotion
import MediaPlayer

class RecorderViewController: UIViewController, CLLocationManagerDelegate {
    fileprivate var backgroundTaskID = UIBackgroundTaskInvalid
    public var formData : [String: Any]!
    
    var sensorComponent: SensorManagerComponent!

    fileprivate var isRecording: Bool = false
    fileprivate var activityManager: CMMotionActivityManager!
    fileprivate var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    fileprivate var sensorDataCollectionForUpload : SensorDataCollection?
    fileprivate var sensorDataCollection : SensorDataCollection?
    fileprivate var startDate: Date?
    fileprivate var sensorDataCollectionForQuery : SensorDataCollection?
    
    fileprivate var locationManager : CLLocationManager!
    fileprivate var player: AVAudioPlayer!
    
    @IBOutlet weak var helperText: UILabel!
    @IBOutlet weak var predictSwitch: UISwitch!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var activityLabel2: UILabel!

    @IBOutlet weak var startStopButton: UIBarButtonItem!
    @IBOutlet weak var pauseDeleteButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        self.predictSwitch.isOn = false
        
        self.sensorComponent = SensorManagerComponent.shared
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
                self.tappedPauseCancel(self)
            } else {
                self.tappedResumeFinish(self)
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
        
        self.startRecording()
        self.updateUI()
    }
    
    func updateUI() {
        if (self.isRecording) {
            self.startStopButton.title = "Finish"
            self.helperText.text = "Tap 'Finish' when you end your trip, change modes or change the position of your phone (for example, taking it out of your bag)."
            self.pauseDeleteButton.title = "Pause"
            self.pauseDeleteButton.isEnabled = true
        } else {
            // paused
            self.title = "Paused"
            self.pauseDeleteButton.title = "Delete"
            self.pauseDeleteButton.tintColor = UIColor.red
            self.startStopButton.title = "Resume"
            self.helperText.text = "Tap 'Resume' to keep recording this trip, or 'Delete' to discard it."
            self.pauseDeleteButton.isEnabled = true
        }
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
        if (self.player.isPlaying) {
            self.player.pause()
        }
    }
    
    private func startRecording() {
        self.isRecording = true
        
        if self.sensorDataCollection == nil {
            self.sensorDataCollection = SensorDataCollection()
            self.startDate = Date()
        }
        
        sensorComponent.classificationManager.gatherSensorData(toSensorDataCollection: self.sensorDataCollection!)
        self.locationManager.startUpdatingLocation()
        
        if let activityNumber = formData["mode"] as? NSNumber, let activityType = ActivityType(rawValue: activityNumber.int16Value), activityType == ActivityType.walking {
            // only enable headphone paddle for walking
            self.player.play()
        }
        
    }
    
    @IBAction func tappedPauseCancel(_ sender: AnyObject) {
        if (self.isRecording) {
            // tapped pause
            stopRecording()
            
            let utterance = AVSpeechUtterance(string: "Paused")
            utterance.rate = 0.6
            self.synth.speak(utterance)
        } else {
            self.sensorDataCollectionForUpload = nil
            self.sensorDataCollection = nil
            self.startDate = nil
            
            self.navigationController?.popViewController(animated: true)
        }
        
        self.updateUI()
    }
    
    @IBAction func tappedResumeFinish(_ sender: AnyObject) {
        if (!self.isRecording) {
            // tapped resume
            startRecording()
            var utterance = AVSpeechUtterance(string: "Resumed")
            utterance.rate = 0.6
            self.synth.speak(utterance)
        } else {
            // tapped finish
            stopRecording()
            
            self.sensorDataCollectionForUpload = self.sensorDataCollection
            self.sensorDataCollection = nil
            self.startDate = nil
            
            self.performSegue(withIdentifier: "showUpload", sender: self)
        }
        
        self.updateUI()
    }
    
    @IBAction func toggledPredictSwitch(_ sender: AnyObject) {
        self.runPredictionIfEnabled()
    }
    
    private func stringFromTimeInterval(interval: TimeInterval) -> String {
        let ti = NSInteger(interval)
        
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)
        
        return String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let date = self.startDate {
            self.title = stringFromTimeInterval(interval: Date().timeIntervalSince(date))
        }
        
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
                vc.formData = self.formData
                vc.sensorDataCollection = sensorData
            }
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)
            self.sensorDataCollectionForUpload = nil
            self.sensorDataCollection = nil
        }
    }
    
}
