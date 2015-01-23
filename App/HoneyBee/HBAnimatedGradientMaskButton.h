//
//  HBAnimatedGradientArrowView.h
//  Hopbox
//
//  Created by William Henderson on 8/26/13.
//  Copyright (c) 2013 Serious Software. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum _HBAnimatedGradientMaskButtonAnimationDirection{
    HBAnimatedGradientMaskButtonDirectionUp,
    HBAnimatedGradientMaskButtonDirectionDown
}
HBAnimatedGradientMaskButtonAnimationDirection;

@interface HBAnimatedGradientMaskButton : UIButton

@property (nonatomic, assign) BOOL drawsGreyComponent;
@property (nonatomic, assign) BOOL animates;
@property (nonatomic, assign) HBAnimatedGradientMaskButtonAnimationDirection direction;
@property (nonatomic, retain) UIImage *maskImage;
@property (nonatomic, retain) UIImage *pressStateMaskImage;
@property (nonatomic, retain) UIImage *pressStateOverlayImage;
@property (nonatomic, retain) UIColor *primaryColor;
@property (nonatomic, retain) UIColor *secondaryColor;
@property (nonatomic, retain) UIColor *neutralColor;

- (void)stopAnimating;
- (void)animate;

@end