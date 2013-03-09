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

@property (nonatomic, assign) id<S1TabBarDelegate> tabbarDelegate;

//@property (nonatomic, copy) void (^eventHandler)(NSString *key);

@property (nonatomic, strong) NSArray *keys;


@end

@protocol S1TabBarDelegate <NSObject>

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key;

@end
