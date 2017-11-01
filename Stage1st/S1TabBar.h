//
//  S1TabBar.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/2/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol S1TabBarDelegate;

// TODO: Rewrite this in swift.
@interface S1TabBar : UIScrollView <UIScrollViewDelegate>

@property (nonatomic, weak) id<S1TabBarDelegate> tabbarDelegate;
@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSNumber *expectPresentingButtonCount;
@property (nonatomic, strong) NSNumber *minButtonWidth;

- (void)setSelectedIndex:(NSInteger)index;
- (void)deselectAll;

- (void)updateColor;

@end


@protocol S1TabBarDelegate <NSObject>

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key;

@end
