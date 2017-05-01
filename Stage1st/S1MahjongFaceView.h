//
//  S1MahjongFaceView.h
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1MahjongFaceButton;
@class S1MahjongFaceTextAttachment;
@class MahjongFaceCategory;
@class MahjongFaceItem;
@protocol S1MahjongFaceViewDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface S1MahjongFaceView : UIView

@property (nonatomic, strong) NSArray<MahjongFaceCategory *> *mahjongCategories; // Exposed for swift extension.
@property (nonatomic, strong) NSString *currentCategory;
@property (nonatomic, assign) NSUInteger historyCountLimit;
@property (nonatomic, strong) NSArray<MahjongFaceItem *> *historyArray;
@property (weak, nonatomic, nullable) id<S1MahjongFaceViewDelegate> delegate;

- (void)mahjongFacePressed:(S1MahjongFaceButton *)button;
- (void)backspacePressed:(UIButton *)button;

@end

@protocol S1MahjongFaceViewDelegate <NSObject>

- (void)mahjongFaceViewController:(S1MahjongFaceView *)mahjongFaceView didFinishWithResult:(S1MahjongFaceTextAttachment *)attachment;
- (void)mahjongFaceViewControllerDidPressBackSpace:(S1MahjongFaceView *)mahjongFaceViewController;

@end

NS_ASSUME_NONNULL_END
