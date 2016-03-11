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

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    private var isRecording: Bool = false
    private var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    private var sensorDataCollection : SensorDataCollection?
    private var sensorDataCollectionForUpload : SensorDataCollection?
    
    private var locationManager : CLLocationManager!
    private var player: AVAudioPlayer!

    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var lineChart: Chart!
    
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var notesTextField: UITextField!
    @IBOutlet weak var carButton: UIButton!
    @IBOutlet weak var walkButton: UIButton!
    @IBOutlet weak var bikeButton: UIButton!
    @IBOutlet weak var busButton: UIButton!
    @IBOutlet weak var railButton: UIButton!
    @IBOutlet weak var uploadButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
            self.runQuery()
            
            return MPRemoteCommandHandlerStatus.Success
        }
        
        self.updateUI()
    }
    
    @IBAction func tappedCarButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            updateUI()
        }
    }
    
    @IBAction func tappedWalkButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
            updateUI()
        }
    }
    
    @IBAction func tappedBusButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Bus.rawValue)
            updateUI()
        }
    }
    
    @IBAction func tappedBikeButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            updateUI()
        }
    }
    
    @IBAction func tappedTrainButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Rail.rawValue)
            updateUI()
        }
    }
    
    @IBAction func tappedUploadButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            
            CoreDataManager.sharedManager.saveContext()
            APIClient.sharedClient.uploadSensorDataCollection(collection, withNotes: self.notesTextField.text ?? "")
            self.notesTextField.text = ""
            self.sensorDataCollectionForUpload = nil
           self.sensorDataCollection = nil
            self.updateUI()
        }
    }
    
    func updateUI() {
        if (self.isRecording) {

            self.startStopButton.setTitle("Pause", forState: UIControlState.Normal)
            self.uploadView.hidden = true
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
                
                guard let activityType = collection.actualActivityType else {
                    self.uploadButton.enabled = false
                    return
                }
                
                self.uploadButton.enabled = true
                self.carButton.backgroundColor = UIColor.clearColor()
                self.walkButton.backgroundColor = UIColor.clearColor()
                self.busButton.backgroundColor = UIColor.clearColor()
                self.bikeButton.backgroundColor = UIColor.clearColor()
                self.railButton.backgroundColor = UIColor.clearColor()
                
                switch Trip.ActivityType(rawValue: activityType.shortValue)! {
                case .Automotive:
                    self.carButton.backgroundColor = UIColor.greenColor()
                case .Walking:
                    self.walkButton.backgroundColor = UIColor.greenColor()
                case .Bus:
                    self.busButton.backgroundColor = UIColor.greenColor()
                case .Cycling:
                    self.bikeButton.backgroundColor = UIColor.greenColor()
                case .Rail:
                    self.railButton.backgroundColor = UIColor.greenColor()
                default: break
                }
                
            } else if (self.sensorDataCollection != nil){
                // paused
                self.uploadView.hidden = true
                self.activityLabel.hidden = false
                self.startStopButton.hidden = false
                self.cancelButton.hidden = false
                self.finishButton.hidden = false
                
                self.startStopButton.setTitle("Resume", forState: UIControlState.Normal)
                self.cancelButton.setTitle("Cancel", forState: UIControlState.Normal)
            } else {
                // init state
                self.uploadView.hidden = true
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
            if self.sensorDataCollection == nil {
                self.sensorDataCollection = SensorDataCollection()
            }
            
            MotionManager.sharedManager.gatherSensorData(toSensorDataCollection: self.sensorDataCollection!)
            self.locationManager.startUpdatingLocation()

            self.player.play()
            
            let utterance = AVSpeechUtterance(string: "Recording")
            utterance.rate = 0.6
            self.synth.speakUtterance(utterance)
        } else {
            // tapped pause
            self.isRecording = false
            CoreDataManager.sharedManager.saveContext()
            
            MotionManager.sharedManager.stopGatheringSensorData()
            self.locationManager.stopUpdatingLocation()
            self.player.pause()
            
            let utterance = AVSpeechUtterance(string: "Paused")
            utterance.rate = 0.6
            self.synth.speakUtterance(utterance)
        }
        
        self.updateUI()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if self.sensorDataCollection == nil {
            // could happen since didUpdateLocations sometimes keeps getting called for a bit after stopUpdatingLocation is called
            return
        }
        
        for loc in locations {
            self.sensorDataCollection!.addLocation(loc)
        }
        
        CoreDataManager.sharedManager.saveContext()
    }
    
    private func runQuery() {
        let sensorDataCollection = SensorDataCollection()

        MotionManager.sharedManager.queryCurrentActivityType(forSensorDataCollection: sensorDataCollection) {[weak self] (activityType, confidence) -> Void in
            guard let strongSelf = self else {
            return
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
            case .Unknown:
            activityString = "Unknown"
            }
            
            strongSelf.activityLabel.text = activityString
            
            let utterance = AVSpeechUtterance(string: activityString)
            utterance.rate = 0.6
            strongSelf.synth.speakUtterance(utterance)
            
//            let series = ChartSeries(debugData)
//            series.color = ChartColors.greenColor()
//            strongSelf.lineChart.removeSeries()
//            strongSelf.lineChart.addSeries(series)
            
        }
    }
}

