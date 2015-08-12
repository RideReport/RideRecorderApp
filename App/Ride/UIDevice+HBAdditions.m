//
//  UIDevice+HBAdditions.m
//  Ride Report
//
//  Created by William Henderson on 2/8/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

#import "UIDevice+HBAdditions.h"
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@implementation UIDevice (UIDevice)

- (BOOL)isWiFiEnabled;
{
    struct ifaddrs *interfaces;
    
    BOOL hasFoundAtLeastOne = NO;
    
    if(! getifaddrs(&interfaces) ) {
        for(struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
            if ((interface->ifa_flags & IFF_UP) == IFF_UP && [[NSString stringWithUTF8String:interface->ifa_name] isEqualToString:@"awdl0"]) {
                if (hasFoundAtLeastOne) {
                    return YES;
                }
                hasFoundAtLeastOne = YES;
            }
        }
    }
    
    return NO;
}

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
