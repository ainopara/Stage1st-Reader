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

- (void)deselectAll;

@property (nonatomic, weak) id<S1TabBarDelegate> tabbarDelegate;

@property (nonatomic, strong) NSArray *keys;
@property (nonatomic, assign) BOOL enabled;

-(void)setSelectedIndex:(NSInteger)index;

@end


@protocol S1TabBarDelegate <NSObject>

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key;

@end
