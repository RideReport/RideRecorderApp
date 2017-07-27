//
//  UploadViewController.swift
//  Ride
//
//  Created by William Henderson on 7/27/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Eureka

class UploadViewController: FormViewController {
    public var sensorDataCollection : SensorDataCollection?
    private let availableModes = [ActivityType.automotive, ActivityType.bus, ActivityType.rail, ActivityType.walking, ActivityType.running, ActivityType.cycling]

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        form +++ Section(header: "What mode of transportation was it?", footer: "Please be sure your trip includes only one mode! Submit major changes during a trip (such as changing how you are carrying the phone) as multiple trips.")
        <<< SegmentedRow<ActivityType>(){
                $0.tag = "mode"
                $0.options = availableModes
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
        
        form +++ Section("How did you carry your phone?") {
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
        
        form +++ Section("How did you carry your phone?") {
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
        
        
        form +++ Section("How did you carry your phone?") {
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
                return (form.rowBy(tag: "walk-transit-phone-loc") as? PushRow<String>)?.value != "Hand"
            })
            $0.tag = "walk-transit-hand"
            $0.options = ["Left", "Right"]
        }
        <<< SegmentedRow<String>(){
            $0.hidden = Condition.function(["walk-transit-phone-loc"], { form in
                return (form.rowBy(tag: "walk-transit-phone-loc") as? PushRow<String>)?.value != "Hand"
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
        
        form +++ Section("How did you carry your phone?") {
            $0.hidden = Condition.function(["mode"], { form in
                return (form.rowBy(tag: "mode") as? SegmentedRow<ActivityType>)?.value != ActivityType.running
            })
            $0.tag = "running-phone-carry"
            }
            
            <<< PushRow<String> {
                $0.tag = "running-phone-loc"
                $0.title = "Phone Location"
                $0.options = ["Pants", "On Body", "On Arm", "Hand", "Other"]
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
                    return (form.rowBy(tag: "running-phone-loc") as? PushRow<String>)?.value != "Hand" &&
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

        form +++ Section("Notes") {
            $0.tag = "notes"
        }
        <<< TextRow(){
            $0.tag = "notes"
            $0.placeholder = "Tell us anything else notable about the trip"
        }
        
        form +++ ButtonRow {
            $0.title = "Upload"
        }.onCellSelection { [weak self] (cell, row) in
            guard let strongSelf = self else {
                return
            }
            
            if let collection = strongSelf.sensorDataCollection {
                var formDataOptionals: [String: Any?] = strongSelf.form.values(includeHidden: false)
                var formData: [String: Any] = [:]
                
                for key in formDataOptionals.keys {
                    if key != "notes" && formDataOptionals[key]! == nil {
                        let alert = UIAlertView(title:nil, message: "Please provide an answer for every field!", delegate: nil, cancelButtonTitle:"Got it")
                        alert.show()

                        return
                    } else if key == "notes" && formDataOptionals[key]! == nil {
                    } else {
                        let obj: Any = formDataOptionals[key]!!
                        if let activity = obj as? ActivityType {
                            formData[key] = activity.numberValue
                        } else {
                            formData[key] = obj
                        }
                    }
                }
                var metadata: [String: Any] = ["formdata" : formData]
                if let identifier = UIDevice.current.identifierForVendor {
                    metadata["identifier"] = identifier.uuidString
                }
                
                CoreDataManager.shared.saveContext()
                APIClient.shared.uploadSensorDataCollection(collection, withMetadata: metadata)
                
                strongSelf.navigationController?.popViewController(animated: true)
            }
        }
    }
}
