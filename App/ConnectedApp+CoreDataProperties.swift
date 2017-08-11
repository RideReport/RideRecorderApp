//
//  ConnectedApp+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension ConnectedApp {
    @NSManaged public var appSettingsText: String?
    @NSManaged public var appSettingsUrl: String?
    @NSManaged public var baseImageUrl: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var isHiddenApp: Bool
    @NSManaged public var name: String?
    @NSManaged public var uuid: String
    @NSManaged public var webAuthorizeUrl: String?
    @NSManaged public var profile: Profile?
    @NSManaged public var promotions: Set<Promotion>?
    @NSManaged public var scopes: NSOrderedSet

}

// MARK: Generated accessors for scopes
extension ConnectedApp {

    @objc(insertObject:inScopesAtIndex:)
    @NSManaged public func insertIntoScopes(_ value: ConnectedAppScope, at idx: Int)

    @objc(removeObjectFromScopesAtIndex:)
    @NSManaged public func removeFromScopes(at idx: Int)

    @objc(insertScopes:atIndexes:)
    @NSManaged public func insertIntoScopes(_ values: [ConnectedAppScope], at indexes: NSIndexSet)

    @objc(removeScopesAtIndexes:)
    @NSManaged public func removeFromScopes(at indexes: NSIndexSet)

    @objc(replaceObjectInScopesAtIndex:withObject:)
    @NSManaged public func replaceScopes(at idx: Int, with value: ConnectedAppScope)

    @objc(replaceScopesAtIndexes:withScopes:)
    @NSManaged public func replaceScopes(at indexes: NSIndexSet, with values: [ConnectedAppScope])

    @objc(addScopesObject:)
    @NSManaged public func addToScopes(_ value: ConnectedAppScope)

    @objc(removeScopesObject:)
    @NSManaged public func removeFromScopes(_ value: ConnectedAppScope)

    @objc(addScopes:)
    @NSManaged public func addToScopes(_ values: NSOrderedSet)

    @objc(removeScopes:)
    @NSManaged public func removeFromScopes(_ values: NSOrderedSet)

}
