//
//  TrophyProgress.swift
//  RouteRecorder
//
//  Created by William Henderson on 10/19/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct TrophyProgress {
    public static let emptyBodyPlaceholderString = "???"
    
    var emoji: String = ""
    var progress: Double = 0
    var count: Int = 0
    
    var body: String? = nil
    var moreInfoUrl: URL? = nil
    var iconURL: URL? = nil
    var imageURL: URL? = nil
    var instructions: String? = nil
    var lastEarned: Date? = nil
    
    var reward: TrophyReward? = nil
    
    init?(_ dictionary: JSON) {        
        guard let emoji = dictionary["emoji"].string else {
            return nil
        }
        
        self.emoji = emoji
        self.body = dictionary["description"].string
        
        if let dateString = dictionary["last_earned"].string, let date = Date.dateFromJSONString(dateString) {
            self.lastEarned = date
        }
        
        self.instructions = dictionary["instructions"].string
        
        if let urlString = dictionary["more_info_url"].string {
            self.moreInfoUrl = URL(string: urlString)
        }
        
        if let urlString = dictionary["image_url"].string {
            self.imageURL = URL(string: urlString)
        } else {
            self.imageURL = nil
        }
        
        if let urlString = dictionary["icon_url"].string {
            self.iconURL = URL(string: urlString)
        } else {
            self.iconURL = nil
        }
        
        self.reward = TrophyReward(dictionary["reward"])
        
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
