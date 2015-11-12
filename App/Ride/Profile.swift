//
//  Profile.swift
//  Ride Report
//
//  Created by William Henderson on 4/30/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class Profile : NSManagedObject {
    @NSManaged var uuid : String?
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var profile : Profile!
    }
    
    class func profile() -> Profile! {
        if (Static.profile == nil) {
            let context = CoreDataManager.sharedManager.currentManagedObjectContext()
            let fetchedRequest = NSFetchRequest(entityName: "Profile")
            fetchedRequest.fetchLimit = 1
            
            let results: [AnyObject]?
            do {
                results = try context.executeFetchRequest(fetchedRequest)
            } catch let error {
                DDLogWarn(String(format: "Error finding profile: %@", error as NSError))
                results = nil
            }
            
            if (results!.count == 0 || (results!.first as! Profile).uuid == nil) {
                let context = CoreDataManager.sharedManager.currentManagedObjectContext()
                Static.profile = Profile(entity: NSEntityDescription.entityForName("Profile", inManagedObjectContext: context)!, insertIntoManagedObjectContext:context)
                Static.profile.uuid = NSUUID().UUIDString
                CoreDataManager.sharedManager.saveContext()
            } else {
                Static.profile = (results!.first as! Profile)
            }
        }
        
        return Static.profile
    }
}
