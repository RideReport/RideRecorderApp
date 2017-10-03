//
//  TripReward.swift
//  Ride
//
//  Created by William Henderson on 6/6/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

public class  TripReward : NSManagedObject {
    class var numberOfRewards : Int {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TripReward")
        fetchedRequest.resultType = NSFetchRequestResultType.countResultType
        fetchedRequest.predicate = NSPredicate(format: "trip != NULL")
        
        if let count = try? context.count(for: fetchedRequest) {
            return count
        }
        
        return 0
    }
    
    var earnedAtCoordinate: CLLocationCoordinate2D? {
        get {
            guard earnedAtLatitude != -1 && earnedAtLongitude != -1 else {
                return nil
            }
            
            return CLLocationCoordinate2D(latitude: earnedAtLatitude, longitude: earnedAtLongitude)
        }
        
        set {
            guard let coord = newValue else {
                self.earnedAtLatitude = -1
                self.earnedAtLongitude = -1
                return
            }
            
            self.earnedAtLatitude = coord.latitude
            self.earnedAtLongitude = coord.longitude
        }
    }
    
    var rewardUUID: String? {
        get {
            let components = self.emoji.components(separatedBy: TripReward.stupidHackDelimterString)
            if components.count == 2 {
                return components[0]
            }
            
            return nil
        }
    }
    
    var iconURL: URL? {
        get {
            let components = self.emoji.components(separatedBy: TripReward.stupidHackDelimterString)
            if components.count == 2 {
                return URL(string: components[1])
            }
            
            return nil
        }
    }
    
    private static var stupidHackDelimterString = "%%%"
    var displaySafeEmoji: String {
        let components = self.emoji.components(separatedBy: TripReward.stupidHackDelimterString)
        if components.count != 1 {
            return "💵"
        }
        
        if self.emoji == "" || self.emoji.containsUnsupportEmoji() {
            // support for older versions of iOS without a given emoji
            return "🏆"
        }
        
        return self.emoji
    }
    
    class func reward(dictionary: [String: Any])->TripReward? {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        if let description = dictionary["description"] as? String, let emoji = dictionary["emoji"] as? String {
            let reward = TripReward.init(entity: NSEntityDescription.entity(forEntityName: "TripReward", in: context)!, insertInto: context)
            reward.emoji = emoji
            reward.descriptionText = description
            if let rewardUUID = dictionary["reward_uuid"] as? String, let icon_url = dictionary["icon_url"] as? String {
                reward.emoji = rewardUUID + TripReward.stupidHackDelimterString + icon_url
            }
            
            if let earnedAtCoordinateArray = dictionary["earned_at_coordinate"] as? [Double], earnedAtCoordinateArray.count == 2 {
                reward.earnedAtLongitude = earnedAtCoordinateArray[0]
                reward.earnedAtLatitude = earnedAtCoordinateArray[1]
            }
            
            return reward
        }
        
        return nil
    }
    
    convenience init(trip: Trip, emoji: String, descriptionText: String) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "TripReward", in: context)!, insertInto: context)
        self.emoji = emoji
        self.descriptionText = descriptionText
        
        self.trip = trip
    }
    
    class func tripRewardCountsGroupedByAttribute(_ attribute: String, additionalAttributes: [String]? = nil) -> [[String: AnyObject]] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let  countExpression = NSExpressionDescription()
        countExpression.name = "count"
        countExpression.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: attribute)])
        countExpression.expressionResultType = NSAttributeType.integer32AttributeType
        let entityDescription = NSEntityDescription.entity(forEntityName: "TripReward", in: CoreDataManager.shared.managedObjectContext!)!
        
        guard let attributeDescription = entityDescription.attributesByName[attribute] else {
            return []
        }
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TripReward")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "trip.startDate", ascending: true)]
        var propertiesToFetch = [attributeDescription, countExpression]
        var propertiesToGroupBy = [attributeDescription]
        if let otherAttributes = additionalAttributes {
            for otherAttribute in otherAttributes {
                if let attributeDesc = entityDescription.attributesByName[otherAttribute] {
                    propertiesToFetch.append(attributeDesc)
                    propertiesToGroupBy.append(attributeDesc)
                }
            }
        }
        
        fetchedRequest.propertiesToFetch = propertiesToFetch
        fetchedRequest.propertiesToGroupBy = propertiesToGroupBy
        fetchedRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        
        var error : NSError?
        let results: [AnyObject]?
        
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error1 as NSError {
            error = error1
            results = nil
        }
        if (results == nil || error != nil) {
            return []
        }
        
        let dictResults = results as! [[String: AnyObject]]
        
        if (dictResults.count == 1 && (dictResults[0]["count"]! as? NSNumber)?.int32Value == 0) {
            return []
        }
        
        return dictResults
    }
}
