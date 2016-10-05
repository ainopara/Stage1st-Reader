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
            [strongSelf _hook_didFinishBasicPageLoadFor:strongSelf.webView];
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

#pragma mark - Actions

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
            S1Topic *tracedTopic = [self.viewModel.dataCenter tracedTopic:topic.topicID];
            if (tracedTopic != nil) {
                NSNumber *lastViewedPage = topic.lastViewedPage;
                topic = [tracedTopic copy];
                topic.lastViewedPage = lastViewedPage;
            }
            self.presentingContentViewController = YES;
            S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:self.viewModel.dataCenter];
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

@end
