//
//  TripReward.swift
//  Ride
//
//  Created by William Henderson on 6/6/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class TripReward : NSManagedObject {
    @NSManaged var descriptionText : String
    @NSManaged var emoji : String
    @NSManaged var trip : Trip
    
    var displaySafeEmoji: String? {
        if self.emoji.containsUnsupportEmoji() {
            // support for older versions of iOS without a given emoji
            return "🏆"
        }
        
        return self.emoji
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
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "trip.creationDate", ascending: true)]
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
