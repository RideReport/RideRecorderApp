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
    private static var _timeFormatter : DateFormatter?
    
    class var timeDateFormatter : DateFormatter {
        get {
            if (_timeFormatter == nil) {
                _timeFormatter = DateFormatter()
                _timeFormatter!.locale = Locale.current
                _timeFormatter!.dateFormat = "hh:mma"
            }
            
            return _timeFormatter!
        }
    }
    
    convenience init() {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "TripsListRow", in: context)!, insertInto: context)
    }

    
    func updateSortName() {
        if let trip = self.bikeTrip {
            self.sortName = "y" + TripsListRow.timeDateFormatter.string(from: trip.startDate)
        } else {
            self.sortName = "z"
        }
    }
}
