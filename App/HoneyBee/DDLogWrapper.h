//
//  DDLogWrapper.h
//  HoneyBee
//
//  Created by William Henderson on 10/28/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// hack to make cocoa lumberjack swift-happy
@interface DDLogWrapper : NSObject
+ (void) logVerbose:(NSString *)message;
+ (void) logError:(NSString *)message;
+ (void) logInfo:(NSString *)message;
@end