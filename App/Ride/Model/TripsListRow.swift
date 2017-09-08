//
//  TripsListRow
//  Ride
//
//  Created by William Henderson on 9/8/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

@objc(TripsListRow)
public class TripsListRow: NSManagedObject {
    private static var _sectionDateFormatter : DateFormatter?
    
    class var sectionDateFormatter : DateFormatter {
        get {
            if (_sectionDateFormatter == nil) {
                _sectionDateFormatter = DateFormatter()
                _sectionDateFormatter!.locale = Locale.current
                _sectionDateFormatter!.dateFormat = "yyyy-MM-dd"
            }
            
            return _sectionDateFormatter!
        }
    }
    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "TripsListRow", in: context)!, insertInto: context)
    }
    
    private class func nonbikeTripIdentifier()->String {
        return "yy"
    }
    
    func updateSortName() {
        if let trip = self.bikeTrip {
            self.sortName = TripsListRow.sectionDateFormatter.string(from: trip.startDate)
        } else {
            self.sortName = TripsListRow.nonbikeTripIdentifier()
        }
    }
}
