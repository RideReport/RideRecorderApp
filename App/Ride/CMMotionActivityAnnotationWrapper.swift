//
//  CMMotionActivityAnnotationWrapper..swift
//  Ride
//
//  Created by William Henderson on 7/19/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreMotion
import CoreData

#if DEBUG
    class CMMotionActivityAnnotationWrapper: NSObject, MGLAnnotation {
        var activity: CMMotionActivity!
        var trip: Trip!
        
        init(activity: CMMotionActivity, trip: Trip) {
            self.activity = activity
            self.trip = trip
        }
        
        var coordinate: CLLocationCoordinate2D  {
            get {
                let context = CoreDataManager.shared.currentManagedObjectContext()
                let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
                fetchedRequest.predicate = NSPredicate(format: "trip == %@ AND (date >= %@ AND date <= %@)", argumentArray: [self.trip, self.activity.startDate, self.activity.startDate.addingTimeInterval(2)])
                fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
                
                let results: [AnyObject]?
                do {
                    results = try context.fetch(fetchedRequest)
                } catch let error {
                    DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
                    results = nil
                }
                if (results == nil) {
                    return CLLocationCoordinate2DMake(0, 0)
                }
                
                if let firstLoc = results?.first as? Location {
                    return firstLoc.coordinate()
                }
                
                return CLLocationCoordinate2DMake(0, 0)
            }
        }
        
        // Title and subtitle for use by selection UI.
        var title: String? {
            get {
                var activityString = ""
                if activity.stationary {
                    activityString += ActivityType.stationary.emoji
                }
                if activity.walking {
                    activityString += ActivityType.walking.emoji
                }
                if activity.running {
                    activityString += ActivityType.running.emoji
                }
                if activity.automotive {
                    activityString += ActivityType.automotive.emoji
                }
                if activity.cycling {
                    activityString += ActivityType.cycling.emoji
                }
                if activity.unknown {
                    activityString += ActivityType.unknown.emoji
                }
                
                return activityString
            }
        }
        
        var subtitle: String? {
            get {
                var activityString = ""
                if activity.stationary {
                    activityString += "Stationary "
                }
                if activity.walking {
                    activityString += "Walking "
                }
                if activity.running {
                    activityString += "Running "
                }
                if activity.automotive {
                    activityString += "Automotive "
                }
                if activity.cycling {
                    activityString += "Cycling "
                }
                if activity.unknown {
                    activityString += "Unknown "
                }
                
                switch activity.confidence {
                case .high:
                    activityString += "High"
                case .medium:
                    activityString += "Medium"
                case .low:
                    activityString += "Low"
                }
                
                return activityString
            }
        }
        
        var pinImage: UIImage {
            var rect : CGRect
            let markersImage = UIImage(named: "markers-soft")!
            let pinColorsCount : CGFloat = 20
            let pinWidth = markersImage.size.width/pinColorsCount
            var pinIndex : CGFloat = 0
            
            if activity.stationary {
                pinIndex = 10
            } else if activity.walking {
                pinIndex = 16
            } else if activity.automotive {
                pinIndex = 1
            } else if activity.cycling {
                pinIndex = 2
            } else {
                pinIndex = 17
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
