//
//  RideReportAPIClient.swift
//  Ride
//
//  Created by William Henderson on 9/1/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder
import Mixpanel
import CocoaLumberjack
import Crashlytics
import Alamofire
import WebLinking

class RideReportAPIClient: APIClientDelegate {
    public static private(set) var shared : RideReportAPIClient!
    fileprivate var tripRequests : [Trip: AuthenticatedAPIRequest] = [:]
    
    
    public class func startup(_ useDefaultConfiguration: Bool = false) {
        if (RideReportAPIClient.shared == nil) {
            RideReportAPIClient.shared = RideReportAPIClient()
            APIClient.shared.delegate = RideReportAPIClient.shared
            
            
            RideReportAPIClient.shared.syncStatus()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.8 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                // avoid a bug that could have this called twice on app launch
                NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) { _ in
                    RideReportAPIClient.shared.syncStatus()
                }
            })
        }
    }
    
    enum AccountVerificationStatus : Int16 { // has the user linked and verified an email to the account?
        case unknown = 0
        case unverified
        case verified
    }
    
    enum Area {
        case unknown
        case area(name: String, meters: UInt, metersPerHour: UInt, launched: Bool)
        case nonArea
    }
    
    var area : Area = .unknown
    
    // Status
    var accountVerificationStatus = AccountVerificationStatus.unknown {
        didSet {
            if accountVerificationStatus != .verified {
                self.accountEmailAddress = nil
            }
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RideReportAPIClientAccountStatusDidChange"), object: nil)
        }
    }
    
    var accountEmailAddress: String? = nil
    
    var hasRegisteredForRemoteNotifications: Bool = false
    var notificationDeviceToken: Data?
    
    //
    // MARK: - Trip Synchronization
    //
    
    var hasMoreTripsRemaining: Bool {
        get {
            return Profile.profile().nextPageURLString != nil
        }
    }
    
    @discardableResult func syncTrips(atNextPageURL nextPageURL: String? = nil)->AuthenticatedAPIRequest {
        var syncTripURL: String!
        
        if let nextPageURL = nextPageURL {
            syncTripURL = nextPageURL
        } else if let syncURL = Profile.profile().nextSyncURLString {
            syncTripURL = syncURL
        } else {
            // the user has never synchronized, do initial get
            
            return getMoreTrips()
        }
        
        return getTrips(atURL: syncTripURL).apiResponse({ (response) in
            if let syncLink = response.response?.findLink(relation: "sync") {
                Profile.profile().nextSyncURLString = syncLink.uri
            }
            
            if let nextLink = response.response?.findLink(relation: "next") {
                self.syncTrips(atNextPageURL: nextLink.uri)
            }
            
            CoreDataManager.shared.saveContext()
        })
    }
    
    private var isRequestingTrips = false
    @discardableResult func getMoreTrips()->AuthenticatedAPIRequest {
        guard !isRequestingTrips else {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        var getTripsURL: String!
        if let nextPageURL = Profile.profile().nextPageURLString {
            getTripsURL = nextPageURL
        } else {
            getTripsURL = (AuthenticatedAPIRequest.serverAddress + "trips")
        }
        isRequestingTrips = true
        
        return getTrips(atURL: getTripsURL).apiResponse({ (response) in
            self.isRequestingTrips = false
            if let nextLink = response.response?.findLink(relation: "next") {
                Profile.profile().nextPageURLString = nextLink.uri
            } else if case .success = response.result {
                Profile.profile().nextPageURLString = nil
            }
            
            if let syncLink = response.response?.findLink(relation: "sync") {
                Profile.profile().nextSyncURLString = syncLink.uri
            }
            
            CoreDataManager.shared.saveContext()
        })
    }
    
    @discardableResult private func getTrips(atURL url: String)->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .get, url: url, completionHandler: { (response) -> Void in
            switch response.result {
            case .success(let json):
                for tripJson in json.array! {
                    if let deleted = tripJson["deleted"].bool, deleted {
                        if let uuid = tripJson["uuid"].string, let trip = Trip.tripWithUUID(uuid) {
                            trip.managedObjectContext?.delete(trip)
                            CoreDataManager.shared.saveContext()
                        }
                    } else if let uuid = tripJson["uuid"].string {
                        if let trip = Trip.createOrUpdateFromJSON(tripJson) {
                            trip.isSynced = true
                        }
                    }
                }
                CoreDataManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving getting trip data: %@", error as CVarArg))
            }
        })
    }
    
    public func getTripDisplayData(displayDataURL: String, handler: @escaping (Data?)->()) {
        if let url = URL(string: displayDataURL), let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: url)) {
            handler(cachedResponse.data)
            return
        }
        
        _ = AuthenticatedAPIRequest(client: APIClient.shared, method: .get, url: displayDataURL, parameters: nil) { (response) in
            switch response.result {
            case .success(let json):
                do {
                    let data = try json.rawData()
                    if let urlresponse = response.response, let urlrequest = response.request {
                        URLCache.shared.storeCachedResponse(CachedURLResponse(response: urlresponse, data: data), for: urlrequest)
                    }
                    handler(data)
                } catch {
                    DDLogWarn("Error parsing display data response!")
                    handler(nil)
                }
            case .failure(_):
                DDLogWarn("Error getting display data!")
                handler(nil)
            }
        }
    }
    
    @discardableResult func patchTrip(_ trip: Trip)->AuthenticatedAPIRequest {
        if let existingRequest = self.tripRequests[trip] {
            // if an existing API request is in flight and we have local changes, wait to sync until after it completes
            
            if !trip.isSynced {
                existingRequest.requestCompletetionBlock = {
                                // we need to reset isSynced since the changes were made after the request went out.
                    trip.isSynced = false
                    self.patchTrip(trip)
                }
                return existingRequest
            } else {
                // if we dont have local changes, simply skip this
                return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
            }
        }
        
        let routeURL = "trips/" + trip.uuid
        
        let tripDict = [
            "activityType": trip.activityType.numberValue,
            "rating": trip.rating.choice.numberValue,
            "ratingVersion": trip.rating.version.numberValue
            ] as [String : Any]
        
        self.tripRequests[trip] = AuthenticatedAPIRequest(client: APIClient.shared, method: .patch, route: routeURL, parameters: tripDict as [String : Any]?) { (response) in
            self.tripRequests[trip] = nil
            switch response.result {
            case .success(let json):
                if let updatedTrip = Trip.createOrUpdateFromJSON(json) {
                    updatedTrip.isSynced = true
                }
                
                if let encouragementDictionaries = json["encouragements"].arrayObject {
                    Profile.profile().updateEncouragements(encouragementDictionaries: encouragementDictionaries)
                    CoreDataManager.shared.saveContext()
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "APIClientStatusTextDidChange"), object: nil)
                } else {
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error patching trip: %@", error as CVarArg))
            }
        }
        
        return self.tripRequests[trip]!
    }
    
    @discardableResult func getTrip(_ trip: Trip)->AuthenticatedAPIRequest {
        guard let uuid = trip.uuid else {
            // the server doesn't know about this trip yet
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .get, route: "trips/" + uuid, completionHandler: { (response) -> Void in
            switch response.result {
            case .success(let json):
                Trip.createOrUpdateFromJSON(json)
                
                CoreDataManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving getting individual trip data: %@", error as CVarArg))
                
                if let httpResponse = response.response, httpResponse.statusCode == 404 {
                    // unclear what to do in this case (probably we should try to upload the trip again?), but at a minimum we should never try to sync the summary again.
                    trip.isSynced = true
                    CoreDataManager.shared.saveContext()
                }
            }
        })
    }
    
    @discardableResult func deleteTrip(_ trip: Trip)->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .delete, route: "trips/" + trip.uuid, completionHandler: { (response) -> Void in
            switch response.result {
            case .success(_),
                 .failure(_) where response.response != nil && response.response!.statusCode == 404:
                // it's possible the server already deleted the object, in which case it will send a 404.
                DispatchQueue.main.async {
                    trip.managedObjectContext?.delete(trip)
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error deleting trip data: %@", error as CVarArg))
            }
        })
    }
    
    @discardableResult func saveAndPatchTripIfNeeded(_ trip: Trip)->AuthenticatedAPIRequest {
        trip.saveAndMarkDirty()
        
        if !trip.isSynced {
            return self.patchTrip(trip)
        }
        
        return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
    }
    
    @discardableResult func getReward(uuid: String, completionHandler: @escaping AuthenticatedAPIRequest.APIResponseBlock)->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .get, route: "rewards/" + uuid, completionHandler: completionHandler)
    }
    
    @discardableResult func getStatistics()->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .get, route: "statistics", completionHandler: { (response) -> Void in
            switch response.result {
            case .success(let json):
                let url = CoreDataManager.shared.applicationDocumentsDirectory.appendingPathComponent("stats.json")
                if let data = try? json.rawData() {
                    try? data.write(to: url)
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving getting individual trip data: %@", error as CVarArg))
            }
        })
    }
    
    //
    // MARK: - Account API Methods
    //
    
    func didChangeAuthenticationStatus() {
        if (APIClient.shared.authenticated) {
            self.syncStatus()
        } else {
            self.accountVerificationStatus = .unknown
        }
    }
    
    func appDidReceiveNotificationDeviceToken(_ token: Data?) {
        let oldToken = self.notificationDeviceToken
        let hadRegisteredForRemoteNotifications = self.hasRegisteredForRemoteNotifications
        
        self.hasRegisteredForRemoteNotifications = true
        self.notificationDeviceToken = token
        if (oldToken != token || !hadRegisteredForRemoteNotifications) {
            self.updateAccountStatus()
        }
    }
    
    func syncStatus() {
        if (APIClient.shared.authenticated) {
            // do account status even in the background
            self.updateAccountStatus()
        }
        
    }

    func profileDictionary() -> [String: Any] {
        var profileDictionary = [String: Any]()
        
        var iosDictionary = [String: Any]()
        if let preferredLanguage = Locale.current.languageCode {
            iosDictionary["preferred_language"] = preferredLanguage
        }
        
        if let countryCode = Locale.current.countryCode {
            iosDictionary["country_code"] = countryCode
        }
        
        if let model = UIDevice.current.deviceModel() {
            iosDictionary["device_model"] = model
        }
        
        iosDictionary["device_screen"] = ["width": UIScreen.main.bounds.width, "height": UIScreen.main.bounds.height, "scale": UIScreen.main.scale]
        
        if !iosDictionary.isEmpty {
            profileDictionary["ios"] = iosDictionary
        }
        
        // Health Kit Data
        var healthKitDictionary = [String: Any]()
        if let dob = Profile.profile().dateOfBirth {
            healthKitDictionary["date_of_birth"] = dob.JSONString(includingMilliseconds: false)
        }
        
        if let weight = Profile.profile().weightKilograms, weight > 0 {
            healthKitDictionary["weight_kilograms"] = weight
        }
        
        let gender = Profile.profile().gender
        if  gender.rawValue != 0 {
            healthKitDictionary["gender"] = gender.rawValue
        }
        
        if !healthKitDictionary.isEmpty {
            profileDictionary["healthkit"] = healthKitDictionary
        }
        
        return profileDictionary
    }
    
    
    @discardableResult func updateAccountStatus()-> AuthenticatedAPIRequest {
        guard self.hasRegisteredForRemoteNotifications else {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        var parameters: [String: Any] = [:]
        if let deviceToken = self.notificationDeviceToken {
            parameters["device_token"] = deviceToken.hexadecimalString()
        }
        
        parameters["profile"] = self.profileDictionary()
        
        if let locationManager = RouteRecorder.shared.locationManager, let loc = locationManager.location {
            parameters["lnglat"] = String(loc.coordinate.longitude) + "," + String(loc.coordinate.latitude)
        }
        
        return AuthenticatedAPIRequest(client: APIClient.shared, method:.post, route: "status", parameters: parameters) { (response) -> Void in
            switch response.result {
            case .success(let json):
                if let areaJson = json["area"].dictionary {
                    if let name = areaJson["name"]?.string, let meters = areaJson["count_info"]?["meters"].uInt, let metersPerHour = areaJson["count_info"]?["meters_per_hour"].uInt, let launched = areaJson["launched"]?.bool {
                        self.area = .area(name: name, meters: meters, metersPerHour: metersPerHour, launched: launched)
                    } else {
                        self.area = .nonArea
                    }
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RideReportAPIClientAccountStatusDidGetArea"), object: nil)
                } else {
                    self.area = .unknown
                }
                
                if let featureFlags = json["feature_flags"].array?.map({$0.string}) as? [String] {
                    Profile.profile().featureFlags = featureFlags
                } else {
                    Profile.profile().featureFlags = []
                }
                
                if let encouragementDictionaries = json["encouragements"].arrayObject {
                    Profile.profile().updateEncouragements(encouragementDictionaries: encouragementDictionaries)
                }
                
                if let supportId = json["support_id"].string {
                    Profile.profile().supportId = supportId
                    Crashlytics.sharedInstance().setUserIdentifier(supportId)
                }
                
                if let promotions = json["promotions"].array {
                    var newPromotions: [Promotion] = []
                    
                    for promotionsDict in promotions {
                        if let promo = Promotion.createOrUpdate(withJson: promotionsDict) {
                            newPromotions.append(promo)
                            promo.profile = Profile.profile()
                        }
                    }
                    
                    for promo in Profile.profile().promotions {
                        let promotion = promo as! Promotion
                        if !newPromotions.contains(promotion) {
                            promotion.profile = nil
                        }
                    }
                }
                
                if let connectedApps = json["connected_apps"].array {
                    var appsToDelete = ConnectedApp.allApps()
                    
                    for appDict in connectedApps {
                        if let app = ConnectedApp.createOrUpdate(withJson: appDict) {
                            if let index = appsToDelete.index(of: app) {
                                appsToDelete.remove(at: index)
                            }
                            app.profile = Profile.profile()
                        }
                    }
                    
                    for app in appsToDelete {
                        // delete any app objects we did not receive
                        app.profile = nil
                    }
                }
                
                CoreDataManager.shared.saveContext()
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RideReportAPIClientStatusTextDidChange"), object: nil)
                
                if let mixPanelID = json["mixpanel_id"].string {
                    Mixpanel.mainInstance().identify(distinctId: mixPanelID)
                }
                
                if let account_verified = json["account_verified"].bool {
                    if (account_verified) {
                        self.accountEmailAddress = json["accounts"]["emails"].array?.first?["email"].string
                        self.accountVerificationStatus = .verified
                    } else {
                        self.accountVerificationStatus = .unverified
                    }
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving account status: %@", error as CVarArg))
            }
        }
    }
    
    @discardableResult func sendVerificationTokenForEmail(_ email: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .post, route: "send_email_code", parameters: ["email": email]) { (response) in
            switch response.result {
            case .success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
            case .failure(let error):
                DDLogWarn(String(format: "Error sending verification email: %@", error as CVarArg))
            }
        }
    }
    
    @discardableResult func verifyToken(_ token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .post, route: "verify_email_code", parameters: ["code": token]) { (response) in
            switch response.result {
            case .success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .failure(let error):
                DDLogWarn(String(format: "Error verifying email token: %@", error as CVarArg))
            }
        }
    }
    
    @discardableResult func verifyFacebook(_ token: String)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .post, route: "verify_facebook_login", parameters: ["token": token]) { (response) in
            switch response.result {
            case .success(let json):
                DDLogInfo(String(format: "Response: %@", json.stringValue))
                self.updateAccountStatus()
            case .failure(let error):
                DDLogWarn(String(format: "Error verifying facebook token: %@", error as CVarArg))
            }
        }
    }

    
    //
    // MARK: - Application API Methods
    //
    
    
    @discardableResult func getAllApplications()-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .get, route: "applications") { (response) -> Void in
            switch response.result {
            case .success(let json):
                if let apps = json.array {
                    var appsToDelete = ConnectedApp.allApps()
                    
                    for appDict in apps {
                        if let app = ConnectedApp.createOrUpdate(withJson: appDict), let index = appsToDelete.index(of: app) {
                            appsToDelete.remove(at: index)
                        }
                    }
                    
                    for app in appsToDelete {
                        // delete any app objects we did not receive
                        if !app.isHiddenApp {
                            CoreDataManager.shared.currentManagedObjectContext().delete(app)
                        }
                    }
                    
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error as CVarArg))
            }
        }
    }
    
    @discardableResult func getApplication(_ app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .get, route: "applications/" + app.uuid) { (response) -> Void in
            switch response.result {
            case .success(let json):
                app.updateWithJson(withJson: json)
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party app: %@", error as CVarArg))
            }
        }
    }
    
    @discardableResult func connectApplication(_ app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .post, route: "applications/" + app.uuid + "/connect", parameters: app.json().dictionaryObject as [String : Any]?) { (response) -> Void in
            switch response.result {
            case .success(let json):
                if let httpsResponse = response.response, httpsResponse.statusCode == 200 {
                    _ = ConnectedApp.createOrUpdate(withJson: json)
                    app.profile = Profile.profile()
                    CoreDataManager.shared.saveContext()
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error as CVarArg))
            }
        }
    }
    
    @discardableResult func disconnectApplication(_ app: ConnectedApp)-> AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .post, route: "applications/" + app.uuid + "/disconnect") { (response) -> Void in
            switch response.result {
            case .success(_):
                app.profile = nil
                CoreDataManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error getting third party apps: %@", error as CVarArg))
            }
        }
    }
}
