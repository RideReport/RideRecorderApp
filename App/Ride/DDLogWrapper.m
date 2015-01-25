//
//  DDLogWrapper.m
//  Ride
//
//  Created by William Henderson on 10/28/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

#import "DDLogWrapper.h"
#import "CocoaLumberjack.h"

// Definition of the current log level
#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#endif


@implementation DDLogWrapper

+ (void) logVerbose:(NSString *)message {
    DDLogVerbose(message);
}

+ (void) logError:(NSString *)message {
    DDLogError(message);
}

+ (void) logInfo:(NSString *)message {
    DDLogInfo(message);
}

@end