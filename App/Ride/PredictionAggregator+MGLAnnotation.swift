//
//  PredictionAggregator+MGLAnnotation.swift
//  Ride
//
//  Created by William Henderson on 8/31/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

#if DEBUG
    extension PredictionAggregator : MGLAnnotation {
        private func getFirstLocationAfterPrediction()->Location? {
            guard let route = self.route else {
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
            fetchedRequest.predicate = NSPredicate(format: "route == %@ AND (date >= %@)", route, firstReading.date as CVarArg)
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
