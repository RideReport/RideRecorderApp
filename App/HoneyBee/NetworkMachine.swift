//
//  NetworkMachine.swift
//  HoneyBee
//
//  Created by William Henderson on 12/11/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Alamofire

//let serverAddress = "http://10.1.10.179:8080/"
let serverAddress = "http://54.148.164.222/"

class NetworkMachine {
    private var jsonDateFormatter = NSDateFormatter()
    private var manager : Manager
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedMachine : NetworkMachine?
    }
    
    class var sharedMachine:NetworkMachine {
        dispatch_once(&Static.onceToken) {
            Static.sharedMachine = NetworkMachine()
        }
        
        return Static.sharedMachine!
    }
    
    func jsonify(date: NSDate) -> String {
        return self.jsonDateFormatter.stringFromDate(date)
    }
    
    init () {
        self.jsonDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 60
        self.manager = Alamofire.Manager(configuration: config)
    }
    
    func postRequest(route: String, parameters: [String: AnyObject!]) -> Request {
        return manager.request(.POST, serverAddress + route, parameters: parameters, encoding: .JSON)
    }
    
}
