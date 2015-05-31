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

@end

@implementation S1TabBar {
    NSMutableArray *_buttons;
    NSInteger _index;
    CGFloat _lastContentOffset;
    CGFloat _lastFrameWidth;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _index = -1;
        _lastFrameWidth = 0;
        _enabled = YES;
        self.backgroundColor = [S1Global color3];
        self.canCancelContentTouches = YES;
        self.bounces = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.scrollsToTop = NO;
        self.delegate = self;
        //self.decelerationRate = UIScrollViewDecelerationRateFast;
    }
    return self;
}
//Init from Storyboard
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _index = -1;
        _lastFrameWidth = 0;
        _enabled = YES;
        self.backgroundColor = [S1Global color3];
        self.canCancelContentTouches = YES;
        self.bounces = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.scrollsToTop = NO;
        self.delegate = self;
        //self.decelerationRate = UIScrollViewDecelerationRateFast;
    }
    return self;
}




- (void)setKeys:(NSArray *)keys
{
    [self.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [(UIView *)obj removeFromSuperview];
    }];
    _keys = keys;
    _index = -1;
    if (_keys.count == 0) {
        UIToolbar *maskToolbar = [[UIToolbar alloc] initWithFrame:self.bounds];
        [self addSubview:maskToolbar];
        self.contentSize = CGSizeMake(0, 0);
    } else {
        _buttons = [NSMutableArray arrayWithCapacity:_keys.count];
        [self addItems];
    }
}

- (void)addItems
{
    if (_keys.count == 0) return;
    
    CGFloat widthPerItem;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        widthPerItem = (_keys.count * _DEFAULT_WIDTH >= self.bounds.size.width ? _DEFAULT_WIDTH : self.bounds.size.width/_keys.count);
    } else {
        widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD : self.bounds.size.width/_keys.count); //will be overwrited by layoutsubviews.
    }
    __block CGFloat width = 0.0;
    [_keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect rect = CGRectMake(width, 0.25, ceilf(widthPerItem), self.bounds.size.height-0.25);
        [btn setFrame:rect];
        btn.showsTouchWhenHighlighted = NO;
        //color2 color7
        [btn setBackgroundImage:[S1Global imageWithColor:[S1Global color1]] forState:UIControlStateNormal];
        [btn setBackgroundImage:[S1Global imageWithColor:[S1Global color10]] forState:UIControlStateSelected];
        [btn setBackgroundImage:[S1Global imageWithColor:[S1Global color10]] forState:UIControlStateHighlighted];
        
        [btn setTitle:[obj description] forState:UIControlStateNormal];
        [btn setTitleColor:[S1Global color3] forState:UIControlStateNormal];
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
    //update content size when user change keys in settings.
    self.contentSize = CGSizeMake(width, self.bounds.size.height);
}

#pragma mark - Scroll View Delegate





- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _lastContentOffset = scrollView.contentOffset.x;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        CGPoint offset = scrollView.contentOffset;
        offset.x = [self decideOffset:offset];
        [scrollView setContentOffset:offset animated:YES];
    }
    return;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    _lastContentOffset = scrollView.contentOffset.x;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGPoint offset = scrollView.contentOffset;
    offset.x = [self decideOffset:offset];
    [scrollView setContentOffset:offset animated:YES];
    return;
}

- (void)scrollViewDidScroll:(UIScrollView *)aScrollView
{
    [aScrollView setContentOffset: CGPointMake(aScrollView.contentOffset.x, 0.0f)];
}

#pragma mark - Action

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

#pragma mark - Layout

- (void)layoutSubviews {
    if (self.frame.size.width == _lastFrameWidth) {
        return;
    }
    NSLog(@"Tabbar layout for width:%.1f", self.frame.size.width);
    CGFloat widthPerItem = [self determineWidthPerItem];
    NSInteger maxIndex = 0;
    NSArray * subviews = [self subviews];
    for(id obj in subviews) {
        if ([obj isMemberOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)obj;
            NSInteger index = btn.tag;
            CGRect rect = CGRectMake(widthPerItem * index, 0.25, ceilf(widthPerItem), self.bounds.size.height-0.25);
            [btn setFrame:rect];
            if (index > maxIndex) {
                maxIndex = index;
            }
        }
    }
    [self setContentSize:CGSizeMake(widthPerItem * (maxIndex + 1), self.bounds.size.height)];
    _lastFrameWidth = self.frame.size.width;
    
}

#pragma mark - Helper

- (CGFloat)getWidthPerItemForScroll {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return _DEFAULT_WIDTH;
    } else {
        if (self.bounds.size.width <= 768.0f) {
            return _DEFAULT_WIDTH_IPAD;
        } else {
            return _DEFAULT_WIDTH_IPAD_LANDSCAPE;
        }
    }
}

- (CGFloat)decideOffset:(CGPoint)offset {
    CGFloat widthPerItem = [self getWidthPerItemForScroll];
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

- (CGFloat) determineWidthPerItem
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        CGFloat screenWidth = self.bounds.size.width;
        if (_keys.count < 8) {
            return screenWidth/_keys.count;
        } else if (screenWidth <= 768.0f) {
            return _DEFAULT_WIDTH_IPAD;
        } else {
            return _DEFAULT_WIDTH_IPAD_LANDSCAPE;
        }
    } else {
        return (_keys.count * _DEFAULT_WIDTH >= self.bounds.size.width ? _DEFAULT_WIDTH : self.bounds.size.width/_keys.count);
    }
}
- (void)setSelectedIndex:(NSInteger)index {
    if (index < 0 || index >= [_buttons count]) {
        return;
    }
    if (_index >= 0) {
        [_buttons[_index] setSelected:NO];
    }
    _index = index;
    [_buttons[_index] setSelected:YES];
    [self scrollRectToVisible:[_buttons[_index] frame] animated:YES];
    
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    return YES;
}
@end
