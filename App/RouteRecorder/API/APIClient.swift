//
//  APIClient.swift
//  Ride Report
//
//  Created by William Henderson on 12/11/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire
import OAuthSwift
import CocoaLumberjack
import SwiftMessages
import CoreLocation

public let AuthenticatedAPIRequestErrorDomain = "com.Knock.RideReport.error"
let APIRequestBaseHeaders = ["Content-Type": "application/json", "Accept": "application/json, text/plain"]

extension DataRequest {
    
    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
    @discardableResult
    public func responseSwiftyJSON(
        queue: DispatchQueue? = nil,
        options: JSONSerialization.ReadingOptions = .allowFragments,
        completionHandler: @escaping (DataResponse<JSON>) -> Void) -> Self {
        return response(
            queue: queue,
            responseSerializer: DataRequest.swiftyJSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
    
    /// Creates a response serializer that returns a SwiftyJSON instance result type constructed from the response data using
    /// `JSONSerialization` with the specified reading options.
    ///
    /// - parameter options: The JSON serialization reading options. Defaults to `.allowFragments`.
    ///
    /// - returns: A SwiftyJSON response serializer.
    public static func swiftyJSONResponseSerializer(
        options: JSONSerialization.ReadingOptions = .allowFragments) -> DataResponseSerializer<JSON> {
        return DataResponseSerializer { _, response, data, error in
            let result = Request.serializeResponseJSON(options: options, response: response, data: data, error: error)
            switch result {
            case .success(let value):
                return .success(JSON(value))
            case .failure(let error):
                return .failure(error)
            }
        }
    }
}

public class AuthenticatedAPIRequest {
    public typealias APIResponseBlock = (DataResponse<JSON>) -> Void

    // a block that fires once at completion, unlike APIResponseBlocks which are appended
    public var requestCompletetionBlock: ()->Void = {}
    
    public var request: DataRequest? = nil
    private var authToken: String?
    
    public enum AuthenticatedAPIRequestErrorCode: Int {
        case unauthenticated = 1
        case duplicateRequest
        case clientAborted
    }
    
    public static var serverAddress = "https://server.address.here/api/v4/"
    
    public class func unauthenticatedResponse() -> DataResponse<JSON> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.unauthenticated.rawValue, userInfo: nil)
        
        return DataResponse(request: nil, response: nil, data: nil, result: .failure(error))
    }
    
    public class func duplicateRequestResponse() -> DataResponse<JSON> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.duplicateRequest.rawValue, userInfo: nil)
        
        return DataResponse(request: nil, response: nil, data: nil, result: .failure(error))
    }
    
    public class func clientAbortedResponse() -> DataResponse<JSON> {
        let error = NSError(domain: AuthenticatedAPIRequestErrorDomain, code: AuthenticatedAPIRequestErrorCode.clientAborted.rawValue, userInfo: nil)
        
        return DataResponse(request: nil, response: nil, data: nil, result: .failure(error))
    }
    
    public convenience init(clientAbortedWithResponse response: DataResponse<JSON>, completionHandler: APIResponseBlock = {(_) in }) {
        self.init()

        completionHandler(response)
    }
    
    public convenience init(client: APIClient, method: Alamofire.HTTPMethod, route: String, parameters: [String: Any]? = nil, encoding: ParameterEncoding = GZipEncoding.default, idempotencyKey: String? = nil, authenticated: Bool = true, completionHandler: @escaping APIResponseBlock) {
        self.init(client: client, method: method, url: AuthenticatedAPIRequest.serverAddress + route, parameters: parameters, encoding: encoding, idempotencyKey: idempotencyKey, authenticated: authenticated, completionHandler: completionHandler)
    }
    
    public convenience init(client: APIClient, method: Alamofire.HTTPMethod, url: String, parameters: [String: Any]? = nil, encoding: ParameterEncoding = GZipEncoding.default, idempotencyKey: String? = nil, authenticated: Bool = true, completionHandler: @escaping APIResponseBlock) {
        self.init()
        
        if (authenticated && !client.authenticated) {
            client.authenticateIfNeeded()
            completionHandler(AuthenticatedAPIRequest.unauthenticatedResponse())
            self.requestCompletetionBlock()
            return
        }
        
        var headers = APIRequestBaseHeaders
        
        // for some reason configuring headers on the session fails.
        for (key,value) in SessionManager.defaultHTTPHeaders {
            headers[key] = value
        }
        
        if let token = KeychainManager.shared.accessToken, authenticated {
            self.authToken = token
            headers["Authorization"] =  "Bearer \(token)"
        }
        if let theIdempotencyKey = idempotencyKey {
            headers["Idempotence-Key"] = theIdempotencyKey
        }
        
        #if DEBUG
            headers["RR-development-client"] = "true"
        #endif

        self.request = client.sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
        
        let handleHTTPResonseErrors = { (response: HTTPURLResponse?, json: JSON?) in
            if (response?.statusCode == 401) {
                DispatchQueue.main.async {
                    if (self.authToken == KeychainManager.shared.accessToken) {
                        // make sure the token that generated the 401 is still current
                        // since it is possible we've already reauthenciated
                        client.reauthenticate()
                    }
                }
            } else if (response?.statusCode == 455) {
                DispatchQueue.main.async {
                    let view = MessageView.viewFromNib(layout: .cardView)
                    view.configureTheme(.error)
                    view.configureDropShadow()
                    view.button?.setTitle("Update", for: .normal)
                    view.buttonTapHandler = {
                        _ in SwiftMessages.hide()
                        if let appURL = URL(string: "itms://itunes.apple.com/us/app/ride-report-automatic-gps-bike-ride-tracker/id1053230099") {
                            UIApplication.shared.openURL(appURL)
                        }
                    }
                    
                    if let json = json, let title = json["display_title"].string, let body = json["display_body"].string {
                        view.configureContent(title: title, body: body, iconText: "🤖")
                    } else {
                        view.configureContent(title: "App Update Required", body: "Please update the app to keep using Ride!", iconText: "🤖")
                    }
                    
                    view.titleLabel?.numberOfLines = 1
                    view.titleLabel?.adjustsFontSizeToFitWidth = true
                    view.titleLabel?.minimumScaleFactor = 0.6
                    
                    var config = SwiftMessages.Config()
                    config.presentationStyle = .top
                    config.duration = .forever
                    SwiftMessages.show(config: config, view: view)
                }
            } else if let statusCode = response?.statusCode, statusCode >= 500 && statusCode < 600 {
                DispatchQueue.main.async {
                    let view = MessageView.viewFromNib(layout: .cardView)
                    view.configureTheme(.warning)
                    view.configureDropShadow()
                    view.button?.isHidden = true
                    
                    let iconText = ["😓", "😥", "😳", "🙄", "😭"].sm_random()!
                    
                    if let json = json, let title = json["display_title"].string, let body = json["display_body"].string {
                        view.configureContent(title: title, body: body, iconText: iconText)
                    } else {
                        view.configureContent(title: "Ride is having trouble", body: "There was a problem talking to the server. We're working on it!", iconText: iconText)
                    }
                    
                    view.titleLabel?.numberOfLines = 1
                    view.titleLabel?.adjustsFontSizeToFitWidth = true
                    view.titleLabel?.minimumScaleFactor = 0.6
                    
                    var config = SwiftMessages.Config()
                    config.presentationStyle = .top
                    config.duration = .seconds(seconds: 3)
                    SwiftMessages.show(config: config, view: view)
                }
            }
        }
        
        if (method == .delete) {
            // delete does not return JSON https://github.com/KnockSoftware/rideserver/issues/48
            request!.validate().responseString(encoding: String.Encoding.ascii, completionHandler: { (response) in
                let jsonResponse: DataResponse<JSON> = DataResponse(request: response.request, response: response.response, data: response.data, result: Result.success(JSON("")))
                switch response.result {
                case .success(_):
                    completionHandler(jsonResponse)
                case .failure(_):
                    handleHTTPResonseErrors(response.response, nil)
                    completionHandler(jsonResponse)
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            })
        } else {
            request!.validate().responseSwiftyJSON { (response) in
                switch response.result {
                case .success(_):
                    completionHandler(response)
                case .failure(_):
                    handleHTTPResonseErrors(response.response, response.value)
                    completionHandler(response)
                }
                
                // requestCompletetionBlock should fire after all APIResponseBlocks
                self.requestCompletetionBlock()
            }
        }
    }
    
    @discardableResult public func apiResponse(_ completionHandler: @escaping APIResponseBlock)->AuthenticatedAPIRequest {
        if (self.request == nil) {
            completionHandler(AuthenticatedAPIRequest.unauthenticatedResponse())
            return self
        }
        
        self.request!.responseSwiftyJSON { (response) in
            switch response.result {
            case .success(_):
                completionHandler(response)
            case .failure(_):
                completionHandler(response)
            }
        }
        
        return self
    }
}

public protocol APIClientDelegate: class {
    func didChangeAuthenticationStatus()
}

public class APIClient {
    public static private(set) var shared : APIClient!
    
    weak open var delegate: APIClientDelegate?
    
    fileprivate var sessionManager : SessionManager
    fileprivate var routeRequests : [Route: AuthenticatedAPIRequest] = [:]
    fileprivate var isRequestingAuthentication = false
    
    //
    // MARK: - Initializers
    //
    
    class func startup(_ useDefaultConfiguration: Bool = false) {
        if (APIClient.shared == nil) {
            APIClient.shared = APIClient(useDefaultConfiguration: useDefaultConfiguration)
        }
    }
    
    init (useDefaultConfiguration: Bool = false) {
        var configuration = URLSessionConfiguration.background(withIdentifier: "com.Knock.RideReport.background")
        
        if useDefaultConfiguration {
            // used for testing
            configuration = URLSessionConfiguration.default
        }
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
    
        let serverTrustPolicies : [String: ServerTrustPolicy] = [
            "server.address.here": ServerTrustPolicy.pinPublicKeys(publicKeys: ServerTrustPolicy.publicKeys(), validateCertificateChain: true, validateHost: true)
        ]
        self.sessionManager = Alamofire.SessionManager(configuration: configuration, serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    //
    // MARK: - Routes
    //
    
    #if DEBUG
    @discardableResult public func getRouteLocations(withUUID uuid: String)->AuthenticatedAPIRequest {
        return AuthenticatedAPIRequest(client: self, method: .get, route: "routes/" + uuid + "/locations", completionHandler: { (response) -> Void in
            switch response.result {
            case .success(let json):
                var route: Route! = Route.findRoute(withUUID: uuid)
                if route == nil {
                    route = Route()
                    route.uuid = uuid
                    route.isClosed = true
                    route.isUploaded = true
                    route.isSummaryUploaded = true
                }
                
                if let locations = json.array {
                    for locationJson in locations {
                        if let loc = Location(JSON: locationJson) {
                            loc.route = route
                        }
                    }
                }
                
                RouteRecorderDatabaseManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving getting individual route data: %@", error as CVarArg))
            }
        })
    }
    #endif
    
    public func uploadPredictionAggregators(_ predictionAggregators: [PredictionAggregator]) {
        let routeURL = "/prediction_aggregators"
        
        var params: [String: Any] = [:]
        var predictionAggregatorsDictionaries : [Any?] = []
        
        for aggregator in predictionAggregators {
            predictionAggregatorsDictionaries.append(aggregator.jsonDictionary() as Any?)
        }
        params["predictionAggregators"] = predictionAggregatorsDictionaries
        
        _ = AuthenticatedAPIRequest(client: self, method: .post, route: routeURL, parameters:params , authenticated: true) { (response) in
            switch response.result {
            case .success(_):
                DDLogInfo("Uploaded prediction aggregator")
            case .failure(_):
                DDLogWarn("Error uploading prediction aggregator!")
            }
        }
    }
    
    public func uploadPredictionAggregators(forRoute route: Route) {
        let routeURL = "/prediction_aggregators"

        var params: [String: Any] = [:]
        var predictionAggregatorsDictionaries : [Any?] = []

        for aggregator in route.predictionAggregators {
            predictionAggregatorsDictionaries.append(aggregator.jsonDictionary() as Any?)
        }
        params["predictionAggregators"] = predictionAggregatorsDictionaries
        
        _ = AuthenticatedAPIRequest(client: self, method: .post, route: routeURL, parameters:params , authenticated: true) { (response) in
            switch response.result {
            case .success(_):
                DDLogInfo("Uploaded prediction aggregator")
            case .failure(_):
                DDLogWarn("Error uploading prediction aggregator!")
            }
        }
    }

    public func uploadTrainingData(predictionAggregators: [PredictionAggregator], withSurveyData surveyData:[String: Any] = [:]) {
        let accelerometerRouteURL = "training_data"
        var params = surveyData
        
        var predictionAggregatorsDictionaries : [Any?] = []

        for aggregator in predictionAggregators {
            predictionAggregatorsDictionaries.append(aggregator.jsonDictionary() as Any?)
        }
        params["predictionAggregators"] = predictionAggregatorsDictionaries

        _ = AuthenticatedAPIRequest(client: self, method: .post, route: accelerometerRouteURL, parameters:params , authenticated: false) { (response) in
            switch response.result {
            case .success(_):
                DDLogWarn("Yep")
            case .failure(_):
                DDLogWarn("Nope!")
            }
        }
     }
    
    @discardableResult public func uploadRoute(_ route: Route, includeFullLocations: Bool)->AuthenticatedAPIRequest {        
        guard (route.isClosed) else {
            DDLogWarn("Tried to upload route info on unclosed route!")
            
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        guard !(route.isUploaded) else {
            DDLogWarn("Tried to upload route that was already uploaded!")
            
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        if let existingRequest = self.routeRequests[route] {
            // if an existing API request is in flight and we have local changes, wait to upload until after it completes
            
            if !route.isUploaded {
                existingRequest.requestCompletetionBlock = {
                    // we need to reset isUploaded since the changes were made after the request went out.
                    self.uploadRoute(route, includeFullLocations: includeFullLocations)
                }
                return existingRequest
            } else {
                // if we dont have local changes, simply skip this
                return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
            }
        }
        
        let routeURL = "routes/" + route.uuid
        
        let method = Alamofire.HTTPMethod.put
        var routeDict = [
            "activityType": route.activityType.numberValue,
            "creationDate": route.creationDate.JSONString(includingMilliseconds: true)
        ] as [String : Any]
        
        if let closedDate = route.closedDate {
            routeDict["closedDate"] = closedDate.JSONString(includingMilliseconds: true)
        }

        let summaryLocs = route.fetchOrGenerateSummaryLocations()
        
        if summaryLocs.count == 0 {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        var summaryLocations : [Any?] = []
        
        for location in summaryLocs {
            summaryLocations.append((location).jsonDictionary())
        }
        routeDict["summaryLocations"] = summaryLocations
        
        if includeFullLocations {
            guard route.locationCount() > 0 else {
                DDLogWarn("No locations found when syncing route locations!")
                return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
            }
            
            var locations : [Any?] = []

            let locs = route.fetchOrderedLocations(includingInferred: true)
            for location in locs {
                locations.append((location).jsonDictionary())
            }
            routeDict["locations"] = locations
        }
        
        routeDict["length"] = route.length

        DDLogInfo("Uploading route…")
        
        self.routeRequests[route] = AuthenticatedAPIRequest(client: self, method: method, route: routeURL, parameters: routeDict as [String : Any]?) { (response) in
            self.routeRequests[route] = nil
            switch response.result {
            case .success(_):
                DDLogInfo("Uploaded route")

                route.isSummaryUploaded = true
                if includeFullLocations {
                    route.isUploaded = true
                }
                
                RouteRecorderDatabaseManager.shared.saveContext()
            case .failure(let error):
                DDLogWarn(String(format: "Error syncing route: %@", error as CVarArg))

                if let httpResponse = response.response, httpResponse.statusCode == 409 {
                    // a route with that UUID exists. retry.
                    route.generateUUID()
                    self.uploadRoute(route, includeFullLocations: includeFullLocations)
                }
            }
        }
        
        return self.routeRequests[route]!
    }
    
    public func triggerGreenLight(for zone: TriggerZoneCircularRegion, locations: [Location]) {
        let greenLightRouteURL = "trigger_zones/" + zone.uuid + "/hit"
        var params: [String : Any] = [:]
        
        var jsonLocations : [Any?] = []
        for location in locations {
            jsonLocations.append((location).jsonDictionary())
        }
        params["locations"] = jsonLocations
        params["request_date"] = Date().JSONString(includingMilliseconds: true)
        
        _ = AuthenticatedAPIRequest(client: self, method: .post, route: greenLightRouteURL, parameters:params , authenticated: true) { (response) in
            switch response.result {
            case .success(_):
                #if DEBUG
                    // For testing, trigger a local notification that the API was hit
                    let notif = UILocalNotification()
                    notif.alertTitle = "🚦 Green Light Triggered!"
                    notif.alertBody = "Trigger zone id: " + zone.uuid
                    notif.category = "DEBUG_CATEGORY"
                    notif.soundName = "bell.aiff"
                    UIApplication.shared.presentLocalNotificationNow(notif)
                #endif
            case .failure(_):
                DDLogWarn("Failed to post green light trigger")
            }
        }
    }

    //
    // MARK: - OAuth
    //
    
    @discardableResult func logout()-> AuthenticatedAPIRequest {        
        return AuthenticatedAPIRequest(client: APIClient.shared, method: .post, route: "logout") { (response) in
            switch response.result {
            case .success(_):
                APIClient.shared.reauthenticate()
                DDLogInfo("Logged out!")
            case .failure(let error):
                DDLogWarn(String(format: "Error logging out: %@", error as CVarArg))
                APIClient.shared.authenticateIfNeeded()
            }
        }
    }
    
    public var authenticated: Bool {
        return (KeychainManager.shared.accessToken != nil)
    }
    
    public func reauthenticate() {
        if (!self.authenticated) {
            // avoid duplicate reauthenticate requests
            return
        }
        
        KeychainManager.shared.accessToken = nil
        KeychainManager.shared.accessTokenExpiresIn = nil
        if let delegate = self.delegate {
            delegate.didChangeAuthenticationStatus()
        }

        self.authenticateIfNeeded()
    }
    
    @discardableResult public func authenticateIfNeeded()->AuthenticatedAPIRequest {
        if (self.authenticated || self.isRequestingAuthentication) {
            return AuthenticatedAPIRequest(clientAbortedWithResponse: AuthenticatedAPIRequest.clientAbortedResponse())
        }
        
        self.isRequestingAuthentication = true
        
        let parameters = ["client_id" : "1ARN1fJfH328K8XNWA48z6z5Ag09lWtSSVRHM9jw", "response_type" : "token"]
        
        return AuthenticatedAPIRequest(client: self, method: .get, route: "oauth_token", parameters: parameters as [String : Any]?, encoding: URLEncoding.default, authenticated: false) { (response) in
            self.isRequestingAuthentication = false
            
            switch response.result {
            case .success(let json):
                if let accessToken = json["access_token"].string, let expiresInString = json["expires_in"].string, let expiresInInt = Int(expiresInString) {
                    let expiresIn = Date().secondsFrom(expiresInInt)
                    if (KeychainManager.shared.accessToken == nil) {
                        KeychainManager.shared.accessToken = accessToken
                        KeychainManager.shared.accessTokenExpiresIn = expiresIn
                        if let delegate = self.delegate {
                            delegate.didChangeAuthenticationStatus()
                        }
                    } else {
                        DDLogWarn("Got a new access token when one was already set!")
                    }
                }
            case .failure(let error):
                DDLogWarn(String(format: "Error retriving access token: %@", error as CVarArg))
            }
        }
    }
}
