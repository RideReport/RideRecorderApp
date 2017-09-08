//
//  TripsListSection
//  Ride
//
//  Created by William Henderson on 9/8/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

@objc(TripsListSection)
public class TripsListSection: NSManagedObject {
    var isInProgressSection: Bool {
        return self.date == Date.distantFuture
    }
    
    class func section(forTrip trip: Trip)->TripsListSection {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TripsListSection")
        fetchedRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", trip.startDate.beginingOfDay() as CVarArg, trip.startDate.beginingOfDay().daysFrom(1) as CVarArg)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if let r = results, let section = r.first as? TripsListSection {
            return section
        }
        
        let section = TripsListSection.init(entity: NSEntityDescription.entity(forEntityName: "TripsListSection", in: context)!, insertInto: context)
        section.date = trip.startDate.beginingOfDay()
        
        return section
    }
    
    func sortedRows()->[TripsListRow] {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TripsListRow")
        fetchedRequest.predicate = NSPredicate(format: "section == %@", self)
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "sortName", ascending: true)]
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if let r = results as? [TripsListRow] {
            return r
        }
        
        return []
    }
}
