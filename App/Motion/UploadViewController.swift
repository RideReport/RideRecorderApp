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
    public var sensorDataCollection : SensorDataCollection!
    public var formData : [String: Any]!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        form +++ Section("Notes") {
            $0.tag = "notes"
        }
        <<< TextRow(){
            $0.tag = "notes"
            $0.placeholder = "Tell us anything notable about the trip"
        }
        
        form +++ ButtonRow {
            $0.title = "Upload"
        }.onCellSelection { [weak self] (cell, row) in
            guard let strongSelf = self else {
                return
            }
            
            if let collection = strongSelf.sensorDataCollection {
                var formDataForUPload: [String: Any] = strongSelf.formData
                
                if let notes = (strongSelf.form.rowBy(tag: "notes") as? TextRow)?.value,  notes != "" {
                    formDataForUPload["notes"] = notes
                }
                
                var metadata: [String: Any] = ["formdata" : formDataForUPload]
                if let identifier = UIDevice.current.identifierForVendor {
                    metadata["identifier"] = identifier.uuidString
                }
                
                CoreDataManager.shared.saveContext()
                APIClient.shared.uploadSensorDataCollection(collection, withMetadata: metadata)
                
                strongSelf.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
}
