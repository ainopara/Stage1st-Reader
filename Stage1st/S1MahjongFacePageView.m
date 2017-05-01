//
//  S1MahjongFacePageView.m
//  Stage1st
//
//  Created by Zheng Li on 5/30/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1MahjongFacePageView.h"
#import "UIButton+AFNetworking.h"
#import "S1MahjongFaceView.h"
#import <JTSImageViewController/JTSAnimatedGIFUtility.h>

@implementation S1MahjongFacePageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _buttons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setMahjongFaceList:(NSArray<MahjongFaceItem *> *)list withRows:(NSInteger)rows andColumns:(NSInteger)columns {
    NSInteger rowIndex = 0;
    NSInteger columnIndex = 0;
    NSInteger buttonIndex = 0;
    CGFloat heightOffset = (self.frame.size.height - rows * 50.0) / 2;

    for(S1MahjongFaceButton *button in self.buttons) {
        buttonIndex = rowIndex * columns + columnIndex;
        if (buttonIndex < [list count] && buttonIndex < rows * columns) {
            MahjongFaceItem *item = [list objectAtIndex:buttonIndex];
            if ([button.mahjongFaceItem.key isEqualToString:item.key]) {
                DDLogVerbose(@"face button hit, skip.");
            } else {
                button.mahjongFaceItem = item;
                [self setImageURL:item.url forButton:button];
            }

            [button setFrame:CGRectMake(columnIndex * 50 + 10,rowIndex * 50 + heightOffset, 50, 50)];
            button.hidden = NO;
        } else {
            button.hidden = YES;
        }
        columnIndex += 1;
        if (columnIndex == columns) {
            rowIndex += 1;
            columnIndex = 0;
        }
    }

    buttonIndex = rowIndex * columns + columnIndex;

    while (buttonIndex < [list count] && buttonIndex < rows * columns) {
        MahjongFaceItem *item = [list objectAtIndex:buttonIndex];
        S1MahjongFaceButton *button = [self mahjongFaceButtonForItem:item];
        [button setFrame:CGRectMake(columnIndex * 50 + 10,rowIndex * 50 + heightOffset, 50, 50)];
        columnIndex += 1;
        if (columnIndex == columns) {
            rowIndex += 1;
            columnIndex = 0;
        }
        buttonIndex = rowIndex * columns + columnIndex;
    }

    if (self.backspaceButton == nil) {
        self.backspaceButton = [[S1MahjongFaceButton alloc] init];
        [self.backspaceButton setImage:[[UIImage imageNamed:@"Backspace"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        self.backspaceButton.adjustsImageWhenHighlighted = NO;
        [self.backspaceButton setTintColor:[[ColorManager shared] colorForKey:@"mahjongface.backspace.tint"]];
        [self.backspaceButton addTarget:self action:@selector(backspacePressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.backspaceButton];
    }

    [self.backspaceButton setFrame:CGRectMake((columns - 1) * 50 + 10,(rows - 1) * 50 + heightOffset, 50, 50)];
}

- (S1MahjongFaceButton *)mahjongFaceButtonForItem:(MahjongFaceItem *)item {
    S1MahjongFaceButton *button = [[S1MahjongFaceButton alloc] init];
    button.contentMode = UIViewContentModeCenter;
    [button addTarget:self action:@selector(mahjongFacePressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:button];
    [self.buttons addObject:button];
    button.adjustsImageWhenHighlighted = NO;
    button.mahjongFaceItem = item;
    [self setImageURL:item.url forButton:button];
    
    return button;
}

- (void)setImageURL:(NSURL *)URL forButton:(S1MahjongFaceButton *)button {
    [button setImage:[UIImage imageNamed:@"MahjongFacePlaceholder"] forState:UIControlStateNormal];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [JTSAnimatedGIFUtility animatedImageWithAnimatedGIFURL:URL];
        dispatch_async(dispatch_get_main_queue(), ^{
            [button setImage:image forState:UIControlStateNormal];
        });
    });
}

- (void)mahjongFacePressed:(S1MahjongFaceButton *)button {
    if (self.containerView) {
        [self.containerView mahjongFacePressed:button];
    }
}

- (void)backspacePressed:(UIButton *)button {
    if (self.containerView) {
        [self.containerView backspacePressed:button];
    }
}

@end
