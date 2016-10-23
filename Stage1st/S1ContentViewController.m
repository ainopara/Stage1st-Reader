//
//  S1ContentViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Crashlytics/Answers.h>
#import <ReactiveObjC/ReactiveObjC.h>

#import "S1ContentViewController.h"
#import "S1ContentViewModel.h"
#import "S1Topic.h"
#import "S1Parser.h"
#import "S1DataCenter.h"
#import "S1HUD.h"
#import "REComposeViewController.h"

#import "NavigationControllerDelegate.h"

@interface S1ContentViewController (Stage1stAdd)

@end

@implementation S1ContentViewController (Stage1stAdd)

- (void)viewDidLoadObjC {

    __weak __typeof__(self) weakSelf = self;
    [[RACSignal combineLatest:@[RACObserve(self.viewModel, currentPage), RACObserve(self.viewModel, totalPages)]] subscribeNext:^(RACTuple *x) {
        DDLogVerbose(@"[ContentVM] Current page or totoal page changed: %@/%@", x.first, x.second);
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf.pageButton setTitle:[strongSelf.viewModel pageButtonString] forState:UIControlStateNormal];
    }];

    [[RACSignal combineLatest:@[RACObserve(self, webPageReadyForAutomaticScrolling), RACObserve(self, finishFirstLoading)]] subscribeNext:^(RACTuple *x) {
        DDLogVerbose(@"[ContentVC] document ready: %@, finish first loading: %@", x.first, x.second);
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        if ([x.first boolValue] && [x.second boolValue] && strongSelf.webPageAutomaticScrollingEnabled) {
            // Wait for content size changed
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong __typeof__(self) strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                [strongSelf _hook_didFinishBasicPageLoadFor:strongSelf.webView];
            });
            strongSelf.webPageAutomaticScrollingEnabled = NO;
        }
    }];

    [[self.favoriteButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf.viewModel toggleFavorite];
    }];

    [RACObserve(self.viewModel.topic, favorite) subscribeNext:^(id x) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf.favoriteButton setImage:[strongSelf.viewModel favoriteButtonImage] forState:UIControlStateNormal];
    }];
}

@end
