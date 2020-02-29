//
//  UILabel+HBAdditions.m
//  Hopbox
//
//  Created by admin on 8/1/13.
//  Copyright (c) 2013 Knock, LLC. All rights reserved.
//

#import "UILabel+HBAdditions.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

static NSTimeInterval fadeDuration = 0.3;

@interface MGMushParser : NSObject

@property (nonatomic, copy) NSString *mush;
@property (nonatomic, retain) UIFont *baseFont;

+ (NSAttributedString *)attributedStringFromMush:(NSString *)markdown withBaseAttributes:(NSDictionary *)baseAttributres;
- (void)parseWithBaseAttributes:(NSDictionary *)baseAttributres;
- (NSAttributedString *)attributedString;

@end

@implementation UILabel (HBAdditions)

- (NSString *)markdownStringValue;
{
    return self.text;
}

- (UILabel *)animatedSetMarkdownStringValue:(NSString *)markdownString;
{
    [self animatedSetMarkdownStringValue:markdownString completionBlock:nil];
    
    return self;
}

- (UILabel *)animatedSetMarkdownStringValue:(NSString *)markdownString completionBlock:(void (^)(void))block;
{
    NSDictionary *baseAttributes = [self.attributedText attributesAtIndex:0 effectiveRange:NULL];
    NSAttributedString *attributedString = [MGMushParser attributedStringFromMush:markdownString withBaseAttributes:baseAttributes];
    
    if ([[self text] isEqual:attributedString.string])
    {
        return self;
    }
    
    [CATransaction begin];
    CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [CATransaction setCompletionBlock:^{
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            if (block != nil) {
                block();
            }
        }];
        self.markdownStringValue = markdownString;
        
        CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        fadeAnimation.fromValue = @0.0;
        fadeAnimation.toValue = @1.0;
        fadeAnimation.duration = fadeDuration;
        [self.layer addAnimation:fadeAnimation forKey:@"fadeIn"];
        [CATransaction commit];
        self.layer.opacity = 1.0;
    }];
    
    fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    fadeAnimation.fromValue = @1.0;
    fadeAnimation.toValue = @0.0;
    fadeAnimation.duration = fadeDuration;
    [self.layer addAnimation:fadeAnimation forKey:@"fadeOut"];
    self.layer.opacity = 0.0;
    [CATransaction commit];
    
    return self;
}

- (void)setMarkdownStringValue:(NSString *)markdownString;
{
    // force baseAttributes to be plain style of label's font family/size.
    NSDictionary *baseAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont fontWithName:self.font.familyName size:self.font.pointSize], NSFontAttributeName, self.textColor, NSForegroundColorAttributeName, nil];
    
    [self setAttributedText:[MGMushParser attributedStringFromMush:markdownString withBaseAttributes:baseAttributes]];
}

@end


@implementation MGMushParser {
    NSMutableAttributedString *working;
    UIFont *bold, *italic, *monospace;
}

- (id)initWithTextile:(NSString *)markdown {
    self = [self init];
    working = [[NSMutableAttributedString alloc] initWithString:markdown];
    return self;
}

+ (NSAttributedString *)attributedStringFromMush:(NSString *)markdown withBaseAttributes:(NSDictionary *)baseAttributres
{
    MGMushParser *parser = [[MGMushParser alloc] init];
    parser.mush = markdown;
    parser.baseFont = [baseAttributres objectForKey:NSFontAttributeName];

    [parser parseWithBaseAttributes:baseAttributres];

    return parser.attributedString;
}

- (void)parseWithBaseAttributes:(NSDictionary *)baseAttributres {
    
    // apply base colour and font
    [working addAttributes:baseAttributres range:(NSRange){0, working.length}];
    UIFont *baseFont = [baseAttributres objectForKey:NSFontAttributeName];
    NSString *fontName = baseFont.fontName;
    if ([fontName hasSuffix:@"-Bold"]) {
        fontName = [[fontName componentsSeparatedByString:@"-"] objectAtIndex:0];
    } else if ([fontName hasSuffix:@"-Regular"]) {
        fontName = [[[fontName componentsSeparatedByString:@"-"] objectAtIndex:0] stringByAppendingString:@"-Light"];
    }
    
    UIFont *font = [UIFont fontWithName:fontName size:baseFont.pointSize];
    
    if (font) {
        [working addAttribute:NSFontAttributeName value:font range:(NSRange){0, working.length}];
    }
    
    [working addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:67.0/255 green:67.0/255 blue:67.0/255 alpha:1.0] range:(NSRange){0, working.length}];
    
    // patterns
    id boldParser = @{
                      @"regex":@"(\\*{2})(.+?)(\\*{2})",
                      @"replace":@[@"", @1, @""],
                      @"attributes":@[@{ }, @{ NSFontAttributeName:bold, NSForegroundColorAttributeName:[UIColor colorWithRed:67.0/255 green:67.0/255 blue:67.0/255 alpha:1.0]}, @{ }]
                      };
    
    id italicParser = @{
                        @"regex":@"(/{2})(.+?)(/{2})",
                        @"replace":@[@"", @1, @""],
                        @"attributes":@[@{ }, @{ NSFontAttributeName:italic }, @{ }]
                        };
    
    id underlineParser = @{
                           @"regex":@"(_{2})(.+?)(_{2})",
                           @"replace":@[@"", @1, @""],
                           @"attributes":@[@{ }, @{ NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle) }, @{ }]
                           };
    
    id monospaceParser = @{
                           @"regex":@"(`)(.+?)(`)",
                           @"replace":@[@"", @1, @""],
                           @"attributes":@[@{ }, @{ NSFontAttributeName:monospace }, @{ }]
                           };
    
    [self applyParser:boldParser];
    [self applyParser:italicParser];
    [self applyParser:underlineParser];
    [self applyParser:monospaceParser];
}

- (void)applyParser:(NSDictionary *)parser {
    id regex = [NSRegularExpression regularExpressionWithPattern:parser[@"regex"]
                                                         options:0 error:nil];
    NSString *markdown = working.string.copy;
    
    __block int nudge = 0;
    [regex enumerateMatchesInString:markdown options:0
                              range:(NSRange){0, markdown.length}
                         usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                      BOOL *stop) {
                             
                             NSMutableArray *substrs = [NSMutableArray array];
                             NSMutableArray *replacements = [NSMutableArray array];
                             
                             // fetch match substrings
                             for (int i = 0; i < match.numberOfRanges - 1; i++) {
                                 NSRange nudged = [match rangeAtIndex:i + 1];
                                 nudged.location -= nudge;
                                 substrs[i] = [self->working attributedSubstringFromRange:nudged].mutableCopy;
                             }
                             
                             // make replacement substrings
                             for (int i = 0; i < match.numberOfRanges - 1; i++) {
                                 NSString *repstr = parser[@"replace"][i];
                                 replacements[i] = [repstr isKindOfClass:NSNumber.class]
                                 ? substrs[repstr.intValue]
                                 : [[NSMutableAttributedString alloc] initWithString:repstr];
                             }
                             
                             // apply attributes
                             for (int i = 0; i < match.numberOfRanges - 1; i++) {
                                 id attributes = parser[@"attributes"][i];
                                 if (attributes) {
                                     NSMutableAttributedString *repl = replacements[i];
                                     [repl addAttributes:attributes range:(NSRange){0, repl.length}];
                                 }
                             }
                             
                             // replace
                             for (int i = 0; i < match.numberOfRanges - 1; i++) {
                                 NSRange nudged = [match rangeAtIndex:i + 1];
                                 nudged.location -= nudge;
                                 nudge += [substrs[i] length] - [replacements[i] length];
                                 [self->working replaceCharactersInRange:nudged
                                              withAttributedString:replacements[i]];
                             }
                         }];
}

#pragma mark - Setters

- (void)setMush:(NSString *)mush {
    _mush = mush;
    working = [[NSMutableAttributedString alloc] initWithString:mush];
}

- (void)setBaseFont:(UIFont *)font {
    _baseFont = font;
    
    if (!font) {
        return;
    }
    
    // base ctfont
    CGFloat size = font.pointSize;
    NSString *name = font.fontName;
    CTFontRef ctBase = CTFontCreateWithName((__bridge CFStringRef)name, size, NULL);
    
    // bold font
    CTFontRef ctBold = CTFontCreateCopyWithSymbolicTraits(ctBase, 0, NULL,
                                                          kCTFontBoldTrait, kCTFontBoldTrait);
    NSString *boldName = (__bridge NSString *)CTFontCopyName(ctBold, kCTFontPostScriptNameKey);
    if (!boldName && [name hasSuffix:@"-Light"]) {
        boldName = [[[name componentsSeparatedByString:@"-"] objectAtIndex:0] stringByAppendingString:@"-Regular"];
    }
    bold = [UIFont fontWithName:boldName size:size] ?: font;
    
    // italic font
    CTFontRef ctItalic = CTFontCreateCopyWithSymbolicTraits(ctBase, 0, NULL,
                                                            kCTFontItalicTrait, kCTFontItalicTrait);
    NSString *italicName = (__bridge NSString *)CTFontCopyName(ctItalic, kCTFontPostScriptNameKey);
    italic = [UIFont fontWithName:italicName size:size] ?: font;
    
    monospace = [UIFont fontWithName:@"CourierNewPSMT" size:size] ?: font;
    
    // Release CF objects no longer needed
    if (ctBase) CFRelease(ctBase);
    if (ctBold) CFRelease(ctBold);
    if (ctItalic) CFRelease(ctItalic);
}

#pragma mark - Getters

- (NSAttributedString *)attributedString {
    return working;
}

@end