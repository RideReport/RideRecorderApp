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
#import <sys/utsname.h>

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

- (NSString*)deviceModel;
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

@end
