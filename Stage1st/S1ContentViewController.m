//
//  S1ContentViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <ActionSheetPicker_3_0/ActionSheetStringPicker.h>
#import <Crashlytics/Answers.h>
#import <ReactiveObjC/ReactiveObjC.h>

#import "S1ContentViewController.h"
#import "S1ContentViewModel.h"
#import "S1Topic.h"
#import "S1Parser.h"
#import "S1DataCenter.h"
#import "S1HUD.h"
#import "REComposeViewController.h"
#import "MTStatusBarOverlay.h"

#import "JTSSimpleImageDownloader.h"
#import "JTSImageViewController.h"
#import "S1MahjongFaceView.h"
#import "Masonry.h"
#import "NavigationControllerDelegate.h"


CGFloat const topOffset = -80.0;
CGFloat const bottomOffset = 60.0;

//@interface UIScrollView (S1Inspect)
//@end
//
//@implementation UIScrollView (S1Inspect)
//
//+ (void)load {
//    Method origin = class_getInstanceMethod([self class], @selector(setContentOffset:));
//    Method newMethod = class_getInstanceMethod([self class], @selector(s1_setContentOffset:));
//    method_exchangeImplementations(origin, newMethod);
//}
//
//- (void)s1_setContentOffset:(CGPoint)contentOffset {
//    if ([self isKindOfClass:NSClassFromString(@"_UIWebViewScrollView")]) {
//        NSLog(@"%@ old: %f, %f", self, self.contentOffset.x, self.contentOffset.y);
//        NSLog(@"new: %f, %f",contentOffset.x, contentOffset.y);
//    }
//    [self s1_setContentOffset:contentOffset];
//}
//
//@end

@interface S1ContentViewController (Stage1stAdd) <
JTSImageViewControllerInteractionsDelegate,
JTSImageViewControllerOptionsDelegate
>

@end

@implementation S1ContentViewController (Stage1stAdd)

#pragma mark - Life Cycle

- (void)viewDidLoadObjC {

    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithCustomView:self.forwardButton];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:self.backButton];

    // Favorite Button
    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.favoriteButton.frame = CGRectMake(0, 0, 40, 30);
    self.favoriteButton.imageView.clipsToBounds = NO;
    self.favoriteButton.imageView.contentMode = UIViewContentModeCenter;

    UIBarButtonItem *favoriteItem = [[UIBarButtonItem alloc] initWithCustomView:self.favoriteButton];

    [self updateToolBar];
    
    UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithCustomView:self.pageButton];
    labelItem.width = 80.0;
    
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 26.0;
    UIBarButtonItem *fixItem2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem2.width = 48.0;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    // Hide Favorite button when device do not have enough space for it.
    if (![self shouldPresentingFavoriteButtonOnToolBar]) {
        favoriteItem.customView.bounds = CGRectZero;
        favoriteItem.customView.hidden = YES;
        fixItem2.width = 0.0;
    }
    
    [self.toolBar setItems:@[backItem, fixItem, forwardItem, flexItem, labelItem, flexItem, favoriteItem, fixItem2, self.actionBarButtonItem]];


   
    __weak __typeof__(self) weakSelf = self;
    [[RACSignal combineLatest:@[RACObserve(self.viewModel, currentPage), RACObserve(self.viewModel, totalPages)]] subscribeNext:^(RACTuple *x) {
        DDLogVerbose(@"[ContentVM] Current page or totoal page changed: %@/%@", x.first, x.second);
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        [strongSelf.pageButton setTitle:[strongSelf.viewModel pageButtonString] forState:UIControlStateNormal];
    }];

    [[RACSignal combineLatest:@[RACObserve(self, webPageReadyForAutomaticScrolling), RACObserve(self, webPageSizeChangedForAutomaticScrolling)]] subscribeNext:^(RACTuple *x) {
        DDLogVerbose(@"[ContentVC] document ready: %@, content size changed: %@", x.first, x.second);
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        if ([x.first boolValue] && [x.second boolValue] && strongSelf.webPageAutomaticScrollingEnabled) {
            [strongSelf didFinishBasicPageLoadForWebView:strongSelf.webView];
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

    [self _setupActivity];

    [self.view layoutIfNeeded];

    DDLogDebug(@"[ContentVC] View Did Load 9");
    [self fetchContentForCurrentPageWithForceUpdate:self.viewModel.currentPage == self.viewModel.totalPages];
}

#pragma mark - Actions

- (void)pickPage:(id)sender {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (long i = 0; i < (self.viewModel.currentPage > self.viewModel.totalPages ? self.viewModel.currentPage : self.viewModel.totalPages); i++) {
        if ([self.dataCenter hasPrecacheFloorsForTopic:self.viewModel.topic withPage:[NSNumber numberWithLong:i + 1]]) {
            [array addObject:[NSString stringWithFormat:@"✓第 %ld 页✓", i + 1]];
        } else {
            [array addObject:[NSString stringWithFormat:@"第 %ld 页", i + 1]];
        }
    }
    ActionSheetStringPicker *picker = [[ActionSheetStringPicker alloc] initWithTitle:@"" rows:array initialSelection:self.viewModel.currentPage - 1 doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {

        if (self.viewModel.currentPage != selectedIndex + 1) {
            [self preChangeCurrentPage];
            self.viewModel.currentPage = selectedIndex + 1;
            [self fetchContentForCurrentPageWithForceUpdate:NO];
        } else {
            [self forceRefreshCurrentPage];
        }

    } cancelBlock:nil origin:self.pageButton];
    picker.pickerBackgroundColor = [[APColorManager shared] colorForKey:@"content.picker.background"];
    picker.toolbarBackgroundColor = [[APColorManager shared] colorForKey:@"appearance.toolbar.bartint"];
    picker.toolbarButtonsColor = [[APColorManager shared] colorForKey:@"appearance.toolbar.tint"];
    
    NSMutableParagraphStyle *labelParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    labelParagraphStyle.alignment = NSTextAlignmentCenter;
    picker.pickerTextAttributes = [@{
        NSParagraphStyleAttributeName: labelParagraphStyle,
        NSFontAttributeName: [UIFont systemFontOfSize:19.0],
        NSForegroundColorAttributeName: [[APColorManager shared] colorForKey:@"content.picker.text"]
    } mutableCopy];
    [picker showActionSheetPicker];
}

- (void)action:(id)sender {
    UIAlertController *moreActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    // Reply Action
    UIAlertAction *replyAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Reply", @"Reply") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self presentReplyViewToFloor:nil];
    }];

    // Favorite Action
    UIAlertAction *favoriteAction = [UIAlertAction actionWithTitle:[self.viewModel.topic.favorite boolValue] ? NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self.viewModel toggleFavorite];
        [self.hintHUD showMessage:[self.viewModel.topic.favorite boolValue] ? NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") : NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite")];
        [self.hintHUD hideWithDelay:0.5];
    }];

    // Share Action
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Share", @"Share") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIImage *screenShot = [self.view s1_screenShot];
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.viewModel.topic.title], [NSURL URLWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.viewModel.topic.topicID, (long)self.viewModel.currentPage]], screenShot] applicationActivities:nil];
        [activityController.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
        [self presentViewController:activityController animated:YES completion:nil];
        [activityController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            DDLogDebug(@"[Activity] finish with activity type: %@",activityType);
        }];
    }];

    // Copy Link
    UIAlertAction *copyLinkAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [[self.viewModel correspondingWebPageURL] absoluteString];
        [self.refreshHUD showMessage:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link")];
        [self.refreshHUD hideWithDelay:0.3];
    }];

    // Origin Page Action
    UIAlertAction *originPageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_OriginPage", @"Origin") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.presentingWebViewer = YES;
        [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
        NSURL *URLToOpen = [self.viewModel correspondingWebPageURL];
        if (URLToOpen != nil) {
            WebViewController *controller = [[WebViewController alloc] initWithURL:URLToOpen];
            [self presentViewController:controller animated:YES completion:nil];
        }
    }];

    // Cancel Action
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];

    [moreActionSheet addAction:replyAction];
    if (![self shouldPresentingFavoriteButtonOnToolBar]) {
        [moreActionSheet addAction:favoriteAction];
    }

    [moreActionSheet addAction:shareAction];
    [moreActionSheet addAction:copyLinkAction];
    [moreActionSheet addAction:originPageAction];
    [moreActionSheet addAction:cancelAction];
    [moreActionSheet.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
    [self presentViewController:moreActionSheet animated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURLRequest *request = navigationAction.request;
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    if ([request.URL.absoluteString hasPrefix:@"file://"]) {
        if ([request.URL.absoluteString hasSuffix:@"html"]) {
            decisionHandler(WKNavigationActionPolicyAllow);
            return;
        }

        if ([request.URL.path isEqualToString:@"/ready"]) {
            DDLogDebug(@"[WebView] ready");
            self.webPageReadyForAutomaticScrolling = YES;
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }

        // Reply
        if ([request.URL.path isEqualToString:@"/reply"]) {
            NSString *floorID = [request.URL.query stringByRemovingPercentEncoding];
            [self actionButtonTappedFor:floorID];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }

        // Present User
        if ([request.URL.path isEqualToString:@"/user"]) {
            [Answers logCustomEventWithName:@"[Content] User" customAttributes:nil];
            NSNumber *userID = [NSNumber numberWithInteger:[request.URL.query integerValue]];
            [self showUserViewController:userID];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }

        // Present image
        if ([request.URL.path hasPrefix:@"/present-image:"]) {
            self.presentingImageViewer = YES;
            [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
            [Answers logCustomEventWithName:@"[Content] Image" customAttributes:@{@"type": @"processed"}];

            NSString *imageID = request.URL.fragment;
            NSString *imageURL = [request.URL.path stringByReplacingCharactersInRange:NSRangeFromString(@"0 15") withString:@""];
            DDLogDebug(@"[ContentVC] JTS View Image: %@", imageURL);
            JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
            imageInfo.imageURL = [[NSURL alloc] initWithString:imageURL];
            imageInfo.referenceRect = [[self class] positionOfElementWith:imageID in:self.webView];
            imageInfo.referenceView = self.webView;

            JTSImageViewController *imageViewer = [[JTSImageViewController alloc] initWithImageInfo:imageInfo mode:JTSImageViewControllerMode_Image backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
            [imageViewer setInteractionsDelegate:self];
            [imageViewer setOptionsDelegate:self];
            [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }

    //Image URL opened in image Viewer
    if ([request.URL.path hasSuffix:@".jpg"] || [request.URL.path hasSuffix:@".gif"]) {
        self.presentingImageViewer = YES;
        [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
        [Answers logCustomEventWithName:@"[Content] Image" customAttributes:@{@"type": @"hijack"}];

        NSString *imageURL = request.URL.absoluteString;
        DDLogDebug(@"[ContentVC] JTS View Image: %@", imageURL);
        JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
        imageInfo.imageURL = request.URL;

        JTSImageViewController *imageViewer = [[JTSImageViewController alloc] initWithImageInfo:imageInfo mode:JTSImageViewControllerMode_Image backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
        [imageViewer setInteractionsDelegate:self];
        [imageViewer setOptionsDelegate:self];
        [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOffscreen];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }


    if ([request.URL.absoluteString hasPrefix:[[NSUserDefaults standardUserDefaults] stringForKey:@"BaseURL"]]) {

        // Open S1 topic
        S1Topic *topic = [S1Parser extractTopicInfoFromLink:request.URL.absoluteString];
        if (topic.topicID != nil) {
            S1Topic *tracedTopic = [self.dataCenter tracedTopic:topic.topicID];
            if (tracedTopic != nil) {
                NSNumber *lastViewedPage = topic.lastViewedPage;
                topic = [tracedTopic copy];
                topic.lastViewedPage = lastViewedPage;
            }
            self.presentingContentViewController = YES;
            S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:self.dataCenter];
            [[self navigationController] pushViewController:contentViewController animated:YES];
            [Answers logCustomEventWithName:@"[Content] Topic Link" customAttributes:nil];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }

        // Open Quote Link
        NSDictionary *querys = [S1Parser extractQuerysFromURLString:request.URL.absoluteString];
        if (querys) {
            DDLogDebug(@"[ContentVC] Extract query: %@",querys);
            if ([[querys valueForKey:@"mod"] isEqualToString:@"redirect"]) {
                if ([[querys valueForKey:@"ptid"] integerValue] == [self.viewModel.topic.topicID integerValue]) {
                    NSInteger tid = [[querys valueForKey:@"ptid"] integerValue];
                    NSInteger pid = [[querys valueForKey:@"pid"] integerValue];
                    if (tid == [self.viewModel.topic.topicID integerValue]) {
                        NSArray *chainQuoteFloors = [self.viewModel chainSearchQuoteFloorInCache:pid];
                        if ([chainQuoteFloors count] > 0) {
                            self.presentingContentViewController = YES;
                            S1Topic *quoteTopic = [self.viewModel.topic copy];
                            NSString *htmlString = [S1ContentViewModel generateContentPage:chainQuoteFloors withTopic:quoteTopic];
                            [self showQuoteFloorViewControllerWithTopic:quoteTopic floors:chainQuoteFloors htmlString: htmlString centerFloorID: [[chainQuoteFloors lastObject] ID]];
                            [Answers logCustomEventWithName:@"[Content] Quote Link" customAttributes:nil];
                            decisionHandler(WKNavigationActionPolicyCancel);
                            return;
                        }
                    }
                }
            }
        }
    }

    // Open link

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") style:UIAlertActionStyleDefault handler:nil];

    __weak __typeof__(self) weakSelf = self;
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        __strong __typeof__(self) strongSelf = weakSelf;
        strongSelf.presentingWebViewer = YES;
        [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
        if (SYSTEM_VERSION_LESS_THAN(@"9")) {
            DDLogDebug(@"[ContentVC] Open in WebView: %@", request.URL);
            WebViewController *webViewController = [[WebViewController alloc] initWithURL:request.URL];
            [strongSelf presentViewController:webViewController animated:YES completion:nil];
        } else {
            DDLogDebug(@"[ContentVC] Open in Safari: %@", request.URL);
            if (![[UIApplication sharedApplication] openURL:request.URL]) {
                DDLogWarn(@"Failed to open url: %@", request.URL);
            }
        }
    }];

    [alert addAction:cancelAction];
    [alert addAction:continueAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    decisionHandler(WKNavigationActionPolicyCancel);
    return;
}

#pragma mark JTSImageViewControllerInteractionsDelegate

- (void)imageViewerDidLongPress:(JTSImageViewController *)imageViewer atRect:(CGRect)rect {
    UIAlertController *imageActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ImageViewer_ActionSheet_Save", @"Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImageWriteToSavedPhotosAlbum(imageViewer.image, nil, nil, nil);
        });
    }];
    UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ImageViewer_ActionSheet_CopyURL", @"Copy URL") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = imageViewer.imageInfo.imageURL.absoluteString;
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
    [imageActionSheet addAction:saveAction];
    [imageActionSheet addAction:copyURLAction];
    [imageActionSheet addAction:cancelAction];
    [imageActionSheet.popoverPresentationController setSourceView:imageViewer.view];
    [imageActionSheet.popoverPresentationController setSourceRect:rect];
    [imageViewer presentViewController:imageActionSheet animated:YES completion:nil];
}

#pragma mark JTSImageViewControllerOptionsDelegate

- (CGFloat)alphaForBackgroundDimmingOverlayInImageViewer:(JTSImageViewController *)imageViewer {
    return 0.3;
}

#pragma mark - Networking

- (void)fetchContentForCurrentPageWithForceUpdate:(BOOL)forceUpdate {
    [self updateToolBar];

    self.userActivity.needsSave = YES;
   
    //remove cache for last page
    if (forceUpdate) {
        [self.dataCenter removePrecachedFloorsForTopic:self.viewModel.topic withPage:[NSNumber numberWithUnsignedInteger:self.viewModel.currentPage]];
    }
    //Set up HUD
    DDLogVerbose(@"[ContentVC] check precache exist");

    if (![self.dataCenter hasPrecacheFloorsForTopic:self.viewModel.topic withPage:[NSNumber numberWithUnsignedInteger:self.viewModel.currentPage]]) {
        DDLogVerbose(@"[ContentVC] Show HUD");
        [self.refreshHUD showActivityIndicator];

        __weak __typeof__(self) weakSelf = self;
        [self.refreshHUD setRefreshEventHandler:^(S1HUD *aHUD) {
            __strong __typeof__(self) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }

            [aHUD hideWithDelay:0.0];
            [strongSelf fetchContentForCurrentPageWithForceUpdate:NO];
        }];
    }

    __weak __typeof__(self) weakSelf = self;
    [self.viewModel contentPageWithSuccess:^(NSString *contents, bool shouldRefetch) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        [strongSelf updateToolBar];
        [strongSelf updateTitleLabelWithTitle:strongSelf.viewModel.topic.title];

        [strongSelf saveViewPositionForPreviousPage];

        strongSelf.finishFirstLoading = YES;

        [strongSelf.webView loadHTMLString:contents baseURL:[S1ContentViewModel pageBaseURL]];

        // Prepare next page
        if (strongSelf.viewModel.currentPage < strongSelf.viewModel.totalPages) {
            NSNumber *cachePage = [NSNumber numberWithUnsignedInteger:strongSelf.viewModel.currentPage + 1];
            [strongSelf.dataCenter setFinishHandlerForTopic:strongSelf.viewModel.topic withPage:cachePage andHandler:^(NSArray *floorList) {
                __strong __typeof__(self) strongSelf = weakSelf;
                [strongSelf updateToolBar];
            }];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PrecacheNextPage"]) {
                [strongSelf.dataCenter precacheFloorsForTopic:strongSelf.viewModel.topic withPage:cachePage shouldUpdate:NO];
            }
        }
        // Dismiss HUD if exist
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf hideHUDIfNoMessageToShow];
        });

        // Auto refresh when current page not full.
        if (shouldRefetch) {
            strongSelf.scrollType = S1ContentScrollTypeRestorePosition;
            [strongSelf fetchContentForCurrentPageWithForceUpdate:YES];
        }
        
    } failure:^(NSError *error) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if (error.code == NSURLErrorCancelled) {
            DDLogDebug(@"request cancelled.");
            // TODO:
//            if (strongSelf.refreshHUD != nil) {
//                [strongSelf.refreshHUD hideWithDelay:0.3];
//            }
        } else {
            DDLogDebug(@"%@", error);
            if (strongSelf.refreshHUD != nil) {
                [strongSelf.refreshHUD showRefreshButton];
            }
        }
    }];
}

#pragma mark - Layout

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    DDLogDebug(@"viewWillTransitionToSize: w%f,h%f ",size.width, size.height);
    CGRect frame = self.view.frame;
    frame.size = size;
    self.view.frame = frame;
    
    // Update Toolbar Layout
    NSArray *items = self.toolBar.items;
    UIBarButtonItem *favoriteItem = items[6];
    UIBarButtonItem *fixItem2 = items[7];
    if ([self shouldPresentingFavoriteButtonOnToolBar]) {
        favoriteItem.customView.bounds = CGRectMake(0, 0, 30, 40);
        favoriteItem.customView.hidden = NO;
        fixItem2.width = 48.0;
    } else {
        favoriteItem.customView.bounds = CGRectZero;
        favoriteItem.customView.hidden = YES;
        fixItem2.width = 0.0;
    }
    self.toolBar.items = items;
}

#pragma mark - Notificatons

- (void)saveTopicViewedState:(id)sender {
    DDLogDebug(@"[ContentVC] Save Topic View State Begin.");
    if (self.finishFirstLoading) {
        self.viewModel.topic.lastViewedPosition = [NSNumber numberWithFloat:(float)self.webView.scrollView.contentOffset.y];
    } else if (self.viewModel.topic.lastViewedPosition == nil || [self.viewModel.topic.lastViewedPage unsignedIntegerValue] != self.viewModel.currentPage) {
        // If last viewed page in record doesn't equal current page it means user has changed page since this view controller is loaded.
        // Then the unfinish loaded new page's last view position should be 0.
        self.viewModel.topic.lastViewedPosition = [NSNumber numberWithFloat:(float)0.0];
    }
    self.viewModel.topic.lastViewedPage = [NSNumber numberWithInteger:self.viewModel.currentPage];
    self.viewModel.topic.lastViewedDate = [NSDate date];
    self.viewModel.topic.lastReplyCount = self.viewModel.topic.replyCount;
    [self.dataCenter hasViewed:self.viewModel.topic];
    DDLogInfo(@"[ContentVC] Save Topic View State Finish.");
}

#pragma mark - Restore Position

- (void)preChangeCurrentPage {
    DDLogDebug(@"[webView] pre change current page");
    [self cancelRequest];
    [self saveViewPositionForCurrentPage];
    self.webPageReadyForAutomaticScrolling = NO;
    self.webPageSizeChangedForAutomaticScrolling = NO;
    self.webPageAutomaticScrollingEnabled = YES;
}

- (void)didFinishBasicPageLoadForWebView:(WKWebView *)webView {
    DDLogDebug(@"[webView] basic page loaded");
    CGFloat maxOffset = webView.scrollView.contentSize.height - CGRectGetHeight(webView.scrollView.bounds);

    switch (self.scrollType) {
        case S1ContentScrollTypePullUpForNext: {
            // Set position
            [webView.scrollView setContentOffset:CGPointMake(0.0, -CGRectGetHeight(webView.bounds)) animated:NO];
            // Animated scroll
            [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                [webView.scrollView setContentOffset:CGPointMake(0.0, 0.0) animated:NO];
                webView.scrollView.alpha = 1.0;
            } completion:NULL];
            break;
        }
        case S1ContentScrollTypePullDownForPrevious: {
            // Set position
            [webView.scrollView setContentOffset:CGPointMake(0.0, webView.scrollView.contentSize.height) animated:NO];
            // Animated scroll
            [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                [webView.scrollView setContentOffset:CGPointMake(0.0, maxOffset) animated:NO];
                webView.scrollView.alpha = 1.0;
            } completion:NULL];
            break;
        }
        case S1ContentScrollTypeToBottom:
            [webView.scrollView setContentOffset:CGPointMake(0, maxOffset) animated:YES];
            break;
        default:
            break;
    }
}
    
- (void)didFinishFullPageLoadForWebView:(WKWebView *)webView {
    DDLogDebug(@"[webView] full page loaded");
    CGFloat maxOffset = webView.scrollView.contentSize.height - CGRectGetHeight(webView.scrollView.bounds);

    switch (self.scrollType) {
        case S1ContentScrollTypeToBottom:
        case S1ContentScrollTypePullDownForPrevious:
            [webView.scrollView setContentOffset:CGPointMake(0, maxOffset) animated:NO];
            break;
        case S1ContentScrollTypePullUpForNext:
            [webView.scrollView setContentOffset:CGPointMake(0.0, 0.0) animated:NO];
            break;
        default: {
            NSNumber *positionForPage = [self.viewModel cachedOffsetForCurrentPage];
            if (positionForPage != nil) {
                // Restore last view position from cached position in this view controller.
                [webView.scrollView setContentOffset:CGPointMake(webView.scrollView.contentOffset.x, fmax(fmin(maxOffset, [positionForPage doubleValue]), 0.0)) animated:NO];
            }
            break;
        }
    }

    self.scrollType = S1ContentScrollTypeRestorePosition;
}

@end
