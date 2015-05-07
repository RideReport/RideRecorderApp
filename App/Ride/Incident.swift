//
//  Incident.swift
//  Ride
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class Incident : NSManagedObject, MKAnnotation {
    enum IncidentType : Int {
        case Unknown = 0
        case RoadHazard
        case UnsafeIntersection
        case BikeLaneEnds
        case UnsafeSpeeds
        case AggressiveMotorist
        case InsufficientParking
        case SuspectedBikeTheif
        
        static var count: Int { return IncidentType.SuspectedBikeTheif.rawValue + 1}
        
        var text: String {
            switch(self) {
            case Unknown:
                return "Other"
            case RoadHazard:
                return "Road Hazard"
            case UnsafeIntersection:
                return "Unsafe Intersection"
            case BikeLaneEnds:
                return "Bike Lane Ends"
            case UnsafeSpeeds:
                return "Unsafe Speeds"
            case AggressiveMotorist:
                return "Aggressive Motorist"
            case InsufficientParking:
                return "Insufficient Parking"
            case SuspectedBikeTheif:
                return "Suspected Stolen Bikes"
            }
        }
        
        var pinImage: UIImage {
            var rect : CGRect
            let markersImage = UIImage(named: "markers-soft")!
            let pinColorsCount : CGFloat = 20
            let pinWidth = markersImage.size.width/pinColorsCount
            var pinIndex : CGFloat = 0
            var icon : UIImage! = nil
            let iconSize : CGFloat = 16.0
            
            switch(self) {
                case Unknown:
                    pinIndex = 17
                    icon = IonIcons.imageWithIcon(ion_flag, size: iconSize, color: UIColor.whiteColor())
                case RoadHazard:
                    pinIndex = 0
                    icon = IonIcons.imageWithIcon(ion_alert, size: iconSize, color: UIColor.whiteColor())
                case UnsafeIntersection:
                    pinIndex = 0
                    icon = IonIcons.imageWithIcon(ion_network, size: iconSize, color: UIColor.whiteColor())
                case BikeLaneEnds:
                    pinIndex = 0
                    icon = IonIcons.imageWithIcon(ion_arrow_graph_down_right, size: iconSize, color: UIColor.whiteColor())
                case UnsafeSpeeds:
                    pinIndex = 0
                    icon = IonIcons.imageWithIcon(ion_speedometer, size: iconSize, color: UIColor.whiteColor())
                case AggressiveMotorist:
                    pinIndex = 1
                    icon = IonIcons.imageWithIcon(ion_model_s, size: iconSize, color: UIColor.whiteColor())
                case InsufficientParking:
                    pinIndex = 8
                    icon = IonIcons.imageWithIcon(ion_code, size: iconSize, color: UIColor.whiteColor())
                case SuspectedBikeTheif:
                    pinIndex = 19
                    icon = IonIcons.imageWithIcon(ion_eye, size: iconSize, color: UIColor.whiteColor())
            }
            
            let iconPoint = CGPoint(x: (pinWidth - icon.size.width)/2.0, y: 9)
            rect = CGRect(x: -pinIndex * pinWidth, y: 0.0, width: pinWidth, height: markersImage.size.height)
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
            markersImage.drawAtPoint(rect.origin)
            icon.drawAtPoint(iconPoint)
            let pinImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return pinImage
        }
    }
    
    @NSManaged var uuid : String
    @NSManaged var body : String!
    @NSManaged var creationDate : NSDate!
    @NSManaged var type : NSNumber!
    
    @NSManaged var trip : Trip?
    @NSManaged var location : Location
    
    convenience init(location: Location, trip: Trip) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("Incident", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.trip = trip
        self.location = location
        self.creationDate = NSDate()
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = NSDate()
        self.uuid = NSUUID().UUIDString
    }
    
    override func awakeFromFetch() {
        super.awakeFromFetch()
        if (self.uuid == "foo") {
            self.uuid = NSUUID().UUIDString
        }
    }
    
    var coordinate: CLLocationCoordinate2D  {
        get {
            return self.location.coordinate()
        }
        set {
            self.willChangeValueForKey("coordinate")
            var nearestLocation = self.trip!.closestLocationToCoordinate(newValue)
            if (nearestLocation == nil) {
                self.location = self.trip!.mostRecentLocation()!
            } else {
                self.location = nearestLocation
            }
            self.didChangeValueForKey("coordinate")
        }
    }
    
    // Title and subtitle for use by selection UI.
    var title: String! {
        get {
            return Incident.IncidentType(rawValue: self.type.integerValue)!.text
        }
    }
}
