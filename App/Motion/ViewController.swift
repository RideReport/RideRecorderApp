//
//  ViewController.swift
//  Motion
//
//  Created by William Henderson on 3/2/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftChart
import CoreLocation
import MediaPlayer
import SwiftyJSON

class ViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate {
    private var backgroundTaskID = UIBackgroundTaskInvalid

    private var isRecording: Bool = false
    private var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    private var sensorDataCollection : SensorDataCollection?
    private var sensorDataCollectionForQuery : SensorDataCollection?
    private var sensorDataCollectionForUpload : SensorDataCollection?
    
    private var locationManager : CLLocationManager!
    private var player: AVAudioPlayer!

    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var predictSwitch: UISwitch!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var activityLabel2: UILabel!
    @IBOutlet weak var lineChart: Chart!
    
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var notesTextField: UITextField!
    @IBOutlet weak var modeSelectorView: ModeSelectorView!
    @IBOutlet weak var uploadButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.predictSwitch.on = false
        
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.Fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        let url = NSBundle.mainBundle().URLForResource("silence", withExtension: ".mp3")
        try! self.player = AVAudioPlayer(contentsOfURL: url!)
        self.player.numberOfLoops = -1
        
        self.notesTextField.delegate = self
        
        // hack to take control of remote
        self.player.play()
        self.player.pause()
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try! AVAudioSession.sharedInstance().setActive(true)
        
        
        MPRemoteCommandCenter.sharedCommandCenter().togglePlayPauseCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            self.tappedStartPause(self)
            
            return MPRemoteCommandHandlerStatus.Success
        }
        
        MPRemoteCommandCenter.sharedCommandCenter().nextTrackCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            self.predictSwitch.on = !self.predictSwitch.on

            var utteranceString = ""
            if self.predictSwitch.on {
                utteranceString = "Prediction enabled"
            } else {
                utteranceString = "Prediction disabled"
            }
            let utterance = AVSpeechUtterance(string: utteranceString)
            utterance.rate = 0.6
            self.synth.speakUtterance(utterance)
            
            self.runPredictionIfEnabled()
            
            return MPRemoteCommandHandlerStatus.Success
        }
        
        self.updateUI()
    }
    
    @IBAction func switchedModeSelectorView(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            updateUI()
        }
    }
    
    @IBAction func tappedUploadButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            var metadata: [String: AnyObject] = [:]
            if let notes = self.notesTextField.text where notes.characters.count > 0 {
                metadata["notes"] = notes
            }
            
            if let identifier = UIDevice.currentDevice().identifierForVendor {
                metadata["identifier"] = identifier.UUIDString
            }
            
            metadata["reportedActivityType"] = NSNumber(short: self.modeSelectorView.selectedMode.rawValue)
            
            CoreDataManager.sharedManager.saveContext()

            APIClient.sharedClient.uploadSensorDataCollection(collection, withMetadata: metadata)
            self.notesTextField.text = ""
            self.sensorDataCollectionForUpload = nil
            self.sensorDataCollection = nil
            self.notesTextField.resignFirstResponder()
            self.updateUI()
        }
    }
    
    func updateUI() {
        if (self.isRecording) {

            self.startStopButton.setTitle("Pause", forState: UIControlState.Normal)
            self.uploadView.hidden = true
            self.modeSelectorView.selectedSegmentIndex = -1
            self.activityLabel.hidden = false
            self.startStopButton.hidden = false
            self.cancelButton.hidden = false
            self.finishButton.hidden = false
            self.cancelButton.setTitle("Cancel", forState: UIControlState.Normal)
        } else {
            if let collection = self.sensorDataCollectionForUpload {
                // prep for upload
                self.uploadView.hidden = false
                self.startStopButton.hidden = true
                self.activityLabel.hidden = true
                self.cancelButton.hidden = false
                self.finishButton.hidden = true
                self.cancelButton.setTitle("Delete", forState: UIControlState.Normal)
                
                guard self.modeSelectorView.selectedMode != .Unknown else {
                    self.uploadButton.enabled = false
                    return
                }
                
                self.uploadButton.enabled = true
            } else if (self.sensorDataCollection != nil){
                // paused
                self.uploadView.hidden = true
                self.modeSelectorView.selectedSegmentIndex = -1
                self.activityLabel.hidden = false
                self.startStopButton.hidden = false
                self.cancelButton.hidden = false
                self.finishButton.hidden = false
                
                self.startStopButton.setTitle("Resume", forState: UIControlState.Normal)
                self.cancelButton.setTitle("Cancel", forState: UIControlState.Normal)
            } else {
                // init state
                self.uploadView.hidden = true
                self.modeSelectorView.selectedSegmentIndex = -1
                self.activityLabel.hidden = false
                self.startStopButton.hidden = false
                self.cancelButton.hidden = true
                self.finishButton.hidden = true
                
                self.startStopButton.setTitle("Start", forState: UIControlState.Normal)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func tappedFinish(sender: AnyObject) {
        if (self.isRecording) {
            // stop recording first
            self.tappedStartPause(self)
        }
        
        self.sensorDataCollectionForUpload = self.sensorDataCollection
        self.sensorDataCollection = nil
        
        self.updateUI()
    }
    
    @IBAction func tappedCancelDelete(sender: AnyObject) {
        if (self.isRecording) {
            // stop recording first
            self.tappedStartPause(self)
        }
        
        self.sensorDataCollectionForUpload = nil
        self.sensorDataCollection = nil
        
        self.updateUI()
    }
    
    @IBAction func tappedStartPause(sender: AnyObject) {
        if (!self.isRecording) {
            // tapped start or resume
            self.isRecording = true
            var utterance = AVSpeechUtterance(string: "Resumed")

            if self.sensorDataCollection == nil {
                self.sensorDataCollection = SensorDataCollection()
                utterance = AVSpeechUtterance(string: "Started")
            }
            utterance.rate = 0.6
            self.synth.speakUtterance(utterance)

            
            MotionManager.sharedManager.gatherSensorData(toSensorDataCollection: self.sensorDataCollection!)
            self.locationManager.startUpdatingLocation()

            self.player.play()
        } else {
            // tapped pause
            self.isRecording = false
            CoreDataManager.sharedManager.saveContext()
            
            MotionManager.sharedManager.stopGatheringSensorData()
            if (self.sensorDataCollectionForQuery == nil) {
                self.locationManager.stopUpdatingLocation()
            }
            self.player.pause()
            
            let utterance = AVSpeechUtterance(string: "Paused")
            utterance.rate = 0.6
            self.synth.speakUtterance(utterance)
        }
        
        self.updateUI()
    }
    
    @IBAction func toggledPredictSwitch(sender: AnyObject) {
        self.runPredictionIfEnabled()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
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
        
        CoreDataManager.sharedManager.saveContext()
    }
    
    func runPredictionIfEnabled() {
        if (!self.predictSwitch.on) {
            return
        }
        
        self.sensorDataCollectionForQuery = SensorDataCollection()
        self.locationManager.startUpdatingLocation()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
        
        MotionManager.sharedManager.queryCurrentActivityType(forSensorDataCollection: self.sensorDataCollectionForQuery!) {[weak self] (sensorDataCollection) -> Void in
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
            
            var activityString = ""
            
            switch activityType {
            case .Automotive:
            activityString = "Driving"
            case .Cycling:
            activityString = "Biking"
            case .Running:
            activityString = "Running"
            case .Bus:
            activityString = "Bus"
            case .Rail:
            activityString = "Train"
            case .Walking:
            activityString = "Walking"
            case .Stationary:
            activityString = "Stationary"
            case .Aviation:
            activityString = "Flying"
            case .Unknown:
            activityString = "Unknown"
            }
            
            activityString = activityString + " " + String(confidence)
            
            strongSelf.activityLabel.text = activityString
            
            let utterance = AVSpeechUtterance(string: activityString)
            utterance.rate = 0.6
            strongSelf.synth.speakUtterance(utterance)
            
            let notif = UILocalNotification()
            notif.alertBody = activityString
            notif.category = "generalCategory"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            
            if (strongSelf.predictSwitch.on) {
                strongSelf.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                    strongSelf.backgroundTaskID = UIBackgroundTaskInvalid
                })
                
                strongSelf.performSelector(Selector("runPredictionIfEnabled"), withObject: nil, afterDelay: 2.0)
            }
            
//            let series = ChartSeries(debugData)
//            series.color = ChartColors.greenColor()
//            strongSelf.lineChart.removeSeries()
//            strongSelf.lineChart.addSeries(series)
            
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

