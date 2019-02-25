//
//  S1HUD.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/23/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1HUD.h"
#import "UIControl+BlockWrapper.h"
#import <Masonry/Masonry.h>
#import "Stage1st-Swift.h"

typedef enum {
    S1HUDStateShowNothing,
    S1HUDStateShowMessage,
    S1HUDStateShowRefreshButton,
    S1HUDStateShowActivityIndicator
} S1HUDType;

@interface S1HUD ()

@property (nonatomic, assign) S1HUDType type;
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *refreshButton;

@property (nonatomic, strong) MASConstraint *widthConstraint;
@property (nonatomic, strong) MASConstraint *heightConstraint;

@end

@implementation S1HUD

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.alpha = 0.0;
        self.layer.borderColor = [[AppEnvironment.current.colorManager colorForKey:@"hud.border"] CGColor];
        self.layer.borderWidth = 1.0 / [[UIScreen mainScreen] scale];
        self.layer.cornerRadius = 3.0;
        self.backgroundColor = [AppEnvironment.current.colorManager colorForKey:@"hud.background"];
        [self mas_makeConstraints:^(MASConstraintMaker *make) {
            self.widthConstraint = make.width.greaterThanOrEqualTo(@60);
            self.heightConstraint = make.height.greaterThanOrEqualTo(@60);
        }];

        _type = S1HUDStateShowNothing;
        self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        self.indicatorView.alpha = 0.0;
        [self addSubview:self.indicatorView];
        [self.indicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
        }];

        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.messageLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:13.0f];
        self.messageLabel.textColor = [AppEnvironment.current.colorManager colorForKey:@"hud.text"];
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
        self.messageLabel.numberOfLines = 0;
        self.messageLabel.alpha = 0.0;

        [self addSubview:self.messageLabel];
        [self.messageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.leading.greaterThanOrEqualTo(self.mas_leading).offset(8.0);
            make.trailing.lessThanOrEqualTo(self.mas_trailing).offset(-8.0);
            make.top.greaterThanOrEqualTo(self).offset(4.0);
            make.bottom.lessThanOrEqualTo(self).offset(-4.0);
        }];

        self.refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.refreshButton.alpha = 0.0;
        [self.refreshButton addTarget:self action:@selector(refreshAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.refreshButton setImage:[UIImage imageNamed:@"Refresh"] forState:UIControlStateNormal];

        [self addSubview:self.refreshButton];
        [self.refreshButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.width.height.equalTo(@40);
        }];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeZero;
}

- (void)showMessage:(NSString *)message {
    _text = message;
    self.type = S1HUDStateShowMessage;
    [self.widthConstraint deactivate];
    [self.heightConstraint deactivate];
    [self showIfCurrentlyHiding];
    [UIView animateWithDuration:0.2 animations:^{
        self.refreshButton.alpha = 0.0;
        self.indicatorView.alpha = 0.0;
        [self.indicatorView stopAnimating];
        self.messageLabel.alpha = 1.0;
        self.messageLabel.text = message;
        [self layoutIfNeeded];
    }];
}

- (void)showActivityIndicator {
    if (self.type == S1HUDStateShowActivityIndicator) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformMakeScale(1.2, 1.2);
            [self layoutIfNeeded];
        } completion:^(BOOL finished) {
            if (finished) {
                [UIView animateWithDuration:0.1 animations:^{
                    self.transform = CGAffineTransformIdentity;
                }];
            } else {
                self.transform = CGAffineTransformIdentity;
            }
        }];
    } else {
        self.type = S1HUDStateShowActivityIndicator;
        [self showIfCurrentlyHiding];
        [self.widthConstraint activate];
        [self.heightConstraint activate];
        [UIView animateWithDuration:0.2 animations:^{
            self.refreshButton.alpha = 0.0;
            self.indicatorView.alpha = 1.0;
            [self.indicatorView startAnimating];
            self.messageLabel.alpha = 0.0;
            self.messageLabel.text = @"";
            [self layoutIfNeeded];
        }];
    }
}

- (void)showRefreshButton {
    self.type = S1HUDStateShowRefreshButton;
    [self showIfCurrentlyHiding];
    [self.widthConstraint activate];
    [self.heightConstraint activate];
    [UIView animateWithDuration:0.2 animations:^{
        self.refreshButton.alpha = 0.8;
        self.indicatorView.alpha = 0.0;
        [self.indicatorView stopAnimating];
        self.messageLabel.alpha = 0.0;
        self.messageLabel.text = @"";
        [self layoutIfNeeded];
    }];
}

- (void)refreshAction:(id)sender {
    if (self.refreshEventHandler != nil) {
        self.refreshEventHandler(self);
    }
}

- (void)show {
    [self layoutIfNeeded];
    self.alpha = 0.0;
    self.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    }];
}

- (void)showIfCurrentlyHiding {
    if (self.alpha == 0.0) {
        [self show];
    }
}

- (void)hideWithDelay:(NSTimeInterval)delay {
    [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionCurveLinear animations:^{
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeScale(1.2, 1.2);
    } completion:^(BOOL finished) {
        if (finished) {
            self.type = S1HUDStateShowNothing;
        }
    }];
}

@end
