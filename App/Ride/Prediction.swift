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
import MapKit

public class Prediction: NSManagedObject {
    var isInProgress = false

    convenience init(trip: Trip) {
        self.init()
        
        self.trip = trip
    }
    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Prediction", in: context)!, insertInto: context)
        self.startDate = Date()
    }
    
    public func addUnknownTypePrediction() {
        _ = PredictedActivity(activityType: .unknown, confidence: 1.0, prediction: self)
    }
    
    public func addToTrip(_ trip: Trip) {
        self.trip = trip
        for reading in self.accelerometerReadings {
            reading.trip = trip
        }
    }
    
    public func fetchAccelerometerReadings(timeInterval: TimeInterval)-> [AccelerometerReading] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AccelerometerReading")
        fetchedRequest.predicate = NSPredicate(format: "%@ IN includedPredictions", self)
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
    
    public func fetchFirstReading()-> AccelerometerReading? {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AccelerometerReading")
        fetchedRequest.predicate = NSPredicate(format: "%@ IN includedPredictions", self)
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
        fetchedRequest.predicate = NSPredicate(format: "%@ IN includedPredictions", self)
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

    
    public func fetchTopPredictedActivity()-> PredictedActivity? {
        let context = CoreDataManager.shared.currentManagedObjectContext()
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
    
    override public var debugDescription: String {
        return "Readings: " + String(accelerometerReadings.count) + ", " + predictedActivities.reduce("", {sum, prediction in sum + (prediction as! PredictedActivity).debugDescription + ", "})
    }
    
    func setPredictedActivities(forClassConfidences classConfidences:[Int: Float]) {
        self.predictedActivities = Set<PredictedActivity>()

        for (classInt, confidence) in classConfidences {
            _ = PredictedActivity(activityType: ActivityType(rawValue: Int16(classInt))!, confidence: confidence, prediction: self)
        }
    }
}

#if DEBUG
    extension Prediction : MGLAnnotation {
        private func getFirstLocationAfterPrediction()->Location? {
            guard let trip = self.trip else {
                return nil
            }
            
            let context = CoreDataManager.shared.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
            fetchedRequest.predicate = NSPredicate(format: "trip == %@ AND (date >= %@)", [trip, self.startDate])
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
                if let predict = self.fetchTopPredictedActivity()  {
                    return predict.activityType.emoji
                }
                
                return "None"
            }
        }
        
        public var subtitle: String? {
            get {
                if let predict = self.fetchTopPredictedActivity()  {
                    return String(format: "Confidence: %f", predict.confidence)
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
            
            if let predict = self.fetchTopPredictedActivity()  {
                switch predict.activityType {
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
