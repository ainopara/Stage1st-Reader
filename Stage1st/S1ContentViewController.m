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

//NS_ASSUME_NONNULL_BEGIN
//
//@interface S1ContentViewController () <
//WKNavigationDelegate,
//JTSImageViewControllerInteractionsDelegate,
//JTSImageViewControllerOptionsDelegate,
//REComposeViewControllerDelegate
//>
//
//@end
//
//@implementation S1ContentViewController ()
//
//#pragma mark - Life Cycle
//
//- (void)viewDidLoad {
//    [super viewDidLoad];
//
//    self.view.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.background"];
//
//    self.toolBar = [[UIToolbar alloc] initWithFrame:CGRectZero];
//    self.toolBar.translucent = NO;
//    [self.view addSubview:self.toolBar];
//    [self.toolBar mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.leading.and.trailing.equalTo(self.view);
//        make.bottom.equalTo(self.mas_bottomLayoutGuideTop);
//    }];
//    DDLogDebug(@"[ContentVC] View Did Load2");
//    // web view
//    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[[WKWebViewConfiguration alloc] init]];
//    self.webView.navigationDelegate = self;
//    self.webView.scrollView.backgroundColor = [UIColor clearColor];
//    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
//    [self.webView.scrollView.panGestureRecognizer requireGestureRecognizerToFail:[(NavigationControllerDelegate *)self.navigationController.delegate colorPanRecognizer]];
//    self.webView.opaque = NO;
//    self.webView.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];
//    [self.view addSubview:self.webView];
//
//    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.leading.and.trailing.equalTo(self.view);
//        make.top.equalTo(self.mas_topLayoutGuideBottom);
//        make.bottom.equalTo(self.toolBar.mas_top);
//    }];
//
//    self.pullToActionController = [[PullToActionController alloc] initWithScrollView:self.webView.scrollView];
//    [self.pullToActionController addConfigurationWith:@"top" baseLine:OffsetBaseLineTop beginPosition:0.0 endPosition:topOffset];
//    [self.pullToActionController addConfigurationWith:@"bottom" baseLine:OffsetBaseLineBottom beginPosition:0.0 endPosition:bottomOffset];
//    self.pullToActionController.delegate = self;
//    
//    self.topDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, topOffset, self.view.bounds.size.width, 1)];
//    self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
//    [self.webView.scrollView addSubview:self.topDecorateLine];
//
//    self.bottomDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, bottomOffset, self.view.bounds.size.width, 1)]; // will be updated soon in delegate.
//    self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
//    [self.webView.scrollView addSubview:self.bottomDecorateLine];
//
//    //title label
//    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
//    self.titleLabel.numberOfLines = 0;
//    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
//    self.titleLabel.textAlignment = NSTextAlignmentCenter;
//
//    if (self.viewModel.topic.title == nil || [self.viewModel.topic.title isEqualToString:@""]) {
//        self.titleLabel.text = [NSString stringWithFormat: @"%@ 载入中...", self.viewModel.topic.topicID];
//        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.disable"];
//    } else {
//        self.titleLabel.text = self.viewModel.topic.title;
//        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
//    }
//
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        self.titleLabel.textAlignment = NSTextAlignmentCenter;
//    }
//    [self.webView.scrollView insertSubview:self.titleLabel atIndex:0];
//    
//    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.bottom.equalTo(self.webView.scrollView.subviews[1].mas_top);
//        make.centerX.equalTo(self.webView.mas_centerX);
//        make.width.equalTo(self.webView.mas_width).with.offset(-24);
//    }];
//
//    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithCustomView:self.forwardButton];
//    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:self.backButton];
//
//    // Favorite Button
//    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeSystem];
//    self.favoriteButton.frame = CGRectMake(0, 0, 40, 30);
//    self.favoriteButton.imageView.clipsToBounds = NO;
//    self.favoriteButton.imageView.contentMode = UIViewContentModeCenter;
//
//    UIBarButtonItem *favoriteItem = [[UIBarButtonItem alloc] initWithCustomView:self.favoriteButton];
//
//    [self updateToolBar];
//    
//    UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithCustomView:self.pageButton];
//    labelItem.width = 80.0;
//    
//    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
//    fixItem.width = 26.0;
//    UIBarButtonItem *fixItem2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
//    fixItem2.width = 48.0;
//    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
//
//    // Hide Favorite button when device do not have enough space for it.
//    if (![self shouldPresentingFavoriteButtonOnToolBar]) {
//        favoriteItem.customView.bounds = CGRectZero;
//        favoriteItem.customView.hidden = YES;
//        fixItem2.width = 0.0;
//    }
//    
//    [self.toolBar setItems:@[backItem, fixItem, forwardItem, flexItem, labelItem, flexItem, favoriteItem, fixItem2, self.actionBarButtonItem]];
//
//
//    self.refreshHUD = [[S1HUD alloc] initWithFrame:CGRectZero];
//    [self.view addSubview:self.refreshHUD];
//    [self.refreshHUD mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.center.equalTo(self.view);
//        make.width.lessThanOrEqualTo(self.view).priorityLow();
//    }];
//
//    self.hintHUD = [[S1HUD alloc] initWithFrame:CGRectZero];
//    [self.view addSubview:self.hintHUD];
//    [self.hintHUD mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.centerX.equalTo(self.view.mas_centerX);
//        make.bottom.equalTo(self.toolBar.mas_top).offset(-10.0);
//        make.width.lessThanOrEqualTo(self.view.mas_width);
//
//    }];
//    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTopicViewedState:) name:UIApplicationDidEnterBackgroundNotification object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePaletteChangeNotification:) name:@"APPaletteDidChangeNotification" object:nil];
//
//    __weak __typeof__(self) weakSelf = self;
//    [[RACSignal combineLatest:@[RACObserve(self.viewModel, currentPage), RACObserve(self.viewModel, totalPages)]] subscribeNext:^(RACTuple *x) {
//        DDLogVerbose(@"[ContentVM] Current page or totoal page changed: %@/%@", x.first, x.second);
//        __strong __typeof__(self) strongSelf = weakSelf;
//        if (strongSelf == nil) {
//            return;
//        }
//        [strongSelf.pageButton setTitle:[strongSelf.viewModel pageButtonString] forState:UIControlStateNormal];
//    }];
//
//    [[RACSignal combineLatest:@[RACObserve(self, webPageDocumentReadyForAutomaticScrolling), RACObserve(self, webPageContentSizeChangedForAutomaticScrolling)]] subscribeNext:^(RACTuple *x) {
//        DDLogVerbose(@"[ContentVC] document ready: %@, content size changed: %@", x.first, x.second);
//        __strong __typeof__(self) strongSelf = weakSelf;
//        if (strongSelf == nil) {
//            return;
//        }
//        if ([x.first boolValue] && [x.second boolValue] && strongSelf.webPageAutomaticScrollingEnabled) {
//            [strongSelf didFinishBasicPageLoadForWebView:strongSelf.webView];
//            strongSelf.webPageAutomaticScrollingEnabled = NO;
//        }
//    }];
//
//    [[self.favoriteButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
//        __strong __typeof__(self) strongSelf = weakSelf;
//        if (strongSelf == nil) {
//            return;
//        }
//        [strongSelf.viewModel toggleFavorite];
//    }];
//
//    [RACObserve(self.viewModel.topic, favorite) subscribeNext:^(id x) {
//        __strong __typeof__(self) strongSelf = weakSelf;
//        if (strongSelf == nil) {
//            return;
//        }
//        [strongSelf.favoriteButton setImage:[strongSelf.viewModel favoriteButtonImage] forState:UIControlStateNormal];
//    }];
//
//    [self _setupActivity];
//
//    [self.view layoutIfNeeded];
//
//    DDLogDebug(@"[ContentVC] View Did Load 9");
//    [self fetchContentForCurrentPageWithForceUpdate:self.viewModel.currentPage == self.viewModel.totalPages];
//}
//

//
//#pragma mark - Actions
//
//- (void)back:(id)sender {
//    if (self.viewModel.currentPage > 1) {
//        [self preChangeCurrentPage];
//        self.viewModel.currentPage -= 1;
//        [self fetchContentForCurrentPageWithForceUpdate:NO];
//    } else {
//        [[self navigationController] popViewControllerAnimated:YES];
//    }
//}
//
//- (void)forward:(id)sender {
//    if (self.viewModel.currentPage < self.viewModel.totalPages) {
//        [self preChangeCurrentPage];
//        self.viewModel.currentPage += 1;
//        [self fetchContentForCurrentPageWithForceUpdate:NO];
//    } else { // currentPage is the last page
//        if (![self.webView s1_atBottom]) {
//            [self scrollToBottomAnimated:YES];
//        } else {
//            [self forceRefreshCurrentPage];
//        }
//    }
//}
//
//- (void)backLongPressed:(UIGestureRecognizer *)gr {
//    if (gr.state == UIGestureRecognizerStateBegan && self.viewModel.currentPage > 1) {
//        [self preChangeCurrentPage];
//        self.viewModel.currentPage = 1;
//        [self fetchContentForCurrentPageWithForceUpdate:NO];
//    }
//}
//
//- (void)forwardLongPressed:(UIGestureRecognizer *)gr {
//    if (gr.state == UIGestureRecognizerStateBegan && self.viewModel.currentPage < self.viewModel.totalPages) {
//        [self preChangeCurrentPage];
//        self.viewModel.currentPage = self.viewModel.totalPages;
//        [self fetchContentForCurrentPageWithForceUpdate:NO];
//    }
//}
//
//- (void)pickPage:(id)sender {
//    NSMutableArray *array = [[NSMutableArray alloc] init];
//    for (long i = 0; i < (self.viewModel.currentPage > self.viewModel.totalPages ? self.viewModel.currentPage : self.viewModel.totalPages); i++) {
//        if ([self.dataCenter hasPrecacheFloorsForTopic:self.viewModel.topic withPage:[NSNumber numberWithLong:i + 1]]) {
//            [array addObject:[NSString stringWithFormat:@"✓第 %ld 页✓", i + 1]];
//        } else {
//            [array addObject:[NSString stringWithFormat:@"第 %ld 页", i + 1]];
//        }
//    }
//    ActionSheetStringPicker *picker = [[ActionSheetStringPicker alloc] initWithTitle:@"" rows:array initialSelection:self.viewModel.currentPage - 1 doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
//
//        if (self.viewModel.currentPage != selectedIndex + 1) {
//            [self preChangeCurrentPage];
//            self.viewModel.currentPage = selectedIndex + 1;
//            [self fetchContentForCurrentPageWithForceUpdate:NO];
//        } else {
//            [self forceRefreshCurrentPage];
//        }
//
//    } cancelBlock:nil origin:self.pageButton];
//    picker.pickerBackgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.picker.background"];
//    picker.toolbarBackgroundColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.bartint"];
//    picker.toolbarButtonsColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.tint"];
//    
//    NSMutableParagraphStyle *labelParagraphStyle = [[NSMutableParagraphStyle alloc] init];
//    labelParagraphStyle.alignment = NSTextAlignmentCenter;
//    picker.pickerTextAttributes = [@{
//        NSParagraphStyleAttributeName: labelParagraphStyle,
//        NSFontAttributeName: [UIFont systemFontOfSize:19.0],
//        NSForegroundColorAttributeName: [[APColorManager sharedInstance] colorForKey:@"content.picker.text"]
//    } mutableCopy];
//    [picker showActionSheetPicker];
//}
//
//- (void)forceRefreshPressed:(UIGestureRecognizer *)gr {
//    if (gr.state == UIGestureRecognizerStateBegan) {
//        DDLogDebug(@"[ContentVC] Force refresh pressed");
//        [self forceRefreshCurrentPage];
//    }
//}
//
//- (void)forceRefreshCurrentPage {
//    [self cancelRequest];
//    [self saveViewPositionForCurrentPage];
//
//    [self fetchContentForCurrentPageWithForceUpdate:YES];
//}
//
//- (void)action:(id)sender {
//    UIAlertController *moreActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
//
//    // Reply Action
//    UIAlertAction *replyAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Reply", @"Reply") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//        [self presentReplyViewToFloor:nil];
//    }];
//
//    // Favorite Action
//    UIAlertAction *favoriteAction = [UIAlertAction actionWithTitle:[self.viewModel.topic.favorite boolValue] ? NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//        [self.viewModel toggleFavorite];
//        [self.hintHUD showMessage:[self.viewModel.topic.favorite boolValue] ? NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") : NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite")];
//        [self.hintHUD hideWithDelay:0.5];
//    }];
//
//    // Share Action
//    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Share", @"Share") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//        UIImage *screenShot = [self.view s1_screenShot];
//        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.viewModel.topic.title], [NSURL URLWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.viewModel.topic.topicID, (long)self.viewModel.currentPage]], screenShot] applicationActivities:nil];
//        [activityController.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
//        [self presentViewController:activityController animated:YES completion:nil];
//        [activityController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
//            DDLogDebug(@"[Activity] finish with activity type: %@",activityType);
//        }];
//    }];
//
//    // Copy Link
//    UIAlertAction *copyLinkAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
//        pasteboard.string = [[self.viewModel correspondingWebPageURL] absoluteString];
//        [self.refreshHUD showMessage:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link")];
//        [self.refreshHUD hideWithDelay:0.3];
//    }];
//
//    // Origin Page Action
//    UIAlertAction *originPageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_OriginPage", @"Origin") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//        _presentingWebViewer = YES;
//        [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
//        NSURL *URLToOpen = [self.viewModel correspondingWebPageURL];
//        if (URLToOpen != nil) {
//            WebViewController *controller = [[WebViewController alloc] initWithURL:URLToOpen];
//            [self presentViewController:controller animated:YES completion:nil];
//        }
//    }];
//
//    // Cancel Action
//    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
//
//    [moreActionSheet addAction:replyAction];
//    if (![self shouldPresentingFavoriteButtonOnToolBar]) {
//        [moreActionSheet addAction:favoriteAction];
//    }
//
//    [moreActionSheet addAction:shareAction];
//    [moreActionSheet addAction:copyLinkAction];
//    [moreActionSheet addAction:originPageAction];
//    [moreActionSheet addAction:cancelAction];
//    [moreActionSheet.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
//    [self presentViewController:moreActionSheet animated:YES completion:nil];
//}
//
//#pragma mark - WKNavigationDelegate
//
//- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
//    DDLogInfo(@"[ContentVC] did commit navigation: %@", navigation);
//}
//
//- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
//    DDLogInfo(@"[ContentVC] webViewDidFinishLoad");
//    [self didFinishFullPageLoadForWebView:webView];
//}
//
//- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
//    DDLogWarn(@"[ContentVC] webview failed to load with error: %@", error);
//    [self didFinishFullPageLoadForWebView:webView];
//}
//
//- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
//    NSURLRequest *request = navigationAction.request;
//    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
//        decisionHandler(WKNavigationActionPolicyAllow);
//        return;
//    }
//    if ([request.URL.absoluteString hasPrefix:@"file://"]) {
//        if ([request.URL.absoluteString hasSuffix:@"html"]) {
//            decisionHandler(WKNavigationActionPolicyAllow);
//            return;
//        }
//
//        if ([request.URL.path isEqualToString:@"/ready"]) {
//            DDLogDebug(@"[WebView] ready");
//            self.webPageDocumentReadyForAutomaticScrolling = YES;
//            decisionHandler(WKNavigationActionPolicyCancel);
//            return;
//        }
//
//        // Reply
//        if ([request.URL.path isEqualToString:@"/reply"]) {
//            NSString *floorID = [request.URL.query stringByRemovingPercentEncoding];
//            [self actionButtonTappedFor:floorID];
//            decisionHandler(WKNavigationActionPolicyCancel);
//            return;
//        }
//
//        // Present User
//        if ([request.URL.path isEqualToString:@"/user"]) {
//            [Answers logCustomEventWithName:@"[Content] User" customAttributes:nil];
//            NSNumber *userID = [NSNumber numberWithInteger:[request.URL.query integerValue]];
//            [self showUserViewController:userID];
//            decisionHandler(WKNavigationActionPolicyCancel);
//            return;
//        }
//
//        // Present image
//        if ([request.URL.path hasPrefix:@"/present-image:"]) {
//            _presentingImageViewer = YES;
//            [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
//            [Answers logCustomEventWithName:@"[Content] Image" customAttributes:@{@"type": @"processed"}];
//
//            NSString *imageID = request.URL.fragment;
//            NSString *imageURL = [request.URL.path stringByReplacingCharactersInRange:NSRangeFromString(@"0 15") withString:@""];
//            DDLogDebug(@"[ContentVC] JTS View Image: %@", imageURL);
//            JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
//            imageInfo.imageURL = [[NSURL alloc] initWithString:imageURL];
//            imageInfo.referenceRect = [self positionOfElementWithId:imageID];
//            imageInfo.referenceView = self.webView;
//
//            JTSImageViewController *imageViewer = [[JTSImageViewController alloc] initWithImageInfo:imageInfo mode:JTSImageViewControllerMode_Image backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
//            [imageViewer setInteractionsDelegate:self];
//            [imageViewer setOptionsDelegate:self];
//            [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
//            decisionHandler(WKNavigationActionPolicyCancel);
//            return;
//        }
//    }
//
//    //Image URL opened in image Viewer
//    if ([request.URL.path hasSuffix:@".jpg"] || [request.URL.path hasSuffix:@".gif"]) {
//        _presentingImageViewer = YES;
//        [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
//        [Answers logCustomEventWithName:@"[Content] Image" customAttributes:@{@"type": @"hijack"}];
//
//        NSString *imageURL = request.URL.absoluteString;
//        DDLogDebug(@"[ContentVC] JTS View Image: %@", imageURL);
//        JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
//        imageInfo.imageURL = request.URL;
//
//        JTSImageViewController *imageViewer = [[JTSImageViewController alloc] initWithImageInfo:imageInfo mode:JTSImageViewControllerMode_Image backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
//        [imageViewer setInteractionsDelegate:self];
//        [imageViewer setOptionsDelegate:self];
//        [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOffscreen];
//        decisionHandler(WKNavigationActionPolicyCancel);
//        return;
//    }
//
//
//    if ([request.URL.absoluteString hasPrefix:[[NSUserDefaults standardUserDefaults] stringForKey:@"BaseURL"]]) {
//
//        // Open S1 topic
//        S1Topic *topic = [S1Parser extractTopicInfoFromLink:request.URL.absoluteString];
//        if (topic.topicID != nil) {
//            S1Topic *tracedTopic = [self.dataCenter tracedTopic:topic.topicID];
//            if (tracedTopic != nil) {
//                NSNumber *lastViewedPage = topic.lastViewedPage;
//                topic = [tracedTopic copy];
//                topic.lastViewedPage = lastViewedPage;
//            }
//            _presentingContentViewController = YES;
//            S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:self.dataCenter];
//            [[self navigationController] pushViewController:contentViewController animated:YES];
//            [Answers logCustomEventWithName:@"[Content] Topic Link" customAttributes:nil];
//            decisionHandler(WKNavigationActionPolicyCancel);
//            return;
//        }
//
//        // Open Quote Link
//        NSDictionary *querys = [S1Parser extractQuerysFromURLString:request.URL.absoluteString];
//        if (querys) {
//            DDLogDebug(@"[ContentVC] Extract query: %@",querys);
//            if ([[querys valueForKey:@"mod"] isEqualToString:@"redirect"]) {
//                if ([[querys valueForKey:@"ptid"] integerValue] == [self.viewModel.topic.topicID integerValue]) {
//                    NSInteger tid = [[querys valueForKey:@"ptid"] integerValue];
//                    NSInteger pid = [[querys valueForKey:@"pid"] integerValue];
//                    if (tid == [self.viewModel.topic.topicID integerValue]) {
//                        NSArray *chainQuoteFloors = [self.viewModel chainSearchQuoteFloorInCache:pid];
//                        if ([chainQuoteFloors count] > 0) {
//                            _presentingContentViewController = YES;
//                            S1Topic *quoteTopic = [self.viewModel.topic copy];
//                            NSString *htmlString = [S1ContentViewModel generateContentPage:chainQuoteFloors withTopic:quoteTopic];
//                            [self showQuoteFloorViewControllerWithTopic:quoteTopic floors:chainQuoteFloors htmlString: htmlString centerFloorID: [[chainQuoteFloors lastObject] ID]];
//                            [Answers logCustomEventWithName:@"[Content] Quote Link" customAttributes:nil];
//                            decisionHandler(WKNavigationActionPolicyCancel);
//                            return;
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    // Open link
//
//    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString preferredStyle:UIAlertControllerStyleAlert];
//    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") style:UIAlertActionStyleDefault handler:nil];
//
//    __weak __typeof__(self) weakSelf = self;
//    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
//        __strong __typeof__(self) strongSelf = weakSelf;
//        strongSelf->_presentingWebViewer = YES;
//        [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
//        if (SYSTEM_VERSION_LESS_THAN(@"9")) {
//            DDLogDebug(@"[ContentVC] Open in WebView: %@", request.URL);
//            WebViewController *webViewController = [[WebViewController alloc] initWithURL:request.URL];
//            [strongSelf presentViewController:webViewController animated:YES completion:nil];
//        } else {
//            DDLogDebug(@"[ContentVC] Open in Safari: %@", request.URL);
//            if (![[UIApplication sharedApplication] openURL:request.URL]) {
//                DDLogWarn(@"Failed to open url: %@", request.URL);
//            }
//        }
//    }];
//
//    [alert addAction:cancelAction];
//    [alert addAction:continueAction];
//    
//    [self presentViewController:alert animated:YES completion:nil];
//    
//    decisionHandler(WKNavigationActionPolicyCancel);
//    return;
//}
//
//#pragma mark JTSImageViewControllerInteractionsDelegate
//
//- (void)imageViewerDidLongPress:(JTSImageViewController *)imageViewer atRect:(CGRect)rect {
//    UIAlertController *imageActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
//    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ImageViewer_ActionSheet_Save", @"Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            UIImageWriteToSavedPhotosAlbum(imageViewer.image, nil, nil, nil);
//        });
//    }];
//    UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ImageViewer_ActionSheet_CopyURL", @"Copy URL") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
//        pasteboard.string = imageViewer.imageInfo.imageURL.absoluteString;
//    }];
//    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
//    [imageActionSheet addAction:saveAction];
//    [imageActionSheet addAction:copyURLAction];
//    [imageActionSheet addAction:cancelAction];
//    [imageActionSheet.popoverPresentationController setSourceView:imageViewer.view];
//    [imageActionSheet.popoverPresentationController setSourceRect:rect];
//    [imageViewer presentViewController:imageActionSheet animated:YES completion:nil];
//}
//
//#pragma mark JTSImageViewControllerOptionsDelegate
//
//- (CGFloat)alphaForBackgroundDimmingOverlayInImageViewer:(JTSImageViewController *)imageViewer {
//    return 0.3;
//}
//
//#pragma mark REComposeViewControllerDelegate
//
//- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result {
//    self.attributedReplyDraft = [composeViewController.textView.attributedText mutableCopy];
//    if (result == REComposeResultCancelled) {
//        [composeViewController dismissViewControllerAnimated:YES completion:NULL];
//    } else if (result == REComposeResultPosted) {
//        if (composeViewController.plainText.length > 0) {
//            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
//            [[MTStatusBarOverlay sharedInstance] postMessage:@"回复发送中" animated:YES];
//            __weak __typeof__(self) weakSelf = self;
//            void (^successBlock)() = ^{
//                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
//                [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
//                __strong __typeof__(self) strongSelf = weakSelf;
//                if (strongSelf == nil) {
//                    return;
//                }
//
//                strongSelf.attributedReplyDraft = nil;
//                if (strongSelf.viewModel.currentPage == strongSelf.viewModel.totalPages) {
//                    strongSelf.scrollType = S1ContentScrollTypeToBottom;
//                    [strongSelf fetchContentForCurrentPageWithForceUpdate:YES];
//                }
//            };
//            void (^failureBlock)() = ^(NSError *error) {
//                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
//                if (error.code == NSURLErrorCancelled) {
//                    DDLogDebug(@"[Network] NSURLErrorCancelled");
//                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
//                } else {
//                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复失败" duration:2.5 animated:YES];
//                }
//            };
//
//            if (self.replyTopicFloor) {
//                [self.dataCenter replySpecificFloor:self.replyTopicFloor inTopic:self.viewModel.topic atPage:[NSNumber numberWithUnsignedInteger:self.viewModel.currentPage] withText:composeViewController.plainText success: successBlock failure:failureBlock];
//            } else {
//                [self.dataCenter replyTopic:self.viewModel.topic withText:composeViewController.plainText success:successBlock failure:failureBlock];
//            }
//            [composeViewController dismissViewControllerAnimated:YES completion:nil];
//        }
//    }
//}
//
//#pragma mark - Networking
//
//- (void)fetchContentForCurrentPageWithForceUpdate:(BOOL)forceUpdate {
//    [self updateToolBar];
//
//    self.userActivity.needsSave = YES;
//   
//    //remove cache for last page
//    if (forceUpdate) {
//        [self.dataCenter removePrecachedFloorsForTopic:self.viewModel.topic withPage:[NSNumber numberWithUnsignedInteger:self.viewModel.currentPage]];
//    }
//    //Set up HUD
//    DDLogVerbose(@"[ContentVC] check precache exist");
//
//    if (![self.dataCenter hasPrecacheFloorsForTopic:self.viewModel.topic withPage:[NSNumber numberWithUnsignedInteger:self.viewModel.currentPage]]) {
//        DDLogVerbose(@"[ContentVC] Show HUD");
//        [self.refreshHUD showActivityIndicator];
//
//        __weak __typeof__(self) weakSelf = self;
//        [self.refreshHUD setRefreshEventHandler:^(S1HUD *aHUD) {
//            __strong __typeof__(self) strongSelf = weakSelf;
//            if (strongSelf == nil) {
//                return;
//            }
//
//            [aHUD hideWithDelay:0.0];
//            [strongSelf fetchContentForCurrentPageWithForceUpdate:NO];
//        }];
//    }
//
//    __weak __typeof__(self) weakSelf = self;
//    [self.viewModel contentPageWithSuccess:^(NSString *contents, bool shouldRefetch) {
//        __strong __typeof__(self) strongSelf = weakSelf;
//        if (strongSelf == nil) {
//            return;
//        }
//
//        [strongSelf updateToolBar];
//        [strongSelf updateTitleLabelWithTitle:strongSelf.viewModel.topic.title];
//
//        [strongSelf saveViewPositionForPreviousPage];
//
//        strongSelf->_finishFirstLoading = YES;
//
//        [strongSelf.webView loadHTMLString:contents baseURL:[S1ContentViewModel pageBaseURL]];
//
//        // Prepare next page
//        if (strongSelf.viewModel.currentPage < strongSelf.viewModel.totalPages) {
//            NSNumber *cachePage = [NSNumber numberWithUnsignedInteger:strongSelf.viewModel.currentPage + 1];
//            [strongSelf.dataCenter setFinishHandlerForTopic:strongSelf.viewModel.topic withPage:cachePage andHandler:^(NSArray *floorList) {
//                __strong __typeof__(self) strongSelf = weakSelf;
//                [strongSelf updateToolBar];
//            }];
//            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PrecacheNextPage"]) {
//                [strongSelf.dataCenter precacheFloorsForTopic:strongSelf.viewModel.topic withPage:cachePage shouldUpdate:NO];
//            }
//        }
//        // Dismiss HUD if exist
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [strongSelf hideHUDIfNoMessageToShow];
//        });
//
//        // Auto refresh when current page not full.
//        if (shouldRefetch) {
//            strongSelf.scrollType = S1ContentScrollTypeRestorePosition;
//            [strongSelf fetchContentForCurrentPageWithForceUpdate:YES];
//        }
//        
//    } failure:^(NSError *error) {
//        __strong __typeof__(self) strongSelf = weakSelf;
//        if (error.code == NSURLErrorCancelled) {
//            DDLogDebug(@"request cancelled.");
//            // TODO:
////            if (strongSelf.refreshHUD != nil) {
////                [strongSelf.refreshHUD hideWithDelay:0.3];
////            }
//        } else {
//            DDLogDebug(@"%@", error);
//            if (strongSelf.refreshHUD != nil) {
//                [strongSelf.refreshHUD showRefreshButton];
//            }
//        }
//    }];
//}
//
//- (void)cancelRequest {
//    [self.dataCenter cancelRequest];
//}
//
//#pragma mark - Layout
//
//- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
//    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
//    DDLogDebug(@"viewWillTransitionToSize: w%f,h%f ",size.width, size.height);
//    CGRect frame = self.view.frame;
//    frame.size = size;
//    self.view.frame = frame;
//    
//    // Update Toolbar Layout
//    NSArray *items = self.toolBar.items;
//    UIBarButtonItem *favoriteItem = items[6];
//    UIBarButtonItem *fixItem2 = items[7];
//    if ([self shouldPresentingFavoriteButtonOnToolBar]) {
//        favoriteItem.customView.bounds = CGRectMake(0, 0, 30, 40);
//        favoriteItem.customView.hidden = NO;
//        fixItem2.width = 48.0;
//    } else {
//        favoriteItem.customView.bounds = CGRectZero;
//        favoriteItem.customView.hidden = YES;
//        fixItem2.width = 0.0;
//    }
//    self.toolBar.items = items;
//}
//
//#pragma mark - Reply
//
//- (void)presentReplyViewToFloor: (Floor *)topicFloor {
//    // Check in login state.
//    if (self.viewModel.topic.fID == nil || self.viewModel.topic.formhash == nil) {
//        [self alertRefresh];
//        return;
//    }
//
//    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"]) {
//        S1LoginViewController *loginViewController = [[S1LoginViewController alloc] initWithNibName:nil bundle:nil];
//        [self presentViewController:loginViewController animated:YES completion:NULL];
//        return;
//    }
//
//    REComposeViewController *replyController = [[REComposeViewController alloc] initWithNibName:nil bundle:nil];
//
//    replyController.textView.keyboardAppearance = [[APColorManager sharedInstance] isDarkTheme] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
//    replyController.sheetBackgroundColor = [[APColorManager sharedInstance] colorForKey:@"reply.background"];
//    replyController.textView.tintColor = [[APColorManager sharedInstance] colorForKey:@"reply.tint"];
//    replyController.textView.textColor = [[APColorManager sharedInstance] colorForKey:@"reply.text"];
//
//    // Set title
//    replyController.title = NSLocalizedString(@"ContentView_Reply_Title", @"Reply");
//    if (topicFloor) {
//        replyController.title = [@"@" stringByAppendingString:topicFloor.author.name];
//        self.replyTopicFloor = topicFloor;
//    } else {
//        self.replyTopicFloor = nil;
//    }
//
//    if (self.attributedReplyDraft != nil) {
//        [replyController.textView setAttributedText:self.attributedReplyDraft];
//    }
//
//    replyController.delegate = self;
//    replyController.accessoryView = [[ReplyAccessoryView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(replyController.view.bounds), 35) withComposeViewController:replyController];
//    [ReplyAccessoryView resetTextViewStyle:replyController.textView];
//
//    [self presentViewController:replyController animated:YES completion:NULL];
//}
//
//#pragma mark - Notificatons
//
//- (void)saveTopicViewedState:(id)sender {
//    DDLogDebug(@"[ContentVC] Save Topic View State Begin.");
//    if (_finishFirstLoading) {
//        self.viewModel.topic.lastViewedPosition = [NSNumber numberWithFloat:(float)self.webView.scrollView.contentOffset.y];
//    } else if (self.viewModel.topic.lastViewedPosition == nil || [self.viewModel.topic.lastViewedPage unsignedIntegerValue] != self.viewModel.currentPage) {
//        // If last viewed page in record doesn't equal current page it means user has changed page since this view controller is loaded.
//        // Then the unfinish loaded new page's last view position should be 0.
//        self.viewModel.topic.lastViewedPosition = [NSNumber numberWithFloat:(float)0.0];
//    }
//    self.viewModel.topic.lastViewedPage = [NSNumber numberWithInteger:self.viewModel.currentPage];
//    self.viewModel.topic.lastViewedDate = [NSDate date];
//    self.viewModel.topic.lastReplyCount = self.viewModel.topic.replyCount;
//    [self.dataCenter hasViewed:self.viewModel.topic];
//    DDLogInfo(@"[ContentVC] Save Topic View State Finish.");
//}
//
//- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
//    self.view.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.background"];
//    self.webView.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];
//
//    self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
//    self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
//    if (self.viewModel.topic.title == nil || [self.viewModel.topic.title isEqualToString:@""]) {
//        self.titleLabel.text = [NSString stringWithFormat: @"%@ 载入中...", self.viewModel.topic.topicID];
//        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.disable"];
//    } else {
//        self.titleLabel.text = self.viewModel.topic.title;
//        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
//    }
//    [self.pageButton setTitleColor:[[APColorManager sharedInstance] colorForKey:@"content.pagebutton.text"] forState:UIControlStateNormal];
//    self.toolBar.barTintColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.bartint"];
//    self.toolBar.tintColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.tint"];
//
//    [self setNeedsStatusBarAppearanceUpdate];
//
//    [self saveViewPositionForCurrentPage];
//    [self fetchContentForCurrentPageWithForceUpdate:NO];
//}
//
//#pragma mark - Helpers
//
//- (void)scrollToBottomAnimated:(BOOL)animated {
//    [self.webView.scrollView setContentOffset:CGPointMake(0, self.webView.scrollView.contentSize.height - self.webView.scrollView.bounds.size.height) animated:animated];
//}
//
//- (void)updateToolBar {
//    [self updateForwardButton];
//    [self updateBackwardButton];
//}
//
//- (void)updateForwardButton {
//    [self.forwardButton setImage:[self.viewModel forwardButtonImage] forState:UIControlStateNormal];
//}
//
//- (void)updateBackwardButton {
//    [self.backButton setImage:[self.viewModel backwardButtonImage] forState:UIControlStateNormal];
//}
//
//- (void)updateTitleLabelWithTitle:(NSString *)title {
//    self.titleLabel.text = title;
//    self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
//}
//
//- (void)updateDecorationLines:(CGSize)contentSize {
//    self.topDecorateLine.frame = CGRectMake(0, topOffset, contentSize.width, 1);
//    self.bottomDecorateLine.frame = CGRectMake(0, contentSize.height + bottomOffset, contentSize.width, 1);
//    self.topDecorateLine.hidden = !(self.viewModel.currentPage != 1 && _finishFirstLoading);
//    self.bottomDecorateLine.hidden = !_finishFirstLoading;
//}
//
//- (CGRect)positionOfElementWithId:(NSString *)elementID {
//    NSString *js = @"function f(){ var r = document.getElementById('%@').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();";
////    NSString *result = [self.webView stringByEvaluatingJavaScriptFromString:];
////    CGRect rect = CGRectFromString(result);
//    __block CGRect rect = CGRectZero;
//    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
//    [self.webView evaluateJavaScript:[NSString stringWithFormat:js, elementID] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
//        if (error != nil) {
//            DDLogWarn(@"failed to get position of element: %@", elementID);
//            dispatch_semaphore_signal(semaphore);
//        }
//        rect = CGRectFromString(result);
//        dispatch_semaphore_signal(semaphore);
//    }];
//    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
//    return rect;
//}
//
//- (void)saveViewPositionForCurrentPage {
//    if (self.webView.scrollView.contentOffset.y != 0) {
//        [self.viewModel cacheOffsetForCurrentPage:self.webView.scrollView.contentOffset.y];
//    }
//}
//
//- (void)saveViewPositionForPreviousPage {
//    if (self.webView.scrollView.contentOffset.y != 0) {
//        [self.viewModel cacheOffsetForPreviousPage:self.webView.scrollView.contentOffset.y];
//    }
//}
//
//- (BOOL)shouldPresentingFavoriteButtonOnToolBar {
//    return CGRectGetWidth(self.view.bounds) > 321.0;
//}
//
//- (void)hideHUDIfNoMessageToShow {
//    if (self.viewModel.topic.message == nil || [self.viewModel.topic.message isEqualToString:@""]) {
//        [self.refreshHUD hideWithDelay:0.3];
//    } else {
//        [self.refreshHUD showMessage:self.viewModel.topic.message];
//    }
//}
//
//#pragma mark - Restore Position
//
//- (void)preChangeCurrentPage {
//    DDLogDebug(@"[webView] pre change current page");
//    [self cancelRequest];
//    [self saveViewPositionForCurrentPage];
//    self.webPageDocumentReadyForAutomaticScrolling = NO;
//    self.webPageContentSizeChangedForAutomaticScrolling = NO;
//    self.webPageAutomaticScrollingEnabled = YES;
//}
//
//- (void)preLoadNextPage {
//
//}
//
//- (void)didFinishBasicPageLoadForWebView:(WKWebView *)webView {
//    DDLogDebug(@"[webView] basic page loaded");
//    CGFloat maxOffset = webView.scrollView.contentSize.height - CGRectGetHeight(webView.scrollView.bounds);
//
//    switch (self.scrollType) {
//        case S1ContentScrollTypePullUpForNext: {
//            // Set position
//            [webView.scrollView setContentOffset:CGPointMake(0.0, -CGRectGetHeight(webView.bounds)) animated:NO];
//            // Animated scroll
//            [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
//                [webView.scrollView setContentOffset:CGPointMake(0.0, 0.0) animated:NO];
//                webView.scrollView.alpha = 1.0;
//            } completion:NULL];
//            break;
//        }
//        case S1ContentScrollTypePullDownForPrevious: {
//            // Set position
//            [webView.scrollView setContentOffset:CGPointMake(0.0, webView.scrollView.contentSize.height) animated:NO];
//            // Animated scroll
//            [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
//                [webView.scrollView setContentOffset:CGPointMake(0.0, maxOffset) animated:NO];
//                webView.scrollView.alpha = 1.0;
//            } completion:NULL];
//            break;
//        }
//        case S1ContentScrollTypeToBottom:
//            [webView.scrollView setContentOffset:CGPointMake(0, maxOffset) animated:YES];
//            break;
//        default:
//            break;
//    }
//}
//    
//- (void)didFinishFullPageLoadForWebView:(WKWebView *)webView {
//    DDLogDebug(@"[webView] full page loaded");
//    CGFloat maxOffset = webView.scrollView.contentSize.height - CGRectGetHeight(webView.scrollView.bounds);
//
//    switch (self.scrollType) {
//        case S1ContentScrollTypeToBottom:
//        case S1ContentScrollTypePullDownForPrevious:
//            [webView.scrollView setContentOffset:CGPointMake(0, maxOffset) animated:NO];
//            break;
//        case S1ContentScrollTypePullUpForNext:
//            [webView.scrollView setContentOffset:CGPointMake(0.0, 0.0) animated:NO];
//            break;
//        default: {
//            NSNumber *positionForPage = [self.viewModel cachedOffsetForCurrentPage];
//            if (positionForPage != nil) {
//                // Restore last view position from cached position in this view controller.
//                [webView.scrollView setContentOffset:CGPointMake(webView.scrollView.contentOffset.x, fmax(fmin(maxOffset, [positionForPage doubleValue]), 0.0)) animated:NO];
//            }
//            break;
//        }
//    }
//
//    self.scrollType = S1ContentScrollTypeRestorePosition;
//}
//
//#pragma mark - Getters and Setters
//
//- (UIButton *)backButton {
//    if (_backButton == nil) {
//        _backButton = [UIButton buttonWithType:UIButtonTypeSystem];
//        [_backButton setImage:[UIImage imageNamed:@"Back"] forState:UIControlStateNormal];
//        _backButton.frame = CGRectMake(0, 0, 40, 30);
//        _backButton.imageView.clipsToBounds = NO;
//        _backButton.imageView.contentMode = UIViewContentModeCenter;
//        [_backButton addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
//        UILongPressGestureRecognizer *backLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backLongPressed:)];
//        backLongPressGR.minimumPressDuration = 0.5;
//        [_backButton addGestureRecognizer:backLongPressGR];
//    }
//    return _backButton;
//}
//
//- (UIButton *)forwardButton {
//    if (_forwardButton == nil) {
//        _forwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
//        if (self.viewModel.currentPage == self.viewModel.totalPages) {
//            [_forwardButton setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
//        } else {
//            [_forwardButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
//        }
//        
//        _forwardButton.frame = CGRectMake(0, 0, 40, 30);
//        _forwardButton.imageView.clipsToBounds = NO;
//        _forwardButton.imageView.contentMode = UIViewContentModeCenter;
//        [_forwardButton addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
//        UILongPressGestureRecognizer *forwardLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardLongPressed:)];
//        forwardLongPressGR.minimumPressDuration = 0.5;
//        [_forwardButton addGestureRecognizer:forwardLongPressGR];
//    }
//    return _forwardButton;
//}
//
//- (UIButton *)pageButton {
//    if (_pageButton == nil) {
//        //Page Label
//        _pageButton = [UIButton buttonWithType:UIButtonTypeSystem];
//        _pageButton.frame = CGRectMake(0, 0, 80, 30);
//        _pageButton.titleLabel.font = [UIFont systemFontOfSize:13.0f];
//        [_pageButton setTitleColor:[[APColorManager sharedInstance] colorForKey:@"content.pagebutton.text"] forState:UIControlStateNormal];
//        _pageButton.backgroundColor = [UIColor clearColor];
//        _pageButton.titleLabel.textAlignment = NSTextAlignmentCenter;
//        _pageButton.userInteractionEnabled = YES;
//        [_pageButton addTarget:self action:@selector(pickPage:) forControlEvents:UIControlEventTouchUpInside];
//        UILongPressGestureRecognizer *forceRefreshGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forceRefreshPressed:)];
//        forceRefreshGR.minimumPressDuration = 0.5;
//        [_pageButton addGestureRecognizer:forceRefreshGR];
//    }
//    return _pageButton;
//}
//
//- (UIBarButtonItem *)actionBarButtonItem {
//    if (_actionBarButtonItem == nil) {
//        _actionBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
//    }
//    return _actionBarButtonItem;
//}
//
//@end
//
//NS_ASSUME_NONNULL_END
