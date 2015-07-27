//
//  UIDevice+HBAdditions.h
//  Ride
//
//  Created by William Henderson on 2/8/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (HBAdditions)

@property (nonatomic, readonly, getter=isWiFiEnabled) BOOL wifiEnabled;

- (NSDictionary *)usageStastics;
- (NSDictionary *)dailyUsageStasticsForBundleIdentifier:(NSString *)bundleID;
- (NSDictionary *)weeklyUsageStasticsForBundleIdentifier:(NSString *)bundleID;

@end
