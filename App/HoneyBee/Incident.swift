//
//  Incident.swift
//  HoneyBee
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class Incident : NSManagedObject {
    @NSManaged var trip : Trip?
    
    override func willSave() {
        if (self.trip != nil) {
            self.trip!.self.syncEventually()
        }
        
        super.willSave()
    }
}
