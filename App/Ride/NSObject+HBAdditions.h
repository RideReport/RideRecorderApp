//
//  NSObject+HBAdditions.h
//  Hopbox
//
//  Created by admin on 6/27/13.
//  Copyright (c) 2013 Knock, LLC. All rights reserved.
//

#include <Foundation/Foundation.h>

@interface NSObject (HBAdditions)

- (void)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay;

@end
