//
//  RandomForest.swift
//  Ride
//
//  Created by William Henderson on 3/7/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class RandomForestManager {
    var _ptr: COpaquePointer
    
    init(sampleSize: Int) {
        let path = NSBundle(forClass: self.dynamicType).pathForResource("forest.cv", ofType: nil)
        let cpath = path?.cStringUsingEncoding(NSUTF8StringEncoding)

        _ptr = createRandomForestManager(Int32(sampleSize), UnsafeMutablePointer(cpath!))
    }
    
    deinit {
        deleteRandomForestManager(_ptr)
    }
    
    func classifyMagnitudeVector(magnitudeVector: [Float], speedVector: [Float])->Int
    {
        return Int(randomForesetClassifyMagnitudeVector(_ptr, UnsafeMutablePointer(magnitudeVector), UnsafeMutablePointer(speedVector), Int32(speedVector.count)))
    }
}