//
//  UILabel+HBAdditions.h
//  Hopbox
//
//  Created by admin on 8/1/13.
//  Copyright (c) 2013 Knock, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UILabel (HBAdditions)

@property (nonatomic, assign) NSString *markdownStringValue;

- (UILabel *)animatedSetMarkdownStringValue:(NSString *)markdownString;
- (UILabel *)animatedSetMarkdownStringValue:(NSString *)markdownString completionBlock:(void (^)(void))block;;

@end
