//
//  Encouragement.swift
//  Ride
//
//  Created by William Henderson on 6/6/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

public class Encouragement : NSManagedObject {
    public convenience init?(dictionary: [String: Any]) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        
        if let description = dictionary["text"] as? String, let emoji = dictionary["emoji"] as? String {
            self.init(entity: NSEntityDescription.entity(forEntityName: "Encouragement", in: context)!, insertInto: context)
            self.emoji = emoji
            self.descriptionText = description
        } else {
            return nil
        }
    }
}
