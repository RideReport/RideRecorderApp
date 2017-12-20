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
    public static let emptyBodyPlaceholderString = "???"
    
    var emoji: String = ""
    var progress: Double = 0
    var body: String? = nil
    var instructions: String? = nil
    var count: Int = 0
    var lastEarned: Date? = nil
    
    convenience init?(dictionary: JSON) {
        self.init()
        
        guard let emoji = dictionary["emoji"].string else {
            return nil
        }
        
        self.emoji = emoji
        self.body = dictionary["description"].string
        
        if let dateString = dictionary["lastEarned"].string, let date = Date.dateFromJSONString(dateString) {
            self.lastEarned = date
        }
        
        self.instructions = dictionary["instructions"].string
        
        if let count = dictionary["count"].int {
            self.count = count
        } else {
            self.count = 0
        }
        
        if let progress = dictionary["progress"].double {
            self.progress = progress
        } else {
            self.progress = 0.0
        }
    }
}
