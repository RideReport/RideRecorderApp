//
//  RCounter.m
//  Version 0.1
//
//
//  Created by Ans Riaz on 12/12/13.
//  Copyright (c) 2013 Rizh. All rights reserved.
//
//  Have fun :-)

#import "RCounter.h"

#define kCounterDigitStartY 22.0
#define kCounterDigitDiff 23.0

@interface RCounter ()
@property (nonatomic, retain) UIView *counterCanvas;
@end

@implementation RCounter {
    NSUInteger tagCounterRightToLeft;
    NSUInteger tagCounterLeftToRight;
}

#pragma mark - Init/Dealloc

- (id)initWithFrame:(CGRect)frame;
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _initialize];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (void)awakeFromNib {
    [self _setupCounter];
}

- (void)setNumberOfDigits:(NSUInteger)numberOfDigits {
    _numberOfDigits = numberOfDigits;
    
    [self _setupCounter];
}

- (void)_setupCounter;
{   
    tagCounterRightToLeft = 4025;
    tagCounterLeftToRight = tagCounterRightToLeft + 1 - self.numberOfDigits;
    
    // Load the background
    [self setBackgroundColor:[UIColor clearColor]];
    
    // Load the counters
    if (self.counterCanvas) {
        [self.counterCanvas removeFromSuperview];
    }
    self.counterCanvas = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height)];
    
    CGRect frame = CGRectMake(10.0, kCounterDigitStartY, 17.0, 299.0);
    for (int i = 0; i < self.numberOfDigits; i++) {
        UIImageView *img = [[UIImageView alloc] initWithFrame:frame];
        [img setImage:[UIImage imageNamed:@"counter-numbers.png"]];
        centerStart = img.center;
        
        [img setTag: (tagCounterRightToLeft - i)];
        [self.counterCanvas addSubview:img];
        frame.origin.x += 25;
    }
    
    [self.counterCanvas.layer setMasksToBounds:YES];
    [self addSubview:self.counterCanvas];
    
    // Add a shadow over top
    UIImageView *shadowOverlay = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 10 + (self.numberOfDigits * 25), 50.0)];
    [shadowOverlay setImage:[UIImage imageNamed:@"counter-shadow.png"]];
    [self addSubview:shadowOverlay];
    [self bringSubviewToFront:shadowOverlay];
    [self updateCounter:self.currentReading animate:NO];
}

- (void)layoutSubviews;
{
    [super layoutSubviews];
    
    self.counterCanvas.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    
    CGRect frame = CGRectMake(10.0, kCounterDigitStartY, 17.0, 299.0);
    for (int i = 0; i < self.numberOfDigits; i++) {
        UIImageView *img = (UIImageView*)[self viewWithTag:(tagCounterLeftToRight - i)];
        centerStart = img.center;
        
        frame.origin.x += 25;
    }
}

- (void)_initialize
{
    _numberOfDigits = 3;
    self.currentReading = 1;
}

- (void)prepareForInterfaceBuilder {
    [self _setupCounter];
    [self updateCounter:self.currentReading animate:NO];
    [self layoutSubviews];
}

- (void)incrementCounter:(BOOL)animate {
    [self updateCounter:(self.currentReading + 1) animate:animate];
}

-(void)updateFrame:(UIImageView*)img withValue:(long)newValue andImageCentre:(CGPoint)imgCentre andImageFrame:(CGRect)frame{
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"position"];
    anim.fromValue = [NSValue valueWithCGPoint:img.center];
    if (newValue == 0) {
        imgCentre.y = centerStart.y - 11 * kCounterDigitDiff;
        anim.toValue = [NSValue valueWithCGPoint:imgCentre];
    } else
        anim.toValue = [NSValue valueWithCGPoint:imgCentre];
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.duration = 0.3;
    [img.layer addAnimation:anim forKey:@"rollLeft"];
    img.frame = frame;
}

- (void)updateCounter:(NSUInteger)newValue animate:(BOOL)animate {
    // Work out the digits
    int hthousandth = (newValue % 1000000)/100000;
    int tenthounsandth = (newValue % 100000) / 10000;
    int thounsandth = (newValue % 10000)/1000;
    int hundredth = (newValue % 1000)/ 100;
    int ten = (newValue % 100) / 10;
    int unit = newValue % 10;
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject: [NSNumber numberWithInt:unit]];
    [array addObject: [NSNumber numberWithInt:ten]];
    [array addObject: [NSNumber numberWithInt:hundredth]];
    [array addObject: [NSNumber numberWithInt:thounsandth]];
    [array addObject: [NSNumber numberWithInt:tenthounsandth]];
    [array addObject: [NSNumber numberWithInt:hthousandth]];
    
    for (int i = 0; i < self.numberOfDigits; i++) {
        UIImageView *img = (UIImageView*)[self viewWithTag:(tagCounterLeftToRight + i)];
        
        CGRect imgFrame = img.frame;
        CGPoint imgCenter = img.center;
        
        CGFloat fudge = 10.0f;
        imgFrame.origin.y = kCounterDigitStartY - (([array[i] integerValue] + 1) * kCounterDigitDiff) - fudge;
        imgCenter.y = centerStart.y - (([array[i] integerValue] + 1) * kCounterDigitDiff) - fudge;
        
        BOOL imgChanged = NO;
        
        if (imgFrame.origin.y != img.frame.origin.y) {
            imgChanged = YES;
        }
        if (imgChanged) {
            [self updateFrame:img withValue:[array[i] integerValue] andImageCentre:imgCenter andImageFrame:imgFrame];
        }
    }

    self.currentReading = newValue;
}

@end
