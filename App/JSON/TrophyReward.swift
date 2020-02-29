//
//  TrophyReward.swift
//  RouteRecorder
//
//  Created by William Henderson on 10/19/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

enum TrophyRewardCouponFormat {
    case plaintext
    
    init?(_ formatString: String?) {
        if formatString == "plaintext" {
            self = .plaintext
        } else {
            return nil
        }
    }
}

enum TrophyRewardInstanceType {
    case unknown
    case coupon(title: String, message: String, format: TrophyRewardCouponFormat)
}

struct TrophyRewardInstance {
    var voided: Bool
    let uuid: String
    let expires: Date?
    let type: TrophyRewardInstanceType
    
    init?(_ dictionary: JSON) {
        guard let thisUuid = dictionary["uuid"].string else {
            return nil
        }
        
        uuid = thisUuid
        voided = dictionary["voided"].bool ?? false
        
        if let expiresString = dictionary["expires"].string, let expiresDate = Date.dateFromJSONString(expiresString) {
            expires = expiresDate
        } else {
            expires = nil
        }
        
        let coupon = dictionary["coupon"]
        if let couponTitle = coupon["title"].string, let couponMessage = coupon["message"].string, let couponFormat = TrophyRewardCouponFormat(coupon["format"].string) {
            type = .coupon(title: couponTitle, message: couponMessage, format: couponFormat)
        } else {
            type = .unknown
        }
    }
}

public struct TrophyReward {
    let description: String!
    let organizationName: String?
    var instances: [TrophyRewardInstance]
    
    init?(_ dictionary: JSON) {
        guard let thisDescription = dictionary["description"].string else {
            return nil
        }
        description = thisDescription
        
        self.organizationName = dictionary["organization_name"].string
        
        var instancesArray: [TrophyRewardInstance] = []

        if let jsonInstances = dictionary["instances"].array {
            for jsonInstance in jsonInstances {
                if let trophyRewardInstance = TrophyRewardInstance(jsonInstance) {
                    instancesArray.append(trophyRewardInstance)
                }
            }
        }
        self.instances = instancesArray
    }
}
