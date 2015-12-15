//
//  S1HUD.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/23/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1HUD.h"
#import "UIControl+BlockWrapper.h"
#import "Masonry.h"

typedef enum {
    S1HUDStateShowText,
    S1HUDStateShowControl
} S1HUDState;

@implementation S1HUD {
    S1HUDState _state;
}

+ (S1HUD *)showHUDInView:(UIView *)view
{
    S1HUD *HUD = [[self alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    HUD.center = CGPointMake(roundf(CGRectGetMidX(view.bounds)), roundf(CGRectGetMidY(view.bounds)));
    HUD.alpha = 0.0;
    HUD.transform = CGAffineTransformMakeScale(0.85, 0.85);
    HUD.parentView = view;
    [view addSubview:HUD];
    [HUD mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(view.mas_centerX);
        make.centerY.equalTo(view.mas_centerY);
        make.width.greaterThanOrEqualTo(@80);
        make.height.greaterThanOrEqualTo(@80);
    }];
    [UIView animateWithDuration:0.2 animations:^{
        HUD.alpha = 1.0;
        HUD.transform = CGAffineTransformIdentity;
    }];
    return HUD;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
        _state = S1HUDStateShowControl;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)deviceOrientationDidChange:(id)sender {
    if (self.parentView) {
        self.center = CGPointMake(roundf(CGRectGetMidX(self.parentView.bounds)), roundf(CGRectGetMidY(self.parentView.bounds)));
    }
    
}

- (void)setText:(NSString *)text withWidthMultiplier:(NSUInteger)n
{
    _text = text;
    [self removeSubviews];
    self.bounds = CGRectMake(0, 0, 60 * n, 60);
    [self mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.greaterThanOrEqualTo(@60);
        make.width.greaterThanOrEqualTo(@(60 * n));
    }];
    _state = S1HUDStateShowText;
    [self setNeedsDisplay];
}


- (void)showActivityIndicator
{
    [self removeSubviews];
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    indicatorView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    [self addSubview:indicatorView];
    _state = S1HUDStateShowControl;
    [indicatorView startAnimating];
}

- (void)showRefreshButton
{
    [self removeSubviews];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.alpha = 0.8;
    [button setImage:[UIImage imageNamed:@"Refresh.png"] forState:UIControlStateNormal];
    [button addEventHandler:^(id sender, UIEvent *event) {
        if (self.refreshEventHandler) {
            self.refreshEventHandler(self);
        }
    } forControlEvent:UIControlEventTouchUpInside];
    button.frame = CGRectMake(0, 0, 40, 40);
    button.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    [self addSubview:button];
    _state = S1HUDStateShowControl;
}

- (void)removeSubviews
{
    [self.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIView *view = obj;
        [view removeFromSuperview];
    }];
}

- (void)drawRect:(CGRect)rect
{
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* color = [[APColorManager sharedInstance] colorForKey:@"hud.border"];
    UIColor* gradientColor = [[APColorManager sharedInstance] colorForKey:@"hud.background"];
    UIColor* gradientColor2 = [[APColorManager sharedInstance] colorForKey:@"hud.background"];
    UIColor* textColor = [[APColorManager sharedInstance] colorForKey:@"hud.text"];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientColor.CGColor,
                               (id)gradientColor2.CGColor, nil];
    CGFloat gradientLocations[] = {0, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, gradientLocations);
    
    
    //// Frames
    CGRect frame = rect;
    
    
    //// Abstracted Attributes
    CGRect roundedRectangleRect = CGRectInset(rect, 7.5, 7.5);
    NSString* hUDTextContent = self.text;
    
    
    //// Rounded Rectangle Drawing
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: 3];
    CGContextSaveGState(context);
    CGContextBeginTransparencyLayer(context, NULL);
    [roundedRectanglePath addClip];
    
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMinY(roundedRectangleRect)),
                                CGPointMake(CGRectGetMidX(roundedRectangleRect), CGRectGetMaxY(roundedRectangleRect)),
                                0);
    
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    
    [color setStroke];
    roundedRectanglePath.lineWidth = 0;
    [roundedRectanglePath stroke];
    
    
    //// HUDText Drawing
    if (_state == S1HUDStateShowText) {
        UIFont *textFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:13.0f];
        CGFloat fontHeight = [textFont lineHeight];
        CGRect textRect = CGRectMake(8.0, floorf((frame.size.height-fontHeight)/2), frame.size.width-2*8.0, fontHeight);
        NSMutableParagraphStyle *replyCountParagraphStyle = [[NSMutableParagraphStyle alloc] init];
        replyCountParagraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        replyCountParagraphStyle.alignment = NSTextAlignmentCenter;
        [hUDTextContent drawInRect:textRect withAttributes:@{NSFontAttributeName: textFont,
                                                             NSParagraphStyleAttributeName: replyCountParagraphStyle,
                                                             NSForegroundColorAttributeName: textColor}];
    }
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

- (void)hideWithDelay:(NSTimeInterval)delay
{
    [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         self.alpha = 0.0;
                         self.transform = CGAffineTransformMakeScale(1.2, 1.2);
                     }
                     completion:^(BOOL finished) {
                         [self removeFromSuperview];
                     }];
}

@end
