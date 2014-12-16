//
//  PrivacyCircle.swift
//  HoneyBee
//
//  Created by William Henderson on 12/15/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class PrivacyCircle : NSManagedObject {
    
    @NSManaged var latitude : NSNumber
    @NSManaged var longitude : NSNumber
    @NSManaged var radius : NSNumber
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var privacyCirle : PrivacyCircle?
    }
    
    
    class func privacyCircle() -> PrivacyCircle! {
        if (Static.privacyCirle != nil) {
            return Static.privacyCirle
        }
        
        let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest(entityName: "PrivacyCircle")
        fetchedRequest.fetchLimit = 1
        
        var error : NSError?
        let results = context.executeFetchRequest(fetchedRequest, error: &error)
        
        if (results!.count == 0) {
            return nil
        }
        
        Static.privacyCirle = (results!.first as PrivacyCircle)
        return Static.privacyCirle
    }
    
    class func updateOrCreatePrivacyCircle(circle: MKCircle) {
        if (PrivacyCircle.privacyCircle() == nil) {
            let context = CoreDataController.sharedCoreDataController.currentManagedObjectContext()
            Static.privacyCirle = PrivacyCircle(entity: NSEntityDescription.entityForName("PrivacyCircle", inManagedObjectContext: context)!, insertIntoManagedObjectContext:context)
        }
        Static.privacyCirle?.latitude = circle.coordinate.latitude
        Static.privacyCirle?.longitude = circle.coordinate.longitude
        Static.privacyCirle?.radius = circle.radius
        
        for loc in Location.privateLocations() {
            let location = loc as Location
            location.isPrivate = false
        }
        
        for loc in Location.locationsInCircle(circle) {
            let location = loc as Location
            location.isPrivate = true
        }
        
        CoreDataController.sharedCoreDataController.saveContext()
        
        CoreDataController.sharedCoreDataController.saveContext()
    }
}