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

public class PredictionAggregator : NSManagedObject {
    public var currentPrediction: Prediction?
    public static let highConfidence: Float = 0.75
    public static let sampleOffsetTimeInterval: TimeInterval = 0.25
    public static let minimumSampleCountForSuccess = 8
    public static let maximumSampleBeforeFailure = 15

    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "PredictionAggregator", in: context)!, insertInto: context)
    }
    
    public func fetchFirstReading(afterDate: Date)-> AccelerometerReading? {
        let context = CoreDataManager.shared.currentManagedObjectContext()
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
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
        let context = CoreDataManager.shared.currentManagedObjectContext()
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
    
    public func addUnknownTypePrediction() {
        let prediction = Prediction()
        self.predictions.insert(prediction)
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
        CoreDataManager.shared.saveContext()
    }
    
    func aggregatePredictionIsComplete()->Bool {
        guard let predictedActivity = self.aggregatePredictedActivity else {
            return false
        }
        
        if predictions.count <= PredictionAggregator.minimumSampleCountForSuccess {
            return false
        }
            
        if predictedActivity.confidence > PredictionAggregator.highConfidence {
            return true
        }
        
        if predictions.count > PredictionAggregator.maximumSampleBeforeFailure {
            return true
        }
        
        return false
    }
    
    
    func jsonDictionary() -> [String: Any] {
        var dict:[String: Any] = [:]
        
        var accelerometerAccelerations : [Any] = []
        for ar in self.accelerometerReadings {
            accelerometerAccelerations.append(ar.jsonDictionary())
        }
        dict["accelerometerAccelerations"] = accelerometerAccelerations
        
        var predictions : [Any] = []
        for p in self.predictions {
            predictions.append(p.jsonDictionary())
        }
        dict["predictions"] = predictions
        
        var locsArray : [Any] = []
        
        if let trip = self.trip {
            for l in trip.fetchOrderedLocations() {
                locsArray.append(l.jsonDictionary())
            }
        }
        
        dict["locations"] = locsArray

        return dict
    }
}


#if DEBUG
    extension PredictionAggregator : MGLAnnotation {
        private func getFirstLocationAfterPrediction()->Location? {
            guard let trip = self.trip else {
                return nil
            }
            
            guard let firstPrediction = self.fetchFirstPrediction() else {
                return nil
            }

            guard let firstReading = self.fetchFirstReading(afterDate:firstPrediction.startDate) else {
                return nil
            }
            
            let context = CoreDataManager.shared.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
            fetchedRequest.predicate = NSPredicate(format: "trip == %@ AND (date >= %@)", trip, firstReading.date as CVarArg)
            fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            fetchedRequest.fetchLimit = 1
            
            let results: [AnyObject]?
            do {
                results = try context.fetch(fetchedRequest)
            } catch let error {
                DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
                results = nil
            }
            
            guard let r = results, let loc = r.first as? Location else {
                return nil
            }
            
            return loc
        }
        
        public var coordinate: CLLocationCoordinate2D  {
            get {
                if let firstLoc = self.getFirstLocationAfterPrediction() {
                    return firstLoc.coordinate()
                }
                
                return CLLocationCoordinate2DMake(0, 0)
            }
        }
        
        // Title and subtitle for use by selection UI.
        public var title: String? {
            get {
                if let predictedActivityType = self.aggregatePredictedActivity  {
                    return predictedActivityType.activityType.emoji
                }
                
                return "None"
            }
        }
        
        public var subtitle: String? {
            get {
                if let predictedActivityType = self.aggregatePredictedActivity  {
                    return String(format: "Confidence: %f", predictedActivityType.confidence)
                }
                
                return "-"
            }
        }
        
        var pinImage: UIImage {
            var rect : CGRect
            let markersImage = UIImage(named: "markers-soft")!
            let pinColorsCount : CGFloat = 20
            let pinWidth = markersImage.size.width/pinColorsCount
            var pinIndex : CGFloat = 0
            
            if let predictedActivityType = self.aggregatePredictedActivity  {
                switch predictedActivityType.activityType {
                case .automotive:
                    pinIndex = 1
                case .cycling:
                    pinIndex = 2
                case .walking:
                    pinIndex = 16
                case .bus:
                    pinIndex = 6
                case .rail:
                    pinIndex = 3
                case .stationary:
                    pinIndex = 10
                default:
                    pinIndex = 17
                    
                }
            } else {
                pinIndex = 18
            }
            rect = CGRect(x: -pinIndex * pinWidth, y: 0.0, width: pinWidth, height: markersImage.size.height)
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
            markersImage.draw(at: rect.origin)
            let pinImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return pinImage!
        }
        
    }
#endif
