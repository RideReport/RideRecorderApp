//
//  UIDevice+HBAdditions.m
//  Ride
//
//  Created by William Henderson on 2/8/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

#import "UIDevice+HBAdditions.h"
#import <dlfcn.h>

@implementation UIDevice (UIDevice)

- (NSDictionary *)_usageStastics;
{
    NSDictionary *output = nil;
    
    void * handle = dlopen("/System/Library/PrivateFrameworks/PowerLog.framework/PowerLog", RTLD_LAZY);
    NSDictionary *(*PLBatteryUsageUIQuery)(NSString *key, NSDictionary *dict) = dlsym (handle, "PLBatteryUsageUIQuery");
    
    if (PLBatteryUsageUIQuery) {
        output = PLBatteryUsageUIQuery (@"PLBatteryUIQueryFunctionKey", @{@"PLBatteryUIQueryFunctionKey": @0});
    }
    if (handle) {
        dlclose (handle);
    }
    
    return output;
}

- (NSDictionary *)dailyUsageStasticsForBundleIdentifier:(NSString *)bundleID;
{
    NSDictionary *usage = [self _usageStastics];
    if (!usage) {
        return nil;
    }
    
    NSArray *appsArray = [[usage objectForKey:@"PLBatteryUIQueryRangeDayKey"] objectForKey:@"PLBatteryUIAppArrayKey"];
    for (NSDictionary *dict in appsArray) {
        if ([[dict objectForKey:@"PLBatteryUIAppBundleIDKey"] isEqualToString:bundleID]) {
            return dict;
        }
    }
    
    return nil;
}

- (NSDictionary *)weeklyUsageStasticsForBundleIdentifier:(NSString *)bundleID;
{
    NSDictionary *usage = [self _usageStastics];
    if (!usage) {
        return nil;
    }
    
    NSArray *appsArray = [[usage objectForKey:@"PLBatteryUIQueryRangeWeekKey"] objectForKey:@"PLBatteryUIAppArrayKey"];
    for (NSDictionary *dict in appsArray) {
        if ([[dict objectForKey:@"PLBatteryUIAppBundleIDKey"] isEqualToString:bundleID]) {
            return dict;
        }
    }
    
    return nil;
}

@end
