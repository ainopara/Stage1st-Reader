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
    _buttons = [NSMutableArray arrayWithCapacity:keys.count];
    self.backgroundColor = [UIColor blackColor];
    self.bounces = NO;
    self.showsHorizontalScrollIndicator = NO;
    self.scrollsToTop = NO;
    self.delegate = self;
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
        widthPerItem = _DEFAULT_WIDTH_IPAD;
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
        widthPerItem = _DEFAULT_WIDTH_IPAD;
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
        widthPerItem = (_keys.count >= 8 ? _DEFAULT_WIDTH_IPAD : self.bounds.size.width/_keys.count);
    }
    __block CGFloat width = 0.0;
    [_keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect rect = CGRectMake(width, 0, widthPerItem, self.bounds.size.height);
        [btn setFrame:CGRectInset(rect, 1.0, 2.0)];
        btn.showsTouchWhenHighlighted = NO;
        [btn setBackgroundImage:[UIImage imageNamed:@"Item.png"] forState:UIControlStateNormal];
        [btn setBackgroundImage:[[UIImage imageNamed:@"Item_highlighted.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 15, 5, 15)] forState:UIControlStateSelected];
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
    }];
    
    self.contentSize = CGSizeMake(width, self.bounds.size.height);
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
