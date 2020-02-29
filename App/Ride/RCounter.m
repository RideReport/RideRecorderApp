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
    [super awakeFromNib];
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
        [img setImage:[UIImage imageNamed:@"counter-numbers"]];
        img.layer.anchorPoint = CGPointMake(0, 0);
        [img setTag: (tagCounterRightToLeft - i)];
        [self.counterCanvas addSubview:img];
        frame.origin.x += 25;
    }
    
    [self.counterCanvas.layer setMasksToBounds:YES];
    [self addSubview:self.counterCanvas];
    
    [self updateCounter:self.currentReading animate:NO];
    
    // make the numbers
    CGRect maskRect = CGRectMake(0.0, 0.0, 10 + (self.numberOfDigits * 25), 70.0);
    UIImage *maskImage = [UIImage imageNamed:@"counter-shadow"];

    CALayer *maskLayer = [CALayer new];
    maskLayer.frame = maskRect;
    maskLayer.contents = (__bridge id _Nullable)(maskImage.CGImage);
    self.layer.mask = maskLayer;
}

- (void)layoutSubviews;
{
    [super layoutSubviews];
    
    self.counterCanvas.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    
    CGRect frame = CGRectMake(10.0, kCounterDigitStartY, 17.0, 299.0);
    for (int i = 0; i < self.numberOfDigits; i++) {
        UIImageView *img = (UIImageView*)[self viewWithTag:(tagCounterLeftToRight - i)];
        img.layer.anchorPoint = CGPointMake(0, 0);
        
        frame.origin.x += 25;
    }
}

- (void)_initialize
{
    self.animationDuration = 0.3;
    _numberOfDigits = 3;
    self.currentReading = 1;
}

- (void)prepareForInterfaceBuilder {
    [self _setupCounter];
    [self updateCounter:self.currentReading animate:NO];
    [self layoutSubviews];
}

- (void)incrementCounter;
{
    [self incrementCounter:true];
}

- (void)incrementCounter:(BOOL)animate {
    [self updateCounter:(self.currentReading + 1) animate:animate];
}

-(void)updateFrame:(UIImageView*)img fromImageCenter:(CGPoint)imgCenterFrom toImageCenter:(CGPoint)imgCenterTo andImageFrame:(CGRect)frame {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"position"];
    anim.fromValue = [NSValue valueWithCGPoint:imgCenterFrom];
    anim.toValue = [NSValue valueWithCGPoint:imgCenterTo];
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.duration = self.animationDuration;
    [img.layer addAnimation:anim forKey:@"rollLeft"];
    img.frame = frame;
}

- (void)updateCounter:(NSUInteger)newValue animate:(BOOL)animate {
    // Work out the digits
    int millionsOld = (self.currentReading % 10000000)/1000000;
    int hthousandthOld = (self.currentReading % 1000000)/100000;
    int tenthounsandthOld = (self.currentReading % 100000) / 10000;
    int thounsandthOld = (self.currentReading % 10000)/1000;
    int hundredthOld = (self.currentReading % 1000)/ 100;
    int tenOld = (self.currentReading % 100) / 10;
    int unitOld = self.currentReading % 10;
    
    NSMutableArray *oldValueArray = [[NSMutableArray alloc] init];
    [oldValueArray addObject: [NSNumber numberWithInt:unitOld]];
    [oldValueArray addObject: [NSNumber numberWithInt:tenOld]];
    [oldValueArray addObject: [NSNumber numberWithInt:hundredthOld]];
    [oldValueArray addObject: [NSNumber numberWithInt:thounsandthOld]];
    [oldValueArray addObject: [NSNumber numberWithInt:tenthounsandthOld]];
    [oldValueArray addObject: [NSNumber numberWithInt:hthousandthOld]];
    [oldValueArray addObject: [NSNumber numberWithInt:millionsOld]];
    
    int millionsNew = (newValue % 10000000)/1000000;
    int hthousandthNew = (newValue % 1000000)/100000;
    int tenthounsandthNew = (newValue % 100000) / 10000;
    int thounsandthNew = (newValue % 10000)/1000;
    int hundredthNew = (newValue % 1000)/ 100;
    int tenNew = (newValue % 100) / 10;
    int unitNew = newValue % 10;
    
    NSMutableArray *newValueArray = [[NSMutableArray alloc] init];
    [newValueArray addObject: [NSNumber numberWithInt:unitNew]];
    [newValueArray addObject: [NSNumber numberWithInt:tenNew]];
    [newValueArray addObject: [NSNumber numberWithInt:hundredthNew]];
    [newValueArray addObject: [NSNumber numberWithInt:thounsandthNew]];
    [newValueArray addObject: [NSNumber numberWithInt:tenthounsandthNew]];
    [newValueArray addObject: [NSNumber numberWithInt:hthousandthNew]];
    [newValueArray addObject: [NSNumber numberWithInt:millionsNew]];
    
    
    for (int i = 0; i < self.numberOfDigits; i++) {
        UIImageView *img = (UIImageView*)[self viewWithTag:(tagCounterLeftToRight + i)];
        
        CGRect imgFrame = img.frame;
        CGPoint imgCenterTo = img.center;
        CGPoint imgCenterFrom = img.center;
        
        imgFrame.origin.y = kCounterDigitStartY - (([newValueArray[i] integerValue] + 1) * kCounterDigitDiff);
        imgCenterFrom.y = kCounterDigitStartY - (([oldValueArray[i] integerValue] + 1) * kCounterDigitDiff);
        imgCenterTo.y = kCounterDigitStartY - (([newValueArray[i] integerValue] + 1) * kCounterDigitDiff);
        
        if (imgFrame.origin.y != img.frame.origin.y) {
            if ([newValueArray[i] integerValue] == 0) {
                imgCenterTo.y = kCounterDigitStartY - 11*kCounterDigitDiff;
            }
            
            [self updateFrame:img fromImageCenter:imgCenterFrom toImageCenter:imgCenterTo andImageFrame:imgFrame];
        }

    }

    self.currentReading = newValue;
}

@end
