//
//  S1TabBar.m
//  Stage1st
//
//  Created by Suen Gabriel on 3/2/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TabBar.h"

#define _DEFAULT_WIDTH 80.0f
#define _DEFAULT_WIDTH_IPAD 96.0f
#define _DEFAULT_WIDTH_IPAD_LANDSCAPE 128.0f

@interface S1TabBar ()
- (CGFloat) determineWidthPerItemAndUpdateLastRecognizedOrientation;
@end

@implementation S1TabBar {
    NSMutableArray *_buttons;
    NSInteger _index;
    CGFloat _lastContentOffset;
}

- (id)initWithFrame:(CGRect)frame andKeys:(NSArray *)keys
{
    self = [super initWithFrame:frame];
    if (self) {
        _keys = keys;
        _index = -1;
        _enabled = YES;
        _buttons = [NSMutableArray arrayWithCapacity:keys.count];
        self.backgroundColor = [S1GlobalVariables color3];
        self.canCancelContentTouches = YES;
        self.bounces = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.scrollsToTop = NO;
        self.delegate = self;
        self.lastRecognizedOrientation = UIDeviceOrientationPortrait;
        //self.decelerationRate = UIScrollViewDecelerationRateFast;
        [self addItems];
    }
    return self;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    return YES;
}

- (void)setKeys:(NSArray *)keys
{
    [self.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [(UIView *)obj removeFromSuperview];
    }];
    [self setContentSize:CGSizeMake(0.0f, 0.0f)];
    _keys = keys;
    _index = -1;
    if (_keys.count == 0) {
        UIToolbar *maskToolbar = [[UIToolbar alloc] initWithFrame:self.bounds];
        [self addSubview:maskToolbar];
    } else {
        _buttons = [NSMutableArray arrayWithCapacity:_keys.count];
        [self addItems];
    }
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _lastContentOffset = scrollView.contentOffset.x;
    NSLog(@"Begin Dragging:%f", _lastContentOffset);
}
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    _lastContentOffset = scrollView.contentOffset.x;
    NSLog(@"Begin Decelerating:%f", _lastContentOffset);
}

- (CGFloat)getWidthPerItem {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return _DEFAULT_WIDTH;
    } else {
        if (self.lastRecognizedOrientation == UIDeviceOrientationPortrait || self.lastRecognizedOrientation == UIDeviceOrientationPortraitUpsideDown) {
            NSLog(@"Decelerating Portrait");
            return _DEFAULT_WIDTH_IPAD;
            
        } else {
            NSLog(@"Decelerating Landscape");
            return _DEFAULT_WIDTH_IPAD_LANDSCAPE;
        }
    }
}

- (CGFloat)decideOffset:(CGPoint)offset {
    CGFloat widthPerItem = [self getWidthPerItem];
    float maxOffset = _keys.count * _DEFAULT_WIDTH - self.bounds.size.width;

    if (_lastContentOffset == 0 && offset.x == 0) {
        offset.x = 0.0;
        return offset.x;
    }
    if (offset.x < _lastContentOffset) {
        CGFloat n = floorf(offset.x / widthPerItem);
        if (fmodf(offset.x, widthPerItem) < widthPerItem / 2) {
            offset.x = n * widthPerItem;
        } else {
            offset.x = (n + 1) * widthPerItem;
        }
    } else {
        float offsetFix = _DEFAULT_WIDTH - fmodf(maxOffset, _DEFAULT_WIDTH);
        CGFloat n = floorf((offset.x + offsetFix) / widthPerItem);
        if (((offset.x + offsetFix) - n*widthPerItem) < ((n+1)*widthPerItem -(offset.x + offsetFix))) {
            offset.x = n*widthPerItem - offsetFix;
        } else {
            offset.x = (n+1)*widthPerItem - offsetFix;
        }
    }
    
    offset.x = offset.x > maxOffset ? maxOffset : offset.x;
    offset.x = offset.x < 0 ? 0.0 : offset.x;
    return offset.x;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGPoint offset = scrollView.contentOffset;
    NSLog(@"End Decelerating:%f", offset.x);
    offset.x = [self decideOffset:offset];
    NSLog(@"Target Decelerating:%f", offset.x);
    [scrollView setContentOffset:offset animated:YES];
    return;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        CGPoint offset = scrollView.contentOffset;
        NSLog(@"End Dragging:%f", offset.x);
        offset.x = [self decideOffset:offset];
        NSLog(@"Target Dragging:%f", offset.x);
        [scrollView setContentOffset:offset animated:YES];
    }
    return;
}

- (void)tapped:(UIButton *)sender
{
    if (!_enabled) return;
    if (_index >= 0)
        [_buttons[_index] setSelected:NO];
    _index = sender.tag;
    sender.selected = YES;
    [self.tabbarDelegate tabbar:self didSelectedKey:self.keys[_index]];
    return;
}

- (void)deselectAll
{
    if (_index >= 0) {
        [[_buttons objectAtIndex:_index] setSelected:NO];
        _index = -1;
    }
}

- (void)addItems
{
    if (_keys.count == 0) return;

    CGFloat widthPerItem;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        widthPerItem = (_keys.count * _DEFAULT_WIDTH >= self.bounds.size.width ? _DEFAULT_WIDTH : self.bounds.size.width/_keys.count);
    } else {
        if (self.lastRecognizedOrientation == UIDeviceOrientationPortrait || self.lastRecognizedOrientation == UIDeviceOrientationPortraitUpsideDown) {
            widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD : self.bounds.size.width/_keys.count);
        } else {
            widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD_LANDSCAPE : self.bounds.size.width/_keys.count);
        }
    }
    __block CGFloat width = 0.0;
    [_keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect rect = CGRectMake(width, 0.25, ceilf(widthPerItem), self.bounds.size.height-0.25);
        [btn setFrame:rect];
        btn.showsTouchWhenHighlighted = NO;
        //color2 color7
        [btn setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color1]] forState:UIControlStateNormal];
        [btn setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color10]] forState:UIControlStateSelected];
        [btn setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color10]] forState:UIControlStateHighlighted];
        
        [btn setTitle:[obj description] forState:UIControlStateNormal];
        [btn setTitleColor:[S1GlobalVariables color3] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14.0];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            btn.titleLabel.font = [UIFont systemFontOfSize:15.0];
        }
        [btn setTag:idx];
        [btn addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [_buttons addObject:btn];
        width += widthPerItem;
        [self addSubview:btn];
        
    }];
    
    self.contentSize = CGSizeMake(width, self.bounds.size.height);
}

- (void)updateButtonFrame
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        ;
    } else {
        CGFloat widthPerItem = [self determineWidthPerItemAndUpdateLastRecognizedOrientation];
        if (widthPerItem != 0) {
            NSInteger maxIndex = 0;
            NSArray * subviews = [self subviews];
            for(id obj in subviews)
            {
                if ([obj isMemberOfClass:[UIButton class]]) {
                    UIButton *btn = (UIButton *)obj;
                    NSInteger idx = btn.tag;
                    CGRect rect = CGRectMake(widthPerItem * idx, 0.25, widthPerItem, self.bounds.size.height-0.25);
                    [btn setFrame:rect];
                    if (idx > maxIndex) {
                        maxIndex = idx;
                    }
                }
            }
            [self setContentSize:CGSizeMake(widthPerItem * (maxIndex + 1), self.bounds.size.height)];
        }
    }
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/
- (CGFloat) determineWidthPerItemAndUpdateLastRecognizedOrientation
{
    CGFloat widthPerItem = 0;
    NSInteger orientation = [[UIDevice currentDevice] orientation];
    if (orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationPortraitUpsideDown) {
        widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD : 768.0f/_keys.count);
        NSLog(@"Portrait");
        self.lastRecognizedOrientation = orientation;
    } else if(orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight) {
        widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD_LANDSCAPE : 1024.0f/_keys.count);
        NSLog(@"Landscape");
        self.lastRecognizedOrientation = orientation;
    } else {
        NSLog(@"Other Orientation");
    }
    return widthPerItem;
}
@end
