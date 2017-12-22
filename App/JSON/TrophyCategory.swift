//
//  TrophyCategory.swift
//  Ride
//
//  Created by William Henderson on 12/11/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct TrophyCategory {
    var name: String = ""
    var application: ConnectedApp? = nil
    var trophyProgresses: [TrophyProgress] = []
    
    init?(_ dictionary: JSON) {        
        guard let name = dictionary["name"].string,
            let trophyProgressJsons = dictionary["content"].array else {
                return nil
        }
        
        self.name = name
        
        
        for trophyProgressJson in trophyProgressJsons {
            if let trophyProgress = TrophyProgress(trophyProgressJson) {
                trophyProgresses.append(trophyProgress)
            }
        }
        
        if let applicationUUID = dictionary["application_uuid"].string {
            self.application = ConnectedApp.createOrUpdate(applicationUUID)
        }
    }
}
