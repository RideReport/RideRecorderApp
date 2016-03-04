//
//  RandomForestManager.hpp
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DeviceMotionsSample;

@interface RandomForestManager : NSObject

+(RandomForestManager *)sharedInstance:(float)sampleSize;
- (int)classifyDeviceMotionSample:(DeviceMotionsSample *)sample;

@end