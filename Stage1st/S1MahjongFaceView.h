//
//  S1MahjongFaceView.h
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class S1MahjongFaceButton;
@class S1MahjongFaceTextAttachment;
@protocol S1MahjongFaceViewDelegate;

@interface S1MahjongFaceView : UIView

@property (nonatomic, strong) NSString * currentCategory;
@property (nonatomic, assign) NSUInteger historyCountLimit;
@property (nonatomic, strong) NSMutableArray * historyArray;
@property (weak, nonatomic, nullable) id<S1MahjongFaceViewDelegate> delegate;

- (void)mahjongFacePressed:(S1MahjongFaceButton *)button;
- (void)backspacePressed:(UIButton *)button;

@end

@protocol S1MahjongFaceViewDelegate <NSObject>

- (void)mahjongFaceViewController:(S1MahjongFaceView *)mahjongFaceView didFinishWithResult:(S1MahjongFaceTextAttachment *)attachment;
- (void)mahjongFaceViewControllerDidPressBackSpace:(S1MahjongFaceView *)mahjongFaceViewController;

@end

NS_ASSUME_NONNULL_END
