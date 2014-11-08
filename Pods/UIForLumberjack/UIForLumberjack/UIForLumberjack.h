//
//  UIForLumberjack.h
//  UIForLumberjack
//
//  Created by Kamil Burczyk on 15.01.2014.
//  Copyright (c) 2014 Sigmapoint. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DDLog.h"
#import "DDFileLogger.h"

#define kSPUILoggerMessageMargin 10

@interface UIForLumberjack : NSObject <UITableViewDataSource, UITableViewDelegate, DDLogger>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic) BOOL persistsLogs;

+ (UIForLumberjack*) sharedInstance;

- (void)showLogInView:(UIView*)view;
- (void)hideLog;

@end
