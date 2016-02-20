//
//  S1MahjongFaceView.h
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "S1MahjongFaceTextAttachment.h"
@class S1MahjongFaceButton;
@protocol S1MahjongFaceViewDelegate;

@interface S1MahjongFaceView : UIView

@property (nonatomic, strong) NSString * _Nonnull currentCategory;
@property (nonatomic, assign) NSUInteger historyCountLimit;
@property (nonatomic, strong) NSMutableArray * _Nonnull historyArray;
@property (weak, nonatomic) id<S1MahjongFaceViewDelegate> delegate;

- (void)mahjongFacePressed:(nonnull S1MahjongFaceButton *)button;
- (void)backspacePressed:(nonnull UIButton *)button;

@end

@protocol S1MahjongFaceViewDelegate <NSObject>

- (void)mahjongFaceViewController:(nonnull S1MahjongFaceView *)mahjongFaceView didFinishWithResult:(nonnull S1MahjongFaceTextAttachment *)attachment;
- (void)mahjongFaceViewControllerDidPressBackSpace:(nonnull S1MahjongFaceView *)mahjongFaceViewController;

@end