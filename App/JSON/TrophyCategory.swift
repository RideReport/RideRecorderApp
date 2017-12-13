//
//  TrophyCategory.swift
//  Ride
//
//  Created by William Henderson on 12/11/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

public class TrophyCategory {
    var name: String = ""
    var application: ConnectedApp? = nil
    var trophyProgresses: [TrophyProgress] = []
    
    convenience init?(dictionary: JSON) {
        self.init()
        
        guard let name = dictionary["name"].string,
            let trophyProgressJsons = dictionary["content"].array else {
                return nil
        }
        
        self.name = name
        
        
        for trophyProgressJson in trophyProgressJsons {
            if let trophyProgress = TrophyProgress(dictionary: trophyProgressJson) {
                trophyProgresses.append(trophyProgress)
            }
        }
        
        if let applicationUUID = dictionary["application_uuid"].string {
            self.application = ConnectedApp.createOrUpdate(applicationUUID)
        }
    }
}
