//
//  Promotion.swift
//  Ride
//
//  Created by William Henderson on 3/30/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

public class  Promotion: NSManagedObject {
    class func createOrUpdate(_ uuid: String)->Promotion {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Promotion")
        fetchedRequest.predicate = NSPredicate(format: "uuid == [c] %@", uuid)
        fetchedRequest.fetchLimit = 1
        
        let results: [AnyObject]?
        do {
            results = try context.fetch(fetchedRequest)
        } catch let error {
            DDLogWarn(String(format: "Error executing fetch request: %@", error as NSError))
            results = nil
        }
        
        if let result = results?.first as? Promotion {
            return result
        }
        
        let promo = Promotion(entity: NSEntityDescription.entity(forEntityName: "Promotion", in: context)!, insertInto: context)
        promo.uuid = uuid
        
        return promo
    }
    
    class func createOrUpdate(withJson json: JSON)->Promotion? {
        guard let uuid = json["uuid"].string else {
            return nil
        }
        
        let promo = Promotion.createOrUpdate(uuid)
        promo.updateWithJson(withJson: json)
        
        return promo
    }
    
    func updateWithJson(withJson json: JSON) {
        if let bannerUrl = json["banner_image"].string {
            self.bannerImageUrl = bannerUrl
        }
        
        if let text = json["text"].string {
            self.text = text
        }
        
        if let buttonTitle = json["button_title"].string {
            self.buttonTitle = buttonTitle
        }
        
        if let dateString = json["begins"].string, let date = Date.dateFromJSONString(dateString) {
            self.startDate = date
        }
        if let dateString = json["ends"].string, let date = Date.dateFromJSONString(dateString) {
            self.endDate = date
        }
        
        if let applicationUUID = json["application_uuid"].string {
            let app = ConnectedApp.createOrUpdate(applicationUUID)
            self.connectedApp = app
        }
    }
}
