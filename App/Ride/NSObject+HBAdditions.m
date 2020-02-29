//
//  NSObject+HBAdditions.m
//  Hopbox
//
//  Created by admin on 6/27/13.
//  Copyright (c) 2013 Knock, LLC. All rights reserved.
//

#import "NSObject+HBAdditions.h"

@implementation NSObject (HBAdditions)

- (void)performBlock:(void (^)(void))block;
{
    block();
}

- (void)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay;
{
    void (^block_)(void) = [block copy];
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self performSelector:@selector(performBlock:) withObject:block_ afterDelay:delay];
    });

}

@end
