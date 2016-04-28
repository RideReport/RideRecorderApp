//
//  BKPasscodeField.m
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 4. 20..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//
//  Modified by William Henderson on 8/24/15.
//  Copyright (c) 2015 Knock Software, Inc. All rights reserved.
//

#import "BKPasscodeField.h"

@interface BKPasscodeField ()

@property (strong, nonatomic) NSMutableString       *mutablePasscode;
@property (strong, nonatomic) NSRegularExpression   *nonDigitRegularExpression;
@property (nonatomic) CGSize                separatorSize;

@end

@implementation BKPasscodeField

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (void)_initialize
{
    _maximumLength = 4;
    _dotSize = CGSizeMake(18.0f, 19.0f);
    _separatorSize = CGSizeMake(18.0f, 2.0f);
    _dotSpacing = 25.0f;
    _lineHeight = 3.0f;
    _dotColor = [UIColor blackColor];
    
    self.backgroundColor = [UIColor clearColor];
    
    _mutablePasscode = [[NSMutableString alloc] initWithCapacity:4];
    
    [self addTarget:self action:@selector(didTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
}

- (NSRegularExpression *)nonDigitRegularExpression
{
    if (nil == _nonDigitRegularExpression) {
        _nonDigitRegularExpression = [[NSRegularExpression alloc] initWithPattern:@"[^0-9]+" options:0 error:nil];
    }
    return _nonDigitRegularExpression;
}

- (NSString *)passcode
{
    return self.mutablePasscode;
}

- (void)setPasscode:(NSString *)passcode
{
    if (passcode) {
        if (passcode.length > self.maximumLength) {
            passcode = [passcode substringWithRange:NSMakeRange(0, self.maximumLength)];
        }
        self.mutablePasscode = [NSMutableString stringWithString:passcode];
    } else {
        self.mutablePasscode = [NSMutableString string];
    }
    
    [self setNeedsDisplay];
}

#pragma mark - UIKeyInput

- (BOOL)hasText
{
    return (self.mutablePasscode.length > 0);
}

- (void)insertText:(NSString *)text
{
    if (self.enabled == NO) {
        return;
    }
    
    if (self.keyboardType == UIKeyboardTypeNumberPad) {
        text = [self.nonDigitRegularExpression stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    }
    
    if (text.length == 0) {
        return;
    }
    
    NSInteger newLength = self.mutablePasscode.length + text.length;
    if (newLength > self.maximumLength) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(passcodeField:shouldInsertText:)]) {
        if (NO == [self.delegate passcodeField:self shouldInsertText:text]) {
            return;
        }
    }
    
    [self.mutablePasscode appendString:text];

    [self setNeedsDisplay];
    
    [self sendActionsForControlEvents:UIControlEventEditingChanged];
}

- (void)deleteBackward
{
    if (self.enabled == NO) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(passcodeFieldShouldDeleteBackward:)]) {
        if (NO == [self.delegate passcodeFieldShouldDeleteBackward:self]) {
            return;
        }
    }
    
    if (self.mutablePasscode.length == 0) {
        return;
    }
    
    [self.mutablePasscode deleteCharactersInRange:NSMakeRange(self.mutablePasscode.length - 1, 1)];
    
    [self setNeedsDisplay];
   
    [self sendActionsForControlEvents:UIControlEventEditingChanged];
}

- (UITextAutocapitalizationType)autocapitalizationType
{
    return UITextAutocapitalizationTypeNone;
}

- (UITextAutocorrectionType)autocorrectionType
{
    return UITextAutocorrectionTypeNo;
}

- (UITextSpellCheckingType)spellCheckingType
{
    return UITextSpellCheckingTypeNo;
}

- (BOOL)enablesReturnKeyAutomatically
{
    return YES;
}

- (UIReturnKeyType)returnKeyType
{
    return UIReturnKeyDone;
}

- (BOOL)isSecureTextEntry
{
    return YES;
}

#pragma mark - UIView

- (CGSize)contentSize
{
    CGFloat width = self.maximumLength * _dotSize.width + (self.maximumLength - 1) * _dotSpacing;
    if (self.drawsPasscodeSeparator) {
        width += (_dotSpacing + _separatorSize.width);
    }
    
    return CGSizeMake(width ,
                      _dotSize.height);
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGSize contentSize = [self contentSize];
    
    CGPoint origin = CGPointMake(floorf((self.frame.size.width - contentSize.width) * 0.5f),
                                 floorf((self.frame.size.height - contentSize.height) * 0.5f));
    
    if ([self.imageSource respondsToSelector:@selector(passcodeField:dotImageAtIndex:filled:)]) {
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, self.dotColor.CGColor);
        
        for (NSUInteger i = 0; i < self.maximumLength; i++) {
            
            UIImage *image = nil;
            
            if (self.drawsPasscodeSeparator && i > 1 && (floor(self.maximumLength/2) - i) == 0) {
                CGRect lineFrame = CGRectMake(origin.x, origin.y,
                                              self.separatorSize.width, self.separatorSize.height);
                CGContextFillRect(context, lineFrame);
                origin.x += (self.separatorSize.width + self.dotSpacing);
            }
            
            if (i < self.mutablePasscode.length) {
                // draw filled image
                image = [self.imageSource passcodeField:self dotImageAtIndex:i filled:YES];
            } else {
                // draw blank image
                image = [self.imageSource passcodeField:self dotImageAtIndex:i filled:NO];
            }
            
            if (image) {
                CGRect imageFrame = CGRectMake(origin.x, origin.y, self.dotSize.width, self.dotSize.height);
                [image drawInRect:imageFrame];
            }
            
            origin.x += (self.dotSize.width + self.dotSpacing);
        }
        
    } else {
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, self.dotColor.CGColor);
        
        for (NSUInteger i = 0; i < self.maximumLength; i++) {
            if (self.drawsPasscodeSeparator && i > 1 && (floor(self.maximumLength/2) - i) == 0) {
                CGRect lineFrame = CGRectMake(origin.x, origin.y,
                                              self.separatorSize.width, self.separatorSize.height);
                CGContextFillRect(context, lineFrame);
                origin.x += (self.separatorSize.width + self.dotSpacing);
            }
            
            if (i < self.mutablePasscode.length) {
                // draw circle
                CGRect circleFrame = CGRectMake(origin.x, origin.y, self.dotSize.width, self.dotSize.height);
                CGContextFillEllipseInRect(context, circleFrame);
            } else {
                // draw line
                CGRect lineFrame = CGRectMake(origin.x, origin.y + floorf((self.dotSize.height - self.lineHeight) * 0.5f),
                                              self.dotSize.width, self.lineHeight);
                CGContextFillRect(context, lineFrame);
            }
            
            origin.x += (self.dotSize.width + self.dotSpacing);
        }
    }
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return [self contentSize];
}

#pragma mark - UIResponder

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

#pragma mark - Actions

- (void)didTouchUpInside:(id)sender
{
    [self becomeFirstResponder];
}

@end
