//
//  ViewController.swift
//  Motion
//
//  Created by William Henderson on 3/2/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import SwiftyJSON
import Eureka
import CoreMotion
import AVFoundation
import RouteRecorder
import CocoaLumberjack

class ViewController: FormViewController {
    @IBOutlet weak var predictSwitch: UISwitch!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var activityLabel2: UILabel!
    
    fileprivate var activityManager: CMMotionActivityManager!
    fileprivate var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()
    fileprivate var aggregatorForQuery : PredictionAggregator?
    
    private var formDataForUpload: [String: Any] = [:]
    private let availableModes = [ActivityType.automotive, ActivityType.bus, ActivityType.rail, ActivityType.walking, ActivityType.running, ActivityType.cycling]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.predictSwitch.isOn = false        
        self.activityManager = CMMotionActivityManager()

        setupForm()
    }
    
    func setupForm() {
        let labelRow = LabelRow(){
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value == nil
            })
        }
        form +++ Section(header: "What is your email address?", footer: "We may email you with questions about your trip.") {
            $0.header?.height = { 36 }
        }
            <<< EmailRow("email"){
                $0.placeholder = "me@them.com"
                $0.value = UserDefaults.standard.string(forKey: "email")
            }

        
        form +++ Section(header: "What mode of transportation are you going to use?", footer: "Just one mode please! Please start a new trip recording if you switch modes or change how you are carying your phone.") {
            $0.header?.height = { 60 }
        }
            <<< labelRow
            <<< SegmentedRow<ActivityType>(){
                $0.tag = "mode"
                $0.options = availableModes
                $0.onChange({ (row) in
                    if let activity = row.value {
                        labelRow.title = activity.noun
                        labelRow.updateCell()
                        row.section?.footer = nil
                        row.section?.reload()
                    }
                })
        }
        
        form +++ Section("Tell us about your drive") {
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.automotive
            })
            $0.tag = "driving-details"
            }
            <<< SegmentedRow<String>(){
                $0.tag = "driving-or-passenger"
                $0.options = ["Driving", "Passenger"]
            }
            
            <<< SegmentedRow<String>(){
                $0.tag = "transmission"
                $0.title = "Transmission Type"
                $0.options = ["Automatic", "Manual"]
        }
        
        form +++ Section("Tell us about your bike") {
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.cycling
            })
            $0.tag = "cycling-details"
            }
            <<< PushRow<String>(){
                $0.tag = "bike-type"
                $0.title = "Bike Type"
                $0.options = ["Normal", "Longtail", "Box", "Trike", "Other"]
            }
            
            <<< TextRow(){
                $0.hidden = Condition.function(["bike-type"], { form in
                    return (form.rowBy(tag: "bike-type") as? PushRow<String>)?.value != "Other"
                })
                $0.placeholder = "Describe your bike"
            }
            
            <<< SegmentedRow<String>(){
                $0.tag = "electric-assist"
                $0.title = "Electric assist?"
                $0.options = ["Yes", "No"]
        }
        
        form +++ Section("How will you carry your phone?") {
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.automotive
            })
            $0.tag = "automotive-phone-carry"
            }
            
            <<< PushRow<String> {
                $0.tag = "automotive-phone-loc"
                $0.title = "Phone Location"
                $0.options = ["Dashboard mount", "Loose on Seat/Console", "Pants Pocket", "Other"]
            }
            <<< SegmentedRow<String>(){
                $0.hidden = Condition.function(["automotive-phone-loc"], { form in
                    return (form.rowBy(tag: "automotive-phone-loc") as? PushRow<String>)?.value != "Pants Pocket"
                })
                $0.options = ["Left", "Right", "Left Back", "Right Back"]
                $0.tag = "automotive-pocket"
            }
            <<< TextRow(){
                $0.hidden = Condition.function(["automotive-phone-loc"], { form in
                    return (form.rowBy(tag: "automotive-phone-loc") as? PushRow<String>)?.value != "Other"
                })
                $0.tag = "automotive-other-description"
                $0.placeholder = "Describe"
        }
        
        form +++ Section("How will you carry your phone?") {
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.cycling
            })
            $0.tag = "bike-phone-carry"
            }
            
            <<< PushRow<String> {
                $0.title = "Phone Location"
                $0.tag = "bike-phone-loc"
                $0.options = ["Pants Pocket", "Handlebar Mount", "Backpack", "Pannier", "Font bag/basket", "Other"]
            }
            <<< SegmentedRow<String>(){
                $0.hidden = Condition.function(["bike-phone-loc"], { form in
                    return (form.rowBy(tag: "bike-phone-loc") as? PushRow<String>)?.value != "Pants Pocket"
                })
                $0.options = ["Left", "Right", "Left Back", "Right Back"]
                $0.tag = "bike-pocket"
            }
            <<< TextRow(){
                $0.hidden = Condition.function(["bike-phone-loc"], { form in
                    return (form.rowBy(tag: "bike-phone-loc") as? PushRow<String>)?.value != "Other"
                })
                $0.tag = "bike-other-description"
                $0.placeholder = "Describe"
        }
        
        
        form +++ Section("How will you carry your phone?") {
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.bus &&
                    (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.rail &&
                    (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.stationary &&
                    (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.walking
            })
            $0.tag = "walk-transit-phone-carry"
            }
            
            <<< PushRow<String> {
                $0.tag = "walk-transit-phone-loc"
                $0.title = "Phone Location"
                $0.options = ["Pants Pocket", "In Hand", "Backpack", "Hand bag", "Other"]
            }
            <<< SegmentedRow<String>(){
                $0.hidden = Condition.function(["walk-transit-phone-loc"], { form in
                    return (form.rowBy(tag: "walk-transit-phone-loc") as? PushRow<String>)?.value != "Pants Pocket"
                })
                $0.tag = "walk-transit-pocket"
                $0.options = ["Left", "Right", "Left Back", "Right Back"]
            }
            <<< SegmentedRow<String>(){
                $0.hidden = Condition.function(["walk-transit-phone-loc"], { form in
                    return (form.rowBy(tag: "walk-transit-phone-loc") as? PushRow<String>)?.value != "In Hand"
                })
                $0.tag = "walk-transit-hand"
                $0.options = ["Left", "Right"]
            }
            <<< SegmentedRow<String>(){
                $0.hidden = Condition.function(["walk-transit-phone-loc"], { form in
                    return (form.rowBy(tag: "walk-transit-phone-loc") as? PushRow<String>)?.value != "In Hand"
                })
                $0.title = "Were you using your phone?"
                $0.tag = "walk-transit-using-phone"
                $0.options = ["Yes", "No"]
            }
            <<< TextRow(){
                $0.hidden = Condition.function(["walk-transit-phone-loc"], { form in
                    return (form.rowBy(tag: "walk-transit-phone-loc") as? PushRow<String>)?.value != "Other"
                })
                $0.tag = "walk-transit-other-description"
                $0.placeholder = "Describe"
        }
        
        form +++ Section("How will you carry your phone?") {
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.running
            })
            $0.tag = "running-phone-carry"
            }
            
            <<< PushRow<String> {
                $0.tag = "running-phone-loc"
                $0.title = "Phone Location"
                $0.options = ["Pants", "On Body", "On Arm", "In Hand", "Other"]
            }
            <<< SegmentedRow<String>(){
                $0.hidden = Condition.function(["running-phone-loc"], { form in
                    return (form.rowBy(tag: "running-phone-loc") as? PushRow<String>)?.value != "Pants"
                })
                $0.tag = "run-pocket"
                $0.options = ["Left", "Right", "Left Back", "Right Back"]
            }
            <<< SegmentedRow<String>(){
                $0.hidden = Condition.function(["running-phone-loc"], { form in
                    return (form.rowBy(tag: "running-phone-loc") as? PushRow<String>)?.value != "In Hand" &&
                        (form.rowBy(tag: "running-phone-loc") as? PushRow<String>)?.value != "On Arm"
                })
                $0.tag = "running-hand-arm"
                $0.options = ["Left", "Right"]
            }
            <<< TextRow(){
                $0.hidden = Condition.function(["running-phone-loc"], { form in
                    return (form.rowBy(tag: "running-phone-loc") as? PushRow<String>)?.value != "Other"
                })
                $0.tag = "running-other-description"
                $0.placeholder = "Describe"
        }
        
        form +++ ButtonRow {
            $0.title = "Start Recording"
            }.onCellSelection { [weak self] (cell, row) in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.formDataForUpload = [:]
                
                let formDataOptionals = strongSelf.form.values(includeHidden: false)
                for key in formDataOptionals.keys {
                    if formDataOptionals[key]! == nil {
                        let alert = UIAlertView(title:nil, message: "Please provide an answer for every field!", delegate: nil, cancelButtonTitle:"Got it")
                        alert.show()
                        
                        return
                    } else {
                        let obj: Any = formDataOptionals[key]!
                        if let activity = obj as? ActivityType {
                            strongSelf.formDataForUpload[key] = activity.numberValue
                        } else {
                            if let email = obj as? String, key == "email" {
                                UserDefaults.standard.set(email, forKey: "email")
                                UserDefaults.standard.synchronize()
                            }
                            
                            strongSelf.formDataForUpload[key] = obj
                        }
                    }
                }
                
                strongSelf.performSegue(withIdentifier: "showRecording", sender: self)
        }
    }
    
    
    @IBAction func toggledPredictSwitch(_ sender: AnyObject) {
        self.runPredictionIfEnabled()
    }

    
    fileprivate var isPredicting: Bool = false
    
    @objc func runPredictionIfEnabled() {
        guard self.predictSwitch.isOn else {
            return
        }
        guard !isPredicting else {
            return
        }
        
        isPredicting = true
        
        self.aggregatorForQuery = PredictionAggregator()
        
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
        
        RouteRecorder.shared.classificationManager.predictCurrentActivityType(predictionAggregator: self.aggregatorForQuery!) {[weak self] (aggregator) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPredicting = false
            
            guard let predictedActivity = aggregator.aggregatePredictedActivity else {
                // this should not ever happen.
                DDLogVerbose("No activity type prediction found, continuing to monitor…")
                return
            }
            
            let activityType = predictedActivity.activityType
            let confidence = predictedActivity.confidence
            
            strongSelf.aggregatorForQuery = nil
            
            
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
                strongSelf.perform(Selector("runPredictionIfEnabled"), with: nil, afterDelay: 2.0)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showRecording") {
            if let vc = segue.destination as? RecorderViewController {
                vc.formData = self.formDataForUpload
                self.form.removeAll()
                self.setupForm()
            }
        }
    }

}

