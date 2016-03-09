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
    private var sensorDataCollection : SensorDataCollection!
    
    private var sensorDataCollectionForUpload : SensorDataCollection?
    
    private var locationManager : CLLocationManager!
    private var player: AVAudioPlayer!

    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var lineChart: Chart!
    
    @IBOutlet weak var currentDataSetView: UIView!
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
        
        self.sensorDataCollection = SensorDataCollection()
        
        let url = NSBundle.mainBundle().URLForResource("silence", withExtension: ".mp3")
        try! self.player = AVAudioPlayer(contentsOfURL: url!)
        self.player.numberOfLoops = -1
        self.player.play()
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try! AVAudioSession.sharedInstance().setActive(true)
        
        
        MPRemoteCommandCenter.sharedCommandCenter().togglePlayPauseCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            self.startStop(self)
            
            return MPRemoteCommandHandlerStatus.Success
        }
        
        MPRemoteCommandCenter.sharedCommandCenter().nextTrackCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            self.runQuery()
            
            return MPRemoteCommandHandlerStatus.Success
        }
        
        self.updateCollectionUI()
    }
    
    @IBAction func tappedCarButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Automotive.rawValue)
            updateCollectionUI()
        }
    }
    
    @IBAction func tappedWalkButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Walking.rawValue)
            updateCollectionUI()
        }
    }
    
    @IBAction func tappedBusButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Bus.rawValue)
            updateCollectionUI()
        }
    }
    
    @IBAction func tappedBikeButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Cycling.rawValue)
            updateCollectionUI()
        }
    }
    
    @IBAction func tappedTrainButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            collection.actualActivityType = NSNumber(short: Trip.ActivityType.Rail.rawValue)
            updateCollectionUI()
        }
    }
    
    @IBAction func tappedUploadButton(sender: AnyObject) {
        if let collection = self.sensorDataCollectionForUpload {
            CoreDataManager.sharedManager.saveContext()
            APIClient.sharedClient.uploadSensorDataCollection(collection)
            self.sensorDataCollectionForUpload = nil
            self.updateCollectionUI()
        }
    }
    
    func updateCollectionUI() {
        if let collection = self.sensorDataCollectionForUpload {
            self.currentDataSetView.hidden = false
            self.startStopButton.hidden = true
            self.activityLabel.hidden = true
            
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
            
        } else {
            self.startStopButton.hidden = false
            self.activityLabel.hidden = false
            self.currentDataSetView.hidden = true
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func tappedCancel(sender: AnyObject) {
        MotionManager.sharedManager.stopGatheringSensorData()
        self.locationManager.stopUpdatingLocation()
        
        CoreDataManager.sharedManager.saveContext()
        self.sensorDataCollectionForUpload = nil
        self.sensorDataCollection = SensorDataCollection()
        self.updateCollectionUI()
        
        self.startStopButton.setTitle("Start", forState: UIControlState.Normal)
        self.cancelButton.hidden = true
    }
    
    @IBAction func startStop(sender: AnyObject) {
        self.isRecording = !self.isRecording
        
        if (self.isRecording) {
            MotionManager.sharedManager.gatherSensorData(toSensorDataCollection: self.sensorDataCollection)
            self.locationManager.startUpdatingLocation()
            self.startStopButton.setTitle("Finish", forState: UIControlState.Normal)
            self.cancelButton.hidden = false
        } else {
            CoreDataManager.sharedManager.saveContext()
            self.sensorDataCollectionForUpload = self.sensorDataCollection
            
            MotionManager.sharedManager.stopGatheringSensorData()
            self.locationManager.stopUpdatingLocation()
            self.sensorDataCollection = SensorDataCollection()
            self.startStopButton.setTitle("Start", forState: UIControlState.Normal)
            self.cancelButton.hidden = true
        }
        
        self.updateCollectionUI()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            self.sensorDataCollection.addLocation(loc)
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

