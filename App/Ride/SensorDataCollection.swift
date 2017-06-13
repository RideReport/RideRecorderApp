//
//  SensorDataCollection.swift
//  Ride
//
//  Created by William Henderson on 3/1/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import CoreMotion
import MapKit

#if DEBUG
    extension SensorDataCollection : MGLAnnotation {
        var coordinate: CLLocationCoordinate2D  {
            get {
                if let firstLoc = self.locations.firstObject as? Location {
                    return firstLoc.coordinate()
                }
                
                return CLLocationCoordinate2DMake(0, 0)
            }
        }
        
        // Title and subtitle for use by selection UI.
        var title: String? {
            get {
                if let predict = self.topActivityTypePrediction  {
                    return predict.activityType.emoji
                }
                
                return "None"
            }
        }
        
        var subtitle: String? {
            get {
                if let predict = self.topActivityTypePrediction  {
                    return String(format: "Confidence: %f Speed: %f", predict.confidence.floatValue, averageSpeed)
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
            
            if let predict = self.topActivityTypePrediction  {
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

class SensorDataCollection : NSManagedObject {
    var isBeingCollected = false
    
    @NSManaged var activityPredictionModelIdentifier : String?
    
    @NSManaged var accelerometerAccelerations : NSOrderedSet!
    @NSManaged var gyroscopeRotationRates : NSOrderedSet!
    @NSManaged var activityTypePredictions : NSOrderedSet!
    @NSManaged var locations : NSOrderedSet!
    
    @NSManaged var prototrip : Prototrip?
    @NSManaged var trip : Trip?

    private var referenceBootDate: Date!
    
    private var _topActivityTypePrediction: ActivityTypePrediction? // memoized computer property
    var topActivityTypePrediction: ActivityTypePrediction? {
        get {
            if let prediction = self._topActivityTypePrediction {
                return prediction
            }
            
            var highScore: Float = 0
            var topActivityTypePrediction : ActivityTypePrediction?
            
            for p in self.activityTypePredictions {
                let prediction = p as! ActivityTypePrediction
                if prediction.confidence.floatValue > highScore {
                    topActivityTypePrediction = prediction
                    highScore = prediction.confidence.floatValue
                }
            }
            self._topActivityTypePrediction = topActivityTypePrediction
            
            return topActivityTypePrediction
        }
    }

    convenience init(prototrip: Prototrip) {
        self.init()
        
        self.prototrip = prototrip
    }
    
    convenience init(trip: Trip) {
        self.init()
        
        self.trip = trip
    }
    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "SensorDataCollection", in: context)!, insertInto: context)
    }
    
    private func setDate(forSensorData sensorData: SensorData, fromLogItem logItem:CMLogItem) {
        if self.referenceBootDate == nil {
            self.referenceBootDate = Date(timeIntervalSinceNow: -logItem.timestamp)
        }
        
        sensorData.date =  Date(timeInterval: logItem.timestamp, since: self.referenceBootDate)
    }
    
    var averageMovingSpeed : CLLocationSpeed {
        guard self.locations != nil && self.locations.count > 0 else {
            return -1.0
        }
        
        var sumSpeed : Double = 0.0
        var count = 0
        for loc in self.locations.array {
            let location = loc as! Location
            if (location.speed!.doubleValue >= Location.minimumMovingSpeed && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed!.doubleValue
            }
        }
        
        if (count == 0) {
            return -1.0
        }
        
        return sumSpeed/Double(count)
    }
    
    override var debugDescription: String {
        return "Readings: " + String(accelerometerAccelerations.count) + "Moving Speed: " + String(averageMovingSpeed) + ", " + activityTypePredictions.reduce("", {sum, prediction in sum + (prediction as! ActivityTypePrediction).debugDescription + ", "})
    }
    
    var averageSpeed : CLLocationSpeed {
        guard self.locations != nil && self.locations.count > 0 else {
            return -1.0
        }
        
        var sumSpeed : Double = 0.0
        var count = 0
        for loc in self.locations.array {
            let location = loc as! Location
            if (location.speed!.doubleValue >= 0.0 && location.horizontalAccuracy!.doubleValue <= Location.acceptableLocationAccuracy) {
                count += 1
                sumSpeed += (location as Location).speed!.doubleValue
            }
        }
        
        if (count == 0) {
            return -1.0
        }
        
        return sumSpeed/Double(count)
    }
    
    func addLocationIfSufficientlyAccurate(_ location: CLLocation) {
        guard location.horizontalAccuracy <= Location.acceptableLocationAccuracy && location.speed >= 0 else {
            return
        }
        
        let loc = Location(location: location)
        loc.sensorDataCollection = self
    }
    
    func addGyroscopeData(_ gyroscopeData: CMGyroData) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let gd = GyroscopeRotationRate.init(entity: NSEntityDescription.entity(forEntityName: "GyroscopeRotationRate", in: context)!, insertInto: context)
        setDate(forSensorData: gd, fromLogItem: gyroscopeData)
        
        gd.x = NSNumber(value: gyroscopeData.rotationRate.x)
        gd.y = NSNumber(value: gyroscopeData.rotationRate.y)
        gd.z = NSNumber(value: gyroscopeData.rotationRate.z)
        gd.sensorDataCollection = self
    }
    
    func addAccelerometerData(_ accelerometerData: CMAccelerometerData) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let aa = AccelerometerAcceleration.init(entity: NSEntityDescription.entity(forEntityName: "AccelerometerAcceleration", in: context)!, insertInto: context)
        setDate(forSensorData: aa, fromLogItem: accelerometerData)
        
        aa.x = NSNumber(value: accelerometerData.acceleration.x)
        aa.y = NSNumber(value: accelerometerData.acceleration.y)
        aa.z = NSNumber(value: accelerometerData.acceleration.z)
        aa.sensorDataCollection = self
    }
    
    func addDeviceMotion(_ deviceMotion: CMDeviceMotion) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let dma = DeviceMotionAcceleration.init(entity: NSEntityDescription.entity(forEntityName: "DeviceMotionAcceleration", in: context)!, insertInto: context)
        setDate(forSensorData: dma, fromLogItem: deviceMotion)
        dma.x = NSNumber(value: deviceMotion.userAcceleration.x)
        dma.y = NSNumber(value: deviceMotion.userAcceleration.y)
        dma.z = NSNumber(value: deviceMotion.userAcceleration.z)
        dma.sensorDataCollection = self
        
        let dmr = DeviceMotionRotationRate.init(entity: NSEntityDescription.entity(forEntityName: "DeviceMotionRotationRate", in: context)!, insertInto: context)
        setDate(forSensorData: dmr, fromLogItem: deviceMotion)
        dmr.x = NSNumber(value: deviceMotion.rotationRate.x)
        dmr.y = NSNumber(value: deviceMotion.rotationRate.y)
        dmr.z = NSNumber(value: deviceMotion.rotationRate.z)
        dmr.sensorDataCollection = self
    }
    
    func addUnknownTypePrediction() {
        _ = ActivityTypePrediction(activityType: .unknown, confidence: 1.0, sensorDataCollection: self)
        self._topActivityTypePrediction = nil
    }
    
    func setActivityTypePredictions(forClassConfidences classConfidences:[Int: Float]) {
        self.activityTypePredictions = NSOrderedSet()

        for (classInt, confidence) in classConfidences {
            _ = ActivityTypePrediction(activityType: ActivityType(rawValue: Int16(classInt))!, confidence: confidence, sensorDataCollection: self)
        }
        
        self._topActivityTypePrediction = nil
    }
    
    private func jsonArray(forSensorDataSet sensorDataSet:NSOrderedSet)->[Any] {
        var array : [Any] = []
        for s in sensorDataSet {
            array.append((s as! SensorData).jsonDictionary())
        }
        
        return array
    }
    
    func jsonDictionary() -> [String: Any] {
        var dict:[String: Any] = [:]
        dict["accelerometerAccelerations"] = jsonArray(forSensorDataSet: self.accelerometerAccelerations)
        dict["gyroscopeRotationsRates"] = jsonArray(forSensorDataSet: self.gyroscopeRotationRates)
        
        if let activityPredictionModelIdentifier = self.activityPredictionModelIdentifier {
            dict["activityPredictionModelIdentifier"] = activityPredictionModelIdentifier
        }
        
        var locsArray : [Any] = []
        for s in self.locations {
            locsArray.append((s as! Location).jsonDictionary())
        }
        dict["locations"] = locsArray
        
        var predictionsArray : [Any] = []
        for s in self.activityTypePredictions {
            predictionsArray.append((s as! ActivityTypePrediction).jsonDictionary())
        }
        dict["activityTypePredictions"] = predictionsArray
        
        return dict
    }
}
