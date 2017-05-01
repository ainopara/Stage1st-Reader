//
//  S1MahjongFacePageView.h
//  Stage1st
//
//  Created by Zheng Li on 5/30/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1MahjongFaceView;
@class S1MahjongFaceButton;
@class MahjongFaceItem;

@interface S1MahjongFacePageView : UIView

@property (nonatomic, strong) NSMutableArray<S1MahjongFaceButton *> *buttons;
@property (nonatomic, strong) S1MahjongFaceButton *backspaceButton;
@property (nonatomic, weak) S1MahjongFaceView *containerView;
@property (nonatomic, assign) NSUInteger index;

- (void)setMahjongFaceList:(NSArray<MahjongFaceItem *> *)list withRows:(NSInteger)rows andColumns:(NSInteger)columns;

@end
