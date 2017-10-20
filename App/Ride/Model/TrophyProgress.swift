//
//  TrophyProgress.swift
//  RouteRecorder
//
//  Created by William Henderson on 10/19/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

public class TrophyProgress {
    var emoji: String = ""
    var progress: Double = 0
    var body: String = ""
    var count: Int = 0
    var lastEarned: Date? = nil
    
    convenience init?(dictionary: JSON) {
        self.init()
        
        guard let emoji = dictionary["emoji"].string,
            let body = dictionary["description"].string,
            let count = dictionary["count"].int else {
                return nil
        }
        
        self.emoji = emoji
        self.body = body
        self.count = count
        
        if let dateString = dictionary["lastEarned"].string, let date = Date.dateFromJSONString(dateString) {
            self.lastEarned = date
        }
        
        if let progress = dictionary["progress"].double {
            self.progress = progress
        } else {
            self.progress = 1.0
        }
    }
}
