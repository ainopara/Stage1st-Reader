//
//  S1TabBar.m
//  Stage1st
//
//  Created by Suen Gabriel on 3/2/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TabBar.h"

@implementation S1TabBar {
    NSMutableArray *_buttons;
    NSInteger _index;
    CGFloat _lastContentOffset;
    CGFloat _lastFrameWidth;
    BOOL _needRecalculateButtonWidth;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _index = -1;
        _lastFrameWidth = 0;
        _enabled = YES;
        _needRecalculateButtonWidth = YES;
        _minButtonWidth = [NSNumber numberWithDouble:80.0];
        _expectPresentingButtonCount = [NSNumber numberWithInteger:8];
        self.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"tabbar.background"];
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
        _needRecalculateButtonWidth = YES;
        _minButtonWidth = [NSNumber numberWithDouble:80.0];
        _expectPresentingButtonCount = [NSNumber numberWithInteger:8];
        self.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"tabbar.background"];
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
    
    __block CGFloat width = 0.0;
    [_keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect rect = CGRectMake(width, 0.25, 80.0, self.bounds.size.height-0.25); // The Width will be reset by layoutSubviews
        [btn setFrame:rect];
        btn.showsTouchWhenHighlighted = NO;
        
        [btn setBackgroundImage:[S1Global imageWithColor:[[APColorManager sharedInstance] colorForKey:@"tabbar.button.background.normal"]] forState:UIControlStateNormal];
        [btn setBackgroundImage:[S1Global imageWithColor:[[APColorManager sharedInstance] colorForKey:@"tabbar.button.background.selected"]] forState:UIControlStateSelected];
        [btn setBackgroundImage:[S1Global imageWithColor:[[APColorManager sharedInstance]  colorForKey:@"tabbar.button.background.highlighted"]] forState:UIControlStateHighlighted];
        
        [btn setTitle:[obj description] forState:UIControlStateNormal];
        [btn setTitleColor:[[APColorManager sharedInstance] colorForKey:@"tabbar.button.tint"] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14.0];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            btn.titleLabel.font = [UIFont systemFontOfSize:15.0];
        }
        [btn setTag:idx];
        [btn addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [_buttons addObject:btn];
        width += 80.0; // The Width will be reset by layoutSubviews
        [self addSubview:btn];
        
    }];
    //update content size when user change keys in settings.
    self.contentSize = CGSizeMake(width, self.bounds.size.height);
    _needRecalculateButtonWidth = YES;
}

#pragma mark - Scroll View Delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _lastContentOffset = scrollView.contentOffset.x;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        CGPoint offset = [self decideOffset:scrollView.contentOffset];
        [scrollView setContentOffset:offset animated:YES];
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    _lastContentOffset = scrollView.contentOffset.x;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGPoint offset = [self decideOffset:scrollView.contentOffset];
    [scrollView setContentOffset:offset animated:YES];
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
    if (self.frame.size.width == _lastFrameWidth && !_needRecalculateButtonWidth) {
        return;
    }
    // NSLog(@"Tabbar layout for width:%.1f", self.frame.size.width);
    CGFloat widthPerItem = [self determineWidthPerItem];
    NSInteger maxIndex = 0;
    for(UIButton *button in _buttons) {
        NSInteger index = button.tag;
        CGRect rect = CGRectMake(widthPerItem * index, 0.25, ceilf(widthPerItem) + 1, self.bounds.size.height-0.25);
        [button setFrame:rect];
        if (index > maxIndex) {
            maxIndex = index;
        }
    }
    [self setContentSize:CGSizeMake(widthPerItem * (maxIndex + 1), self.bounds.size.height)];
    _lastFrameWidth = self.frame.size.width;
    _needRecalculateButtonWidth = NO;
}

#pragma mark - Helper

- (CGPoint)decideOffset:(CGPoint)offset {
    CGFloat widthPerItem = [self determineWidthPerItem];
    float maxOffset = _keys.count * widthPerItem - self.bounds.size.width;
    
    if (_lastContentOffset == 0 && offset.x == 0) {
        offset.x = 0.0;
        return offset;
    }
    if (offset.x < _lastContentOffset) {
        CGFloat n = floorf(offset.x / widthPerItem);
        if (fmodf(offset.x, widthPerItem) < widthPerItem / 2) {
            offset.x = n * widthPerItem;
        } else {
            offset.x = (n + 1) * widthPerItem;
        }
    } else {
        float offsetFix = widthPerItem - fmodf(maxOffset, widthPerItem);
        CGFloat n = floorf((offset.x + offsetFix) / widthPerItem);
        if (((offset.x + offsetFix) - n*widthPerItem) < ((n+1)*widthPerItem -(offset.x + offsetFix))) {
            offset.x = n*widthPerItem - offsetFix;
        } else {
            offset.x = (n+1)*widthPerItem - offsetFix;
        }
    }
    
    offset.x = offset.x > maxOffset ? maxOffset : offset.x;
    offset.x = offset.x < 0 ? 0.0 : offset.x;
    return offset;
}

- (CGFloat) determineWidthPerItem
{
    CGFloat screenWidth = self.bounds.size.width;
    CGFloat keyCountWidth = screenWidth / [_keys count];
    CGFloat expectWidth = fmaxf([self.minButtonWidth doubleValue], screenWidth / [self.expectPresentingButtonCount integerValue]);
    return fmaxf(keyCountWidth, expectWidth);
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


- (void)updateColor {
    self.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"tabbar.background"];
    for (UIButton *btn in _buttons) {
        [btn setBackgroundImage:[S1Global imageWithColor:[[APColorManager sharedInstance] colorForKey:@"tabbar.button.background.normal"]] forState:UIControlStateNormal];
        [btn setBackgroundImage:[S1Global imageWithColor:[[APColorManager sharedInstance] colorForKey:@"tabbar.button.background.selected"]] forState:UIControlStateSelected];
        [btn setBackgroundImage:[S1Global imageWithColor:[[APColorManager sharedInstance]  colorForKey:@"tabbar.button.background.highlighted"]] forState:UIControlStateHighlighted];
        [btn setTitleColor:[[APColorManager sharedInstance] colorForKey:@"tabbar.button.tint"] forState:UIControlStateNormal];
    }
    
    
}
@end
