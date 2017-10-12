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
import MediaPlayer
import RouteRecorder

class RecorderViewController: UIViewController, CLLocationManagerDelegate {
    fileprivate var backgroundTaskID = UIBackgroundTaskInvalid
    public var formData : [String: Any]!

    fileprivate var isRecording: Bool = false
    fileprivate var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    fileprivate var aggregatorForUpload : PredictionAggregator?
    fileprivate var aggregator : PredictionAggregator?
    fileprivate var startDate: Date?
    
    fileprivate var locationManager : CLLocationManager!
    fileprivate var player: AVAudioPlayer?
    
    @IBOutlet weak var helperText: UILabel!

    @IBOutlet weak var startStopButton: UIBarButtonItem!
    @IBOutlet weak var pauseDeleteButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        self.startRecording()
        self.updateUI()
        
        if let activityNumber = formData["mode"] as? NSNumber, let activityType = ActivityType(rawValue: activityNumber.int16Value), activityType == ActivityType.walking {
            // only enable headphone paddle for walking
            
            let url = Bundle.main.url(forResource: "silence", withExtension: ".mp3")
            if let player = try? AVAudioPlayer(contentsOf: url!) {
                 self.player = player
                player.numberOfLoops = -1
            
                // hack to take control of remote
                player.play()
            }
            
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
            
//            MPRemoteCommandCenter.shared().nextTrackCommand.addTarget (handler: { (event) -> MPRemoteCommandHandlerStatus in
//                self.predictSwitch.isOn = !self.predictSwitch.isOn
//                
//                var utteranceString = ""
//                if self.predictSwitch.isOn {
//                    utteranceString = "Prediction enabled"
//                } else {
//                    utteranceString = "Prediction disabled"
//                }
//                let utterance = AVSpeechUtterance(string: utteranceString)
//                utterance.rate = 0.6
//                self.synth.speak(utterance)
//                
//                self.runPredictionIfEnabled()
//                
//                return MPRemoteCommandHandlerStatus.success
//            })
        }
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
        
        RouteRecorder.shared.classificationManager.stopGatheringSensorData()
        self.locationManager.stopUpdatingLocation()

        if let player = self.player, player.isPlaying {
            player.pause()
        }
    }
    
    private func startRecording() {
        self.isRecording = true
        
        if self.aggregator == nil {
            self.aggregator = PredictionAggregator()
            self.startDate = Date()
        }
        
        RouteRecorder.shared.classificationManager.gatherSensorData(predictionAggregator: self.aggregator!)
        self.locationManager.startUpdatingLocation()
    }
    
    @IBAction func tappedPauseCancel(_ sender: AnyObject) {
        if (self.isRecording) {
            // tapped pause
            stopRecording()
            
            let utterance = AVSpeechUtterance(string: "Paused")
            utterance.rate = 0.6
            self.synth.speak(utterance)
        } else {
            self.aggregatorForUpload = nil
            self.aggregator = nil
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
            
            self.aggregatorForUpload = self.aggregator
            self.aggregator = nil
            self.startDate = nil
            
            self.performSegue(withIdentifier: "showUpload", sender: self)
        }
        
        self.updateUI()
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
        
//        if let aggregator = self.aggregator {
//            for loc in locations {
//                aggregator.addLocationIfSufficientlyAccurate(loc)
//            }
//        }
//        if let aggregator = self.aggregatorForUpload {
//            for loc in locations {
//                aggregator.addLocationIfSufficientlyAccurate(loc)
//            }
//        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showUpload") {
            if let vc = segue.destination as? UploadViewController,
                let aggregator = self.aggregatorForUpload {
                vc.formData = self.formData
                vc.aggregator = aggregator
            }
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)
            self.aggregatorForUpload = nil
            self.aggregator = nil
        }
    }
    
}
