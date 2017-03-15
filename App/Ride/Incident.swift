//
//  Incident.swift
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation

class Incident : NSManagedObject {
    enum IncidentType : Int {
        case unknown = 0
        case roadHazard
        case unsafeIntersection
        case bikeLaneEnds
        case unsafeSpeeds
        case aggressiveMotorist
        case insufficientParking
        case suspectedBikeTheif
        
        static var count: Int { return IncidentType.suspectedBikeTheif.rawValue + 1}
        
        var text: String {
            switch(self) {
            case .unknown:
                return "Other"
            case .roadHazard:
                return "Road Hazard"
            case .unsafeIntersection:
                return "Unsafe Intersection"
            case .bikeLaneEnds:
                return "Bike Lane Ends"
            case .unsafeSpeeds:
                return "Unsafe Speeds"
            case .aggressiveMotorist:
                return "Aggressive Motorist"
            case .insufficientParking:
                return "Insufficient Parking"
            case .suspectedBikeTheif:
                return "Suspected Stolen Bikes"
            }
        }
        
        var pinImage: UIImage {
            var rect : CGRect
            let markersImage = UIImage(named: "markers-soft")!
            let pinColorsCount : CGFloat = 20
            let pinWidth = markersImage.size.width/pinColorsCount
            var pinIndex : CGFloat = 0
            
            switch(self) {
                case .unknown:
                    pinIndex = 17
                case .roadHazard:
                    pinIndex = 0
                case .unsafeIntersection:
                    pinIndex = 0
                case .bikeLaneEnds:
                    pinIndex = 0
                case .unsafeSpeeds:
                    pinIndex = 0
                case .aggressiveMotorist:
                    pinIndex = 1
                case .insufficientParking:
                    pinIndex = 8
                case .suspectedBikeTheif:
                    pinIndex = 19
            }
            
            rect = CGRect(x: -pinIndex * pinWidth, y: 0.0, width: pinWidth, height: markersImage.size.height)
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
            markersImage.draw(at: rect.origin)
            let pinImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return pinImage!
        }
    }
    
    @NSManaged var uuid : String
    @NSManaged var body : String!
    @NSManaged var creationDate : Date!
    @NSManaged var type : NSNumber!
    
    @NSManaged var trip : Trip?
    @NSManaged var location : Location
    
    convenience init(location: Location, trip: Trip) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "Incident", in: context)!, insertInto: context)
        
        self.trip = trip
        self.location = location
        self.creationDate = Date()
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        self.creationDate = Date()
        self.uuid = UUID().uuidString
    }
    
    override func awakeFromFetch() {
        super.awakeFromFetch()
        if (self.uuid == "foo") {
            self.uuid = UUID().uuidString
        }
    }
    
    var coordinate: CLLocationCoordinate2D  {
        get {
            if (!self.isFault) {
                return self.location.coordinate()
            } else {
                // seems to happen when a pin is getting deleted
                return CLLocationCoordinate2D(latitude: 0, longitude: 0)
            }
        }
        set {
            self.willChangeValue(forKey: "coordinate")
            let nearestLocation = self.trip!.closestLocationToCoordinate(newValue)
            if (nearestLocation == nil) {
                self.location = self.trip!.mostRecentLocation()!
            } else {
                self.location = nearestLocation!
            }
            self.didChangeValue(forKey: "coordinate")
        }
    }
    
    // Title and subtitle for use by selection UI.
    var title: String? {
        get {
            return Incident.IncidentType(rawValue: self.type.intValue)!.text
        }
    }
}
