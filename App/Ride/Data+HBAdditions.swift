//
//  Data+HBAdditions.swift
//  Ride
//
//  Created by William Henderson on 3/14/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

extension Data {
    public func hexadecimalString() -> String {
        var string = ""
        string.reserveCapacity(count * 2)
        
        for byte in self {
            string.append(String(format: "%02X", byte))
        }
        
        return string
    }
}
