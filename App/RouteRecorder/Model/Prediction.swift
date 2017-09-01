//
//  Prediction.swift
//  Ride
//
//  Created by William Henderson on 3/1/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreMotion

public class Prediction: NSManagedObject {    
    convenience init() {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Prediction", in: context)!, insertInto: context)
        self.startDate = Date()
    }
    
    public func addUnknownTypePredictedActivity() {
        _ = PredictedActivity(activityType: .unknown, confidence: 1.0, prediction: self)
    }
    
    public func fetchAccelerometerReadings(timeInterval: TimeInterval)-> [AccelerometerReading] {
        guard let predictionAggregator = self.predictionAggregator else {
            return []
        }
        
        guard let firstReading = predictionAggregator.fetchFirstReading(afterDate: self.startDate) else {
            return []
        }
        
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AccelerometerReading")
        fetchedRequest.predicate = NSPredicate(format: "predictionAggregator = %@ AND date >= %@ AND date <= %@", predictionAggregator, firstReading.date as CVarArg, firstReading.date.addingTimeInterval(timeInterval + 0.1) as CVarArg) // padd an extra 0.1
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let readings = results as? [AccelerometerReading] else {
            return []
        }
        
        return readings
    }
    
    public func fetchTopPredictedActivity()-> PredictedActivity? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PredictedActivity")
        fetchedRequest.predicate = NSPredicate(format: "prediction == %@", self)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "confidence", ascending: false)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let r = results, let prediction = r.first as? PredictedActivity else {
            return nil
        }
        
        return prediction
    }
    
    func jsonDictionary() -> [String: Any] {
        var dict:[String: Any] = [:]
        
        if let activityPredictionModelIdentifier = self.activityPredictionModelIdentifier {
            dict["activityPredictionModelIdentifier"] = activityPredictionModelIdentifier
        }
        
        dict["startDate"] = startDate.MillisecondJSONString()
        
        var predictionsArray : [Any] = []
        for p in self.predictedActivities {
            predictionsArray.append(p.jsonDictionary())
        }
        
        dict["predictedActivities"] = predictionsArray
        
        return dict
    }
    
    override public var debugDescription: String {
        return predictedActivities.reduce("", {sum, prediction in sum + prediction.debugDescription + ", "})
    }
    
    func setPredictedActivities(forClassConfidences classConfidences:[Int: Float]) {
        self.predictedActivities = Set<PredictedActivity>()

        for (classInt, confidence) in classConfidences {
            _ = PredictedActivity(activityType: ActivityType(rawValue: Int16(classInt))!, confidence: confidence, prediction: self)
        }
    }
}
