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

class SensorDataCollection : NSManagedObject {
    @NSManaged var predictedActivityType : NSNumber?
    @NSManaged var actualActivityType : NSNumber?
    
    @NSManaged var accelerometerAccelerations : NSOrderedSet!
    @NSManaged var deviceMotionAccelerations : NSOrderedSet!
    @NSManaged var deviceMotionRotationRates : NSOrderedSet!
    @NSManaged var gyroscopeRotationRates : NSOrderedSet!
    @NSManaged var locations : NSOrderedSet!
    
    @NSManaged var prototrip : Prototrip?
    @NSManaged var trip : Trip?

    private var referenceBootDate: NSDate!

    convenience init(prototrip: Prototrip) {
        self.init()
        
        self.prototrip = prototrip
    }
    
    convenience init(trip: Trip) {
        self.init()
        
        self.trip = trip
    }
    
    convenience init() {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("SensorDataCollection", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
    }
    
    private func setDate(forSensorData sensorData: SensorData, fromLogItem logItem:CMLogItem) {
        if self.referenceBootDate == nil {
            self.referenceBootDate = NSDate(timeIntervalSinceNow: -logItem.timestamp)
        }
        
        sensorData.date =  NSDate(timeInterval: logItem.timestamp, sinceDate: self.referenceBootDate)
    }
    
    func addLocation(location: CLLocation) {
        let loc = Location(location: location)
        loc.sensorDataCollection = self
    }
    
    func addGyroscopeData(gyroscopeData: CMGyroData) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let gd = GyroscopeRotationRate.init(entity: NSEntityDescription.entityForName("GyroscopeRotationRate", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        setDate(forSensorData: gd, fromLogItem: gyroscopeData)
        
        gd.x = gyroscopeData.rotationRate.x
        gd.y = gyroscopeData.rotationRate.y
        gd.z = gyroscopeData.rotationRate.z
        gd.sensorDataCollection = self
    }
    
    func addAccelerometerData(accelerometerData: CMAccelerometerData) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let aa = AccelerometerAcceleration.init(entity: NSEntityDescription.entityForName("AccelerometerAcceleration", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        setDate(forSensorData: aa, fromLogItem: accelerometerData)
        
        aa.x = accelerometerData.acceleration.x
        aa.y = accelerometerData.acceleration.y
        aa.z = accelerometerData.acceleration.z
        aa.sensorDataCollection = self
    }
    
    func addDeviceMotion(deviceMotion: CMDeviceMotion) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        let dma = DeviceMotionAcceleration.init(entity: NSEntityDescription.entityForName("DeviceMotionAcceleration", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        setDate(forSensorData: dma, fromLogItem: deviceMotion)
        dma.x = deviceMotion.gravity.x
        dma.y = deviceMotion.gravity.y
        dma.z = deviceMotion.gravity.z
        dma.sensorDataCollection = self
        
        let dmr = DeviceMotionRotationRate.init(entity: NSEntityDescription.entityForName("DeviceMotionRotationRate", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        setDate(forSensorData: dmr, fromLogItem: deviceMotion)
        dmr.x = deviceMotion.gravity.x
        dmr.y = deviceMotion.gravity.y
        dmr.z = deviceMotion.gravity.z
        dmr.sensorDataCollection = self
    }
    
    private func jsonArray(forSensorDataSet sensorDataSet:NSOrderedSet)->[AnyObject] {
        var array : [AnyObject] = []
        for s in sensorDataSet {
            array.append((s as! SensorData).jsonDictionary())
        }
        
        return array
    }
    
    func jsonDictionary() -> [String: AnyObject] {
        var dict:[String: AnyObject] = [:]
        dict["accelerometerAccelerations"] = jsonArray(forSensorDataSet: self.accelerometerAccelerations)
        dict["deviceMotionAccelerations"] = jsonArray(forSensorDataSet: self.deviceMotionAccelerations)
        dict["deviceMotionRotationRates"] = jsonArray(forSensorDataSet: self.deviceMotionRotationRates)
        dict["gyroscopeRotationsRates"] = jsonArray(forSensorDataSet: self.gyroscopeRotationRates)
        
        var locsArray : [AnyObject] = []
        for s in self.locations {
            locsArray.append((s as! Location).jsonDictionary())
        }
        dict["locations"] = locsArray
        
        return dict
    }
}