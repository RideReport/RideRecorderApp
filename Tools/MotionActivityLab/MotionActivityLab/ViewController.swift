//
//  ViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 9/23/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import CoreMotion
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var motionTypeLabel: UILabel!
    private var motionActivityManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    
    private var motionBackgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    private var speechSynthesizer : AVSpeechSynthesizer!
    
    private var dateFormatter : NSDateFormatter!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.motionQueue = NSOperationQueue.mainQueue()
        self.motionActivityManager = CMMotionActivityManager()
        
        self.speechSynthesizer = AVSpeechSynthesizer()
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "MM-dd 'at' HH:mm:ss"
        
        self.startCheckingMotionActivity();
        
        let sharedSession = AVAudioSession.sharedInstance();
        sharedSession.setCategory(AVAudioSessionCategoryPlayback, error: nil)
        sharedSession.setActive(true, error: nil)
    }
    
    
    func startCheckingMotionActivity() {
        DDLogWrapper.logVerbose("Checking motion…")
        
        if (self.motionBackgroundTaskID == UIBackgroundTaskInvalid) {
            self.motionBackgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({
                DDLogWrapper.logVerbose("Background task expired! Stoping active tracking check")
                self.motionBackgroundTaskID = UIBackgroundTaskInvalid;
            })
        }
        
        self.motionActivityManager.startActivityUpdatesToQueue(self.motionQueue, withHandler: { (activity) in
            DDLogWrapper.logVerbose(NSString(format: "Activity: %@", activity))
            
            var motionTypeString = ""
            
            if (activity.stationary) {
                motionTypeString = motionTypeString + "Stationary\n"
            } else if (activity.walking) {
                motionTypeString = motionTypeString + "Walking\n"
            } else if (activity.running) {
                motionTypeString = motionTypeString + "Running\n"
            } else if (activity.cycling) {
                motionTypeString = motionTypeString + "Cycling\n"
            } else if (activity.automotive) {
                motionTypeString = motionTypeString + "Automotive\n"
            } else if (activity.unknown) {
                motionTypeString = motionTypeString + "Unknown\n"
            }
            
            let utterance = AVSpeechUtterance(string: motionTypeString)
            self.speechSynthesizer.speakUtterance(utterance)
            
            if (activity.confidence == CMMotionActivityConfidence.Low) {
                self.speechSynthesizer.speakUtterance(AVSpeechUtterance(string: "Low"))
            } else if (activity.confidence == CMMotionActivityConfidence.Medium) {
                self.speechSynthesizer.speakUtterance(AVSpeechUtterance(string: "Medium"))
            } else if (activity.confidence == CMMotionActivityConfidence.High) {
                self.speechSynthesizer.speakUtterance(AVSpeechUtterance(string: "High"))
            }
            
            self.motionTypeLabel.text = motionTypeString
            self.detailsLabel.text = NSString(format: "Confidence: %i\n Started: %@, \nTimestamp: %i", activity.confidence.rawValue, self.dateFormatter.stringFromDate(activity.startDate), activity.timestamp)
        })
    }
    
    @IBAction func logs(sender: AnyObject) {
        UIForLumberjack.sharedInstance().showLogInView(self.view)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

