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
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame andKeys:(NSArray *)keys
{
    self = [super initWithFrame:frame];
    if (!self) return nil;    
    _keys = keys;
    _index = -1;
    _enabled = YES;
    _buttons = [NSMutableArray arrayWithCapacity:keys.count];
    self.backgroundColor = [S1GlobalVariables color3];
    self.bounces = NO;
    self.showsHorizontalScrollIndicator = NO;
    self.scrollsToTop = NO;
    self.delegate = self;
    self.lastRecognizedOrientation = UIDeviceOrientationPortrait;
//    self.decelerationRate = UIScrollViewDecelerationRateFast;
    [self addItems];
    return self;
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

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGFloat widthPerItem;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        widthPerItem = _DEFAULT_WIDTH;
    } else {
        if (self.lastRecognizedOrientation == UIDeviceOrientationPortrait || self.lastRecognizedOrientation == UIDeviceOrientationPortraitUpsideDown) {
            widthPerItem = _DEFAULT_WIDTH_IPAD;
            NSLog(@"Decelerating Portrait");
        } else {
            widthPerItem = _DEFAULT_WIDTH_IPAD_LANDSCAPE;
            NSLog(@"Decelerating Landscape");
        }
    }
    CGPoint offset = scrollView.contentOffset;
    CGFloat n = roundf(offset.x / widthPerItem);
    if ((offset.x - n*widthPerItem) < ((n+1)*widthPerItem -offset.x))
        offset.x = n*widthPerItem;
    else
        offset.x = (n+1)*widthPerItem;
    [scrollView setContentOffset:offset animated:YES];
    return;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    CGFloat widthPerItem;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        widthPerItem = _DEFAULT_WIDTH;
    } else {
        if (self.lastRecognizedOrientation == UIDeviceOrientationPortrait || self.lastRecognizedOrientation == UIDeviceOrientationPortraitUpsideDown) {
            widthPerItem = _DEFAULT_WIDTH_IPAD;
            NSLog(@"Dragging Portrait");
        } else {
            widthPerItem = _DEFAULT_WIDTH_IPAD_LANDSCAPE;
            NSLog(@"Dragging Landscape");
        }
    }
    if (!decelerate) {
        CGPoint offset = scrollView.contentOffset;
        CGFloat n = roundf(offset.x / widthPerItem);
        if ((offset.x - n*widthPerItem) < ((n+1)*widthPerItem -offset.x))
            offset.x = n*widthPerItem;
        else
            offset.x = (n+1)*widthPerItem;
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
        widthPerItem = (_keys.count >= 4 ? _DEFAULT_WIDTH : self.bounds.size.width/_keys.count);
    } else {
        if (self.lastRecognizedOrientation == UIDeviceOrientationPortrait || self.lastRecognizedOrientation == UIDeviceOrientationPortraitUpsideDown) {
            widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD : self.bounds.size.width/_keys.count);
        } else {
            widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD_LANDSCAPE : self.bounds.size.width/_keys.count);
        }
    }
    __block CGFloat width = 0.0;
    [_keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (SYSTEM_VERSION_LESS_THAN(@"7")) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            CGRect rect = CGRectMake(width, 0, widthPerItem, self.bounds.size.height);
            [btn setFrame:CGRectInset(rect, 1.0, 2.0)];
            btn.showsTouchWhenHighlighted = NO;
            [btn setBackgroundImage:[UIImage imageNamed:@"Item.png"] forState:UIControlStateNormal];
            [btn setBackgroundImage:[[UIImage imageNamed:@"Item_highlighted.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 15, 5, 15)] forState:UIControlStateHighlighted];
            [btn setBackgroundImage:[[UIImage imageNamed:@"Item_selected.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 15, 5, 15)] forState:UIControlStateSelected];
            [btn setTitle:[obj description] forState:UIControlStateNormal];
            [btn setTitle:[obj description] forState:UIControlStateHighlighted];
            [btn setTitle:[obj description] forState:UIControlStateSelected];
            btn.titleLabel.textColor = [UIColor whiteColor];
            btn.titleLabel.shadowColor = [UIColor blackColor];
            btn.titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                btn.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
            }
            [btn setTag:idx];
            [btn addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
            [_buttons addObject:btn];
            width += widthPerItem;
            [self addSubview:btn];
        } else {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            CGRect rect = CGRectMake(width, 0.25, widthPerItem, self.bounds.size.height-0.25);
            [btn setFrame:rect];
            btn.showsTouchWhenHighlighted = NO;
            //color2 color7
            [btn setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color1]] forState:UIControlStateNormal];
            [btn setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color10]] forState:UIControlStateSelected];
            [btn setBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color10]] forState:UIControlStateHighlighted];
            
            [btn setTitle:[obj description] forState:UIControlStateNormal];
            //[btn setTitle:[obj description] forState:UIControlStateHighlighted];
            //[btn setTitle:[obj description] forState:UIControlStateSelected];
            [btn setTitleColor:[S1GlobalVariables color3] forState:UIControlStateNormal];
            //btn.titleLabel.shadowColor = [UIColor blackColor];
            //btn.titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
            btn.titleLabel.font = [UIFont systemFontOfSize:14.0];
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                btn.titleLabel.font = [UIFont systemFontOfSize:15.0];
            }
            [btn setTag:idx];
            [btn addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
            [_buttons addObject:btn];
            width += widthPerItem;
            [self addSubview:btn];
            

        }
        
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
                    [btn setFrame:SYSTEM_VERSION_LESS_THAN(@"7")?CGRectInset(rect, 1.0, 2.0):rect];
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
