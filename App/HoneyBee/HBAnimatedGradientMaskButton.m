//
//  HBAnimatedGradientArrowView.m
//  Hopbox
//
//  Created by William Henderson on 8/26/13.
//  Copyright (c) 2013 Serious Software. All rights reserved.
//

#import "HBAnimatedGradientMaskButton.h"

static float animationTimeInterval = 0.016;
static float animationInterval = 0.004;
static float gradientLengthMultiplier = 1.8;
static float gradientLengthMultiplierWithGrey = 0.8;
static float animationTimeCurve(float progress) {
    return 3.0 * pow(progress, 4);
}
static float animationTimeCurveWithGrey(float progress) {
    return 2.0 * pow(progress, 4);
}

@interface HBAnimatedGradientMaskButton ()

@property (nonatomic, retain) NSTimer *animationTimer;
@property (nonatomic, assign) float animationProgress;
@property (nonatomic, assign) float animationProgress2;

@end

@implementation HBAnimatedGradientMaskButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        self.primaryColor = [UIColor colorWithRed:112.0/255.0 green:234.0/255.0 blue:176.0/255.0 alpha:1.0];
        self.secondaryColor = [UIColor colorWithRed:116.0/255.0 green:207.0/255.0 blue:230.0/255.0 alpha:1.0];
        self.neutralColor = [UIColor clearColor];
    }
    return self;
}

- (void)dealloc;
{
    [self.animationTimer invalidate];
    self.animationTimer = nil;
    
    self.primaryColor = nil;
    self.secondaryColor = nil;
    self.neutralColor = nil;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    if (newWindow) {
        [self animate];
    } else {
        [self stopAnimating];
    }
}

- (void)animate;
{
    [self stopAnimating];
    
    self.animationProgress = 0;
    self.animationProgress2 = 0.5;
    self.animationTimer = [NSTimer timerWithTimeInterval:animationTimeInterval target:self selector:@selector(animateFrame) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.animationTimer forMode:NSDefaultRunLoopMode];

}

- (void)stopAnimating;
{
    [self.animationTimer invalidate];
    self.animationTimer = nil;
}

- (void)animateFrame;
{
    self.animationProgress += animationInterval;
    self.animationProgress2 += animationInterval;
    if (self.animationProgress > 1.0) {
        self.animationProgress = 0.0;
    }
    if (self.animationProgress2 > 1.0) {
        self.animationProgress2 = 0.0;
    }

    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)dirtyRect
{
    CGRect rect = [self bounds];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIImage *imageToMaskWith = self.maskImage;
    if (self.state == UIControlStateHighlighted && self.pressStateMaskImage) {
        imageToMaskWith = self.pressStateMaskImage;
    }
    
    CGContextSaveGState(context);
    
    if (self.direction == HBAnimatedGradientMaskButtonDirectionUp) {
        CGContextTranslateCTM(context, 0, rect.size.height);
        CGContextScaleCTM(context, 1.0, -1.0);
    }

    CGContextClipToMask(context, rect, imageToMaskWith.CGImage);

    CGGradientRef gradient;
    CGColorSpaceRef baseSpace = CGColorSpaceCreateDeviceRGB();

    if (self.state != UIControlStateHighlighted && self.drawsGreyComponent) {
        CFArrayRef colors = (__bridge CFArrayRef)@[(id)self.neutralColor.CGColor,
                               (id)self.primaryColor.CGColor,
                               (id)self.secondaryColor.CGColor,
                               (id)self.neutralColor.CGColor];
        CGFloat locations[] = {0.0,
            0.3,
            0.7,
            1.0};
        CGContextSetFillColorWithColor(context, self.neutralColor.CGColor);
        
        gradient = CGGradientCreateWithColors(baseSpace, colors, locations);
    } else {
        CFArrayRef colors = (__bridge CFArrayRef)@[(id)self.primaryColor.CGColor,
                                          (id)self.secondaryColor.CGColor,
                                          (id)self.primaryColor.CGColor];
        CGFloat locations[] = {0.0,
            0.65,
            1.0};
        
        CGContextSetFillColorWithColor(context, self.primaryColor.CGColor);
        gradient = CGGradientCreateWithColors(baseSpace, colors, locations);
    }
    
    CGColorSpaceRelease(baseSpace), baseSpace = NULL;
    CGContextFillRect(context, rect);
    
    CGFloat endY = animationTimeCurve(self.animationProgress) * CGRectGetMaxY(rect);
    if (self.state != UIControlStateHighlighted && self.drawsGreyComponent) {
        endY = animationTimeCurveWithGrey(self.animationProgress) * CGRectGetMaxY(rect);
    }
    
    CGFloat multiplier = gradientLengthMultiplier;
    if (self.state != UIControlStateHighlighted && self.drawsGreyComponent) {
        multiplier = gradientLengthMultiplierWithGrey;
    }
    
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), endY - CGRectGetHeight(rect)*multiplier);
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), endY);
    
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);

    endY = animationTimeCurve(self.animationProgress2)* CGRectGetMaxY(rect);
    if (self.state != UIControlStateHighlighted && self.drawsGreyComponent) {
        endY = animationTimeCurveWithGrey(self.animationProgress2) * CGRectGetMaxY(rect);
    }
    
    CGPoint startPoint2 = CGPointMake(CGRectGetMidX(rect), endY - CGRectGetHeight(rect)*multiplier);
    CGPoint endPoint2 = CGPointMake(CGRectGetMidX(rect), endY);
    CGContextDrawLinearGradient(context, gradient, startPoint2, endPoint2, 0);
    CGGradientRelease(gradient), gradient = NULL;
    
    CGContextRestoreGState(context);
    
    if (self.state == UIControlStateHighlighted && self.pressStateOverlayImage) {
        [self.pressStateOverlayImage drawAtPoint:CGPointZero];
    }
}


@end
