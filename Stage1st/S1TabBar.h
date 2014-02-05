//
//  S1TabBar.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/2/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol S1TabBarDelegate;

@interface S1TabBar : UIScrollView <UIScrollViewDelegate>

- (id)initWithFrame:(CGRect)frame andKeys:(NSArray *)keys;
- (void)deselectAll;
- (void)updateButtonFrame;

@property (nonatomic, weak) id<S1TabBarDelegate> tabbarDelegate;

@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, assign) BOOL enabled;



@end

@protocol S1TabBarDelegate <NSObject>

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key;

@end
