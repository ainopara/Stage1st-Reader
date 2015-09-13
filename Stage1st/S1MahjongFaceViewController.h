//
//  S1MahjongFaceViewController.h
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "S1MahjongFaceTextAttachment.h"
@class S1MahjongFaceButton;
@protocol S1MahjongFaceViewControllerDelegate;

@interface S1MahjongFaceViewController : UIViewController
@property (nonatomic, strong) NSString *currentCategory;
@property (nonatomic, assign) NSUInteger historyCountLimit;
@property (weak, nonatomic) id<S1MahjongFaceViewControllerDelegate> delegate;

- (void)mahjongFacePressed:(S1MahjongFaceButton *)button;
- (void)backspacePressed:(UIButton *)button;
@end

@protocol S1MahjongFaceViewControllerDelegate <NSObject>
- (void)mahjongFaceViewController:(S1MahjongFaceViewController *)mahjongFaceViewController didFinishWithResult:(S1MahjongFaceTextAttachment *)attachment;
- (void)mahjongFaceViewControllerDidPressBackSpace:(S1MahjongFaceViewController *)mahjongFaceViewController;
- (NSMutableArray *)restoreHistoryArray;
- (void)saveHistoryArray:(NSMutableArray *)historyArray;
@end