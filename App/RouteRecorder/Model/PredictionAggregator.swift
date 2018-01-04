//
//  PredictionAggregator
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreMotion
import CocoaLumberjack

public class PredictionAggregator : NSManagedObject {
    public internal(set) var currentPrediction: Prediction?
    public static let highConfidence: Float = 0.75
    public static let sampleOffsetTimeInterval: TimeInterval = 0.25
    public static let minimumSampleCountForSuccess = 8
    public static let maximumSampleBeforeFailure = 15

    convenience init() {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "PredictionAggregator", in: context)!, insertInto: context)
    }
    
    convenience init(locations: [Location]) {
        self.init()
        
        for loc in locations {
            loc.predictionAggregator = self
        }
    }
    
    public func fetchFirstReading(afterDate: Date)-> AccelerometerReading? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AccelerometerReading")
        fetchedRequest.predicate = NSPredicate(format: "predictionAggregator = %@ AND date >= %@", self, afterDate as CVarArg)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let r = results, let reading = r.first as? AccelerometerReading else {
            return nil
        }
        
        return reading
    }
    
    public func fetchLastReading()-> AccelerometerReading? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AccelerometerReading")
        fetchedRequest.predicate = NSPredicate(format: "predictionAggregator = %@", self)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let r = results, let reading = r.first as? AccelerometerReading else {
            return nil
        }
        
        return reading
    }
    
    public func fetchFirstPrediction()-> Prediction? {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Prediction")
        fetchedRequest.predicate = NSPredicate(format: "predictionAggregator == %@", self)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        guard let r = results, let reading = r.first as? Prediction else {
            return nil
        }
        
        return reading
    }
    
    func addUnknownTypePrediction() {
        let prediction = Prediction()
        prediction.predictionAggregator = self
        prediction.addUnknownTypePredictedActivity()
    }
    
    func updateAggregatePredictedActivity() {
        var activityClassTopConfidenceVotes : [ActivityType: Float] = [:]
        for prediction in self.predictions {
            for predictedActivity in prediction.predictedActivities {
                let currentVote = activityClassTopConfidenceVotes[predictedActivity.activityType] ?? 0
                activityClassTopConfidenceVotes[predictedActivity.activityType] = currentVote + predictedActivity.confidence
            }
        }
        
        let predictedActivity = PredictedActivity()

        var topVote: Float = 0
        for (activityType, vote) in activityClassTopConfidenceVotes {
            if vote > topVote {
                predictedActivity.activityType = activityType
                predictedActivity.confidence = vote / Float(self.predictions.count)
                topVote = vote
            }
        }
        
        self.aggregatePredictedActivity = predictedActivity
        RouteRecorderDatabaseManager.shared.saveContext()
    }
    
    func aggregatePredictionIsComplete()->Bool {
        if predictions.count <= PredictionAggregator.minimumSampleCountForSuccess {
            return false
        }
        
        if let predictedActivity = self.aggregatePredictedActivity {
            if predictedActivity.confidence > PredictionAggregator.highConfidence {
                return true
            }
        }
        
        if predictions.count >= PredictionAggregator.maximumSampleBeforeFailure {
            return true
        }
        
        return false
    }
    
    
    public func jsonDictionary() -> [String: Any] {
        var dict:[String: Any] = [:]
        
        if let routeUUID = self.route?.uuid {
            dict["routeUUID"] = routeUUID
        }
        
        var accelerometerAccelerations : [Any] = []
        for ar in self.accelerometerReadings {
            accelerometerAccelerations.append(ar.jsonDictionary())
        }
        dict["accelerometerReadings"] = accelerometerAccelerations
        
        var predictions : [Any] = []
        for p in self.predictions {
            predictions.append(p.jsonDictionary())
        }
        dict["predictions"] = predictions
        
        if let aggregatePredictedActivity = self.aggregatePredictedActivity {
            dict["aggregatePredictedActivity"] = aggregatePredictedActivity.jsonDictionary()
        }
        
        var locsArray : [Any] = []
        
        if let route = self.route {
            for l in route.fetchOrderedLocations(includingInferred: true) {
                locsArray.append(l.jsonDictionary())
            }
        }
        
        dict["locations"] = locsArray

        return dict
    }
}
