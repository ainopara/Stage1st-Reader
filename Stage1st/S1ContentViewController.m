//
//  S1ContentViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//


#import "S1ContentViewController.h"
#import "S1ContentViewModel.h"
#import "S1Topic.h"
#import "S1Floor.h"
#import "S1Parser.h"
#import "S1DataCenter.h"
#import "S1HUD.h"
#import "REComposeViewController.h"
#import "MTStatusBarOverlay.h"
#import <ActionSheetPicker_3_0/ActionSheetStringPicker.h>
#import "JTSSimpleImageDownloader.h"
#import "JTSImageViewController.h"
#import "S1MahjongFaceView.h"
#import "Masonry.h"
#import "NavigationControllerDelegate.h"
#import <Crashlytics/Answers.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

#define TOP_OFFSET -80.0
#define BOTTOM_OFFSET 60.0

@interface S1ContentViewController () <UIWebViewDelegate, JTSImageViewControllerInteractionsDelegate, JTSImageViewControllerOptionsDelegate, REComposeViewControllerDelegate, PullToActionDelagete>

@property (nonatomic, strong) UIToolbar *toolBar;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) PullToActionController *pullToActionController;

@property (nonatomic, strong) S1HUD *refreshHUD;

@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *forwardButton;
@property (nonatomic, strong) UIButton *pageButton;
@property (nonatomic, strong) UIButton *favoriteButton;
@property (nonatomic, strong) UIBarButtonItem *actionBarButtonItem;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *topDecorateLine;
@property (nonatomic, strong) UIView *bottomDecorateLine;

@property (nonatomic, strong) NSMutableAttributedString *attributedReplyDraft;
@property (nonatomic, strong) NSMutableDictionary *cachedViewPosition;

@property (nonatomic, weak) S1Floor *replyTopicFloor;

@property (nonatomic, assign) NSUInteger currentPage;
@property (nonatomic, assign) NSUInteger totalPages;

@end

@implementation S1ContentViewController {
    BOOL _needToScrollToBottom;
    BOOL _needToLoadLastPositionFromModel;
    BOOL _finishFirstLoading;
    BOOL _shouldRestoreViewPosition;
    BOOL _pullUpForNext;
    BOOL _pullDownForPrevious;

    BOOL _presentingImageViewer;
    BOOL _presentingWebViewer;
    BOOL _presentingContentViewController;
}

#pragma mark - Life Cycle

- (instancetype)initWithTopic:(S1Topic *)topic dataCenter:(S1DataCenter *)dataCenter {
    self = [super initWithNibName:nil bundle:nil];
    if (self != nil) {
        // Custom initialization

        _currentPage = 1;

        [self setTopic:topic];
        _dataCenter = dataCenter;
        _viewModel = [[S1ContentViewModel alloc] initWithTopic:topic dataCenter:self.dataCenter];

        _needToLoadLastPositionFromModel = YES;

        _cachedViewPosition = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithViewModel:(S1ContentViewModel *)viewModel {
    return [self initWithTopic:viewModel.topic dataCenter:viewModel.dataCenter];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.background"];

    self.toolBar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    self.toolBar.translucent = NO;
    [self.view addSubview:self.toolBar];
    [self.toolBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.and.trailing.equalTo(self.view);
        make.bottom.equalTo(self.mas_bottomLayoutGuideTop);
    }];
    DDLogDebug(@"[ContentVC] View Did Load2");
    //web view
    self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    self.webView.delegate = self;
    DDLogDebug(@"[ContentVC] Why so slow on iPhone 5s?");
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    DDLogDebug(@"[ContentVC] Why so slow on iPhone 5s?");
    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    [self.webView.scrollView.panGestureRecognizer requireGestureRecognizerToFail:[(NavigationControllerDelegate *)self.navigationController.delegate colorPanRecognizer]];
    self.webView.opaque = NO;
    self.webView.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];
    [self.view addSubview:self.webView];

    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.and.trailing.equalTo(self.view);
        make.top.equalTo(self.mas_topLayoutGuideBottom);
        make.bottom.equalTo(self.toolBar.mas_top);
    }];

    self.pullToActionController = [[PullToActionController alloc] initWithScrollView:self.webView.scrollView];
    [self.pullToActionController addConfigurationWithName:@"top" baseLine:OffsetBaseLineTop beginPosition:0.0 endPosition:TOP_OFFSET];
    [self.pullToActionController addConfigurationWithName:@"bottom" baseLine:OffsetBaseLineBottom beginPosition:0.0 endPosition:BOTTOM_OFFSET];
    self.pullToActionController.delegate = self;
    
    self.topDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, TOP_OFFSET, self.view.bounds.size.width, 1)];
    self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    [self.webView.scrollView addSubview:self.topDecorateLine];

    self.bottomDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, TOP_OFFSET, self.view.bounds.size.width, 1)]; // will be updated soon in delegate.
    self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    [self.webView.scrollView addSubview:self.bottomDecorateLine];

    //title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;

    if (self.topic.title == nil || [self.topic.title isEqualToString:@""]) {
        self.titleLabel.text = [NSString stringWithFormat: @"%@ 载入中...", self.topic.topicID];
        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.disable"];
    } else {
        self.titleLabel.text = self.topic.title;
        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
    }

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    [self.webView.scrollView insertSubview:self.titleLabel atIndex:0];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.webView.scrollView.subviews[1].mas_top);
        make.centerX.equalTo(self.webView.mas_centerX);
        make.width.equalTo(self.webView.mas_width).with.offset(-24);
    }];

    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithCustomView:self.forwardButton];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:self.backButton];

    // Favorite Button
    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if ([self.topic.favorite boolValue]) {
        [self.favoriteButton setImage:[UIImage imageNamed:@"Favorited"] forState:UIControlStateNormal];
    } else {
        [self.favoriteButton setImage:[UIImage imageNamed:@"Favorite"] forState:UIControlStateNormal];
    }
    self.favoriteButton.frame = CGRectMake(0, 0, 40, 30);
    self.favoriteButton.imageView.clipsToBounds = NO;
    self.favoriteButton.imageView.contentMode = UIViewContentModeCenter;
    [self.favoriteButton addTarget:self action:@selector(toggleFavoriteAction:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *favoriteItem = [[UIBarButtonItem alloc] initWithCustomView:self.favoriteButton];

    [self updateToolBar];
    
    UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithCustomView:self.pageButton];
    labelItem.width = 80;
    
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 26.0f;
    UIBarButtonItem *fixItem2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem2.width = 48.0f;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    // Hide Favorite button when device do not have enough space for it.
    if (![self shouldPresentingFavoriteButtonOnToolBar]) {
        favoriteItem.customView.bounds = CGRectZero;
        favoriteItem.customView.hidden = YES;
        fixItem2.width = 0.0;
    }
    
    [self.toolBar setItems:@[backItem, fixItem, forwardItem, flexItem, labelItem, flexItem, favoriteItem, fixItem2, self.actionBarButtonItem]];

    self.refreshHUD = [[S1HUD alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.refreshHUD];
    [self.refreshHUD mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTopicViewedState:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePaletteChangeNotification:) name:@"S1PaletteDidChangeNotification" object:nil];

    [RACObserve(self.webView, isLoading) subscribeNext:^(id x) {
        DDLogInfo(@"[ContentVC] webView is loading: %@", x);
    }];

    [RACObserve(self, currentPage) subscribeNext:^(id x) {
        DDLogInfo(@"[ContentVC] Current page changed to: %@", x);
    }];

    [RACObserve(self.topic, replyCount) subscribeNext:^(id x) {
        DDLogInfo(@"[ContentVC] reply count changed: %@", x);
//        self.totalPages = ([x unsignedIntegerValue] / 30) + 1;
    }];

    [[RACSignal combineLatest:@[RACObserve(self, currentPage), RACObserve(self, totalPages)]] subscribeNext:^(RACTuple *x) {
        DDLogWarn(@"[ContentVC] Current page or totoal page changed: %@/%@", x.first, x.second);
    }];

    __weak __typeof__(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        //Set up Activity for Hand Off
        NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"Stage1st.view-topic"];
        activity.title = strongSelf.topic.title;
        activity.userInfo = @{@"topicID": strongSelf.topic.topicID,
                              @"page": [NSNumber numberWithInteger:strongSelf.currentPage]};
        activity.webpageURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], strongSelf.topic.topicID, (long)strongSelf.currentPage]];

        //iOS 9 Search api
        if (!SYSTEM_VERSION_LESS_THAN(@"9")) {
            activity.eligibleForSearch = YES;
            activity.requiredUserInfoKeys = [NSSet setWithObjects:@"topicID", nil];
        }
        strongSelf.userActivity = activity;
    });

    DDLogDebug(@"[ContentVC] View Did Load 9");
    [self fetchContentForPage:self.currentPage forceUpdate:self.currentPage == self.totalPages];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _presentingImageViewer = NO;
    _presentingWebViewer = NO;
    _presentingContentViewController = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    _presentingContentViewController = NO;
    [CrashlyticsKit setObjectValue:@"ContentViewController" forKey:@"lastViewController"];
    DDLogDebug(@"[ContentVC] View did appear");
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if (_presentingImageViewer || _presentingWebViewer || _presentingContentViewController) {
        return;
    }

    DDLogDebug(@"[ContentVC] View did disappear begin");
    [self cancelRequest];
    [self saveTopicViewedState:nil];
    DDLogDebug(@"[ContentVC] View did disappear end");
}

- (void)dealloc {
    DDLogInfo(@"[ContentVC] Dealloc Begin");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.pullToActionController.delegate = nil;
    self.pullToActionController = nil;
    self.webView.delegate = nil;
    self.webView.scrollView.delegate = nil;
    [self.webView stopLoading];
    DDLogInfo(@"[ContentVC] Dealloced");
}

#pragma mark - Actions

- (void)back:(id)sender {
    if (self.currentPage > 1) {
        [self preChangeCurrentPage];
        self.currentPage -= 1;
        [self fetchContentForPage:self.currentPage forceUpdate:NO];
    } else {
        [[self navigationController] popViewControllerAnimated:YES];
    }
}

- (void)forward:(id)sender {
    if (self.currentPage < self.totalPages) {
        [self preChangeCurrentPage];
        self.currentPage += 1;
        [self fetchContentForPage:self.currentPage forceUpdate:NO];
    } else { // currentPage is the last page
        if (![self.webView s1_atBottom]) {
            [self scrollToBottomAnimated:YES];
        } else {
            [self forceRefreshCurrentPage];
        }
    }
}

- (void)backLongPressed:(UIGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan && self.currentPage > 1) {
        [self preChangeCurrentPage];
        self.currentPage = 1;
        [self fetchContentForPage:self.currentPage forceUpdate:NO];
    }
}

- (void)forwardLongPressed:(UIGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan && self.currentPage < self.totalPages) {
        [self preChangeCurrentPage];
        self.currentPage = self.totalPages;
        [self fetchContentForPage:self.currentPage forceUpdate:NO];
    }
}

- (void)pickPage:(id)sender {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (long i = 0; i < (self.currentPage > self.totalPages ? self.currentPage : self.totalPages); i++) {
        if ([self.dataCenter hasPrecacheFloorsForTopic:self.topic withPage:[NSNumber numberWithLong:i + 1]]) {
            [array addObject:[NSString stringWithFormat:@"✓第 %ld 页✓", i + 1]];
        } else {
            [array addObject:[NSString stringWithFormat:@"第 %ld 页", i + 1]];
        }
    }
    ActionSheetStringPicker *picker = [[ActionSheetStringPicker alloc] initWithTitle:@"" rows:array initialSelection:self.currentPage - 1 doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {

        if (self.currentPage != selectedIndex + 1) {
            [self preChangeCurrentPage];
            self.currentPage = selectedIndex + 1;
            [self fetchContentForPage:self.currentPage forceUpdate:NO];
        } else {
            [self forceRefreshCurrentPage];
        }

    } cancelBlock:nil origin:self.pageButton];
    picker.pickerBackgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.picker.background"];
    
    NSMutableParagraphStyle *labelParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    labelParagraphStyle.alignment = NSTextAlignmentCenter;
    picker.pickerTextAttributes = @{NSParagraphStyleAttributeName: labelParagraphStyle,
                                    NSFontAttributeName: [UIFont systemFontOfSize:19.0],
                                    NSForegroundColorAttributeName: [[APColorManager sharedInstance] colorForKey:@"content.picker.text"],};
    [picker showActionSheetPicker];
}

- (void)forceRefreshPressed:(UIGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        DDLogDebug(@"[ContentVC] Force refresh pressed");
        [self forceRefreshCurrentPage];
    }
}

- (void)forceRefreshCurrentPage {
    [self cancelRequest];
    [self saveViewPosition];
    _needToLoadLastPositionFromModel = NO;

    [self fetchContentForPage:self.currentPage forceUpdate:YES];
}

- (void)toggleFavoriteAction:(UIButton *)sender {
    self.topic.favorite = [NSNumber numberWithBool:![self.topic.favorite boolValue]];
    if ([self.topic.favorite boolValue]) {
        self.topic.favoriteDate = [NSDate date];
    }
    if ([self.topic.favorite boolValue]) {
        [sender setImage:[UIImage imageNamed:@"Favorited"] forState:UIControlStateNormal];
    } else {
        [sender setImage:[UIImage imageNamed:@"Favorite"] forState:UIControlStateNormal];
    }
}

- (void)action:(id)sender
{
    UIAlertController *moreActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    // Reply Action
    UIAlertAction *replyAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Reply", @"Reply") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self presentReplyViewToFloor:nil];
    }];
    // Favorite Action
    UIAlertAction *favoriteAction = [UIAlertAction actionWithTitle:[self.topic.favorite boolValue]?NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.topic.favorite = [NSNumber numberWithBool:![self.topic.favorite boolValue]];
        if ([self.topic.favorite boolValue]) {
            self.topic.favoriteDate = [NSDate date];
        }
        [self.refreshHUD showMessage:[self.topic.favorite boolValue] ? NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") : NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite")];
        [self.refreshHUD hideWithDelay:0.3];
    }];
    // Share Action
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Share", @"Share") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIImage *screenShot = [self.view s1_screenShot];
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.topic.title], [NSURL URLWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)self.currentPage]], screenShot] applicationActivities:nil];
        [activityController.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
        [self presentViewController:activityController animated:YES completion:nil];
        [activityController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            DDLogDebug(@"[Activity] finish with activity type: %@",activityType);
        }];
    }];
    // Copy Link
    UIAlertAction *copyLinkAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)self.currentPage];
        [self.refreshHUD showMessage:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link")];
        [self.refreshHUD hideWithDelay:0.3];
    }];
    // Origin Page Action
    UIAlertAction *originPageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_OriginPage", @"Origin") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)self.currentPage];
        _presentingWebViewer = YES;
        [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
        S1WebViewController *controller = [[S1WebViewController alloc] initWithURL:[[NSURL alloc] initWithString:pageAddress]];
        [self presentViewController:controller animated:YES completion:nil];
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

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    // Load
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        return YES;
    }
    if ([request.URL.absoluteString hasPrefix:@"file://"]) {
        if ([request.URL.absoluteString hasSuffix:@"html"]) {
            return YES;
        }

        // Reply
        if ([request.URL.path isEqualToString:@"/reply"]) {
            NSString *floorID = [request.URL.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            S1Floor *floor = [self.viewModel searchFloorInCache:[floorID integerValue]];
            if (floor != nil) {
                DDLogDebug(@"[ContentVC] Reply to %@", floor.author);
                [self presentReplyViewToFloor:floor];
            }
            return NO;
        }

        // Present User
        if ([request.URL.path isEqualToString:@"/user"]) {
            [Answers logCustomEventWithName:@"[Content] User" customAttributes:nil];
            NSNumber *userID = [NSNumber numberWithInteger:[request.URL.query integerValue]];
            [self showUserViewController:userID];
            return NO;
        }

        // Present image
        if ([request.URL.path hasPrefix:@"/present-image:"]) {
            _presentingImageViewer = YES;
            [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
            [Answers logCustomEventWithName:@"[Content] Image" customAttributes:@{@"type": @"processed"}];

            NSString *imageID = request.URL.fragment;
            NSString *imageURL = [request.URL.path stringByReplacingCharactersInRange:NSRangeFromString(@"0 15") withString:@""];
            DDLogDebug(@"JTS View Image: %@", imageURL);
            JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
            imageInfo.imageURL = [[NSURL alloc] initWithString:imageURL];
            imageInfo.referenceRect = [self positionOfElementWithId:imageID];
            imageInfo.referenceView = self.webView;

            JTSImageViewController *imageViewer = [[JTSImageViewController alloc] initWithImageInfo:imageInfo mode:JTSImageViewControllerMode_Image backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
            [imageViewer setInteractionsDelegate:self];
            [imageViewer setOptionsDelegate:self];
            [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
            return NO;
        }
    }

    //Image URL opened in image Viewer
    if ([request.URL.path hasSuffix:@".jpg"] || [request.URL.path hasSuffix:@".gif"]) {
        _presentingImageViewer = YES;
        [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
        [Answers logCustomEventWithName:@"[Content] Image" customAttributes:@{@"type": @"hijack"}];

        NSString *imageURL = request.URL.absoluteString;
        DDLogDebug(@"JTS View Image: %@", imageURL);
        JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
        imageInfo.imageURL = request.URL;

        JTSImageViewController *imageViewer = [[JTSImageViewController alloc] initWithImageInfo:imageInfo mode:JTSImageViewControllerMode_Image backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
        [imageViewer setInteractionsDelegate:self];
        [imageViewer setOptionsDelegate:self];
        [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOffscreen];
        return NO;
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
            _presentingContentViewController = YES;
            S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:self.dataCenter];
            [[self navigationController] pushViewController:contentViewController animated:YES];
            [Answers logCustomEventWithName:@"[Content] Topic Link" customAttributes:nil];
            return NO;
        }

        // Open Quote Link
        NSDictionary *querys = [S1Parser extractQuerysFromURLString:request.URL.absoluteString];
        if (querys) {
            DDLogDebug(@"[ContentVC] Extract query: %@",querys);
            if ([[querys valueForKey:@"mod"] isEqualToString:@"redirect"]) {
                if ([[querys valueForKey:@"ptid"] integerValue] == [self.topic.topicID integerValue]) {
                    NSInteger tid = [[querys valueForKey:@"ptid"] integerValue];
                    NSInteger pid = [[querys valueForKey:@"pid"] integerValue];
                    if (tid == [self.topic.topicID integerValue]) {
                        NSArray *chainQuoteFloors = [self.viewModel chainSearchQuoteFloorInCache:pid];
                        if ([chainQuoteFloors count] > 0) {
                            _presentingContentViewController = YES;
                            S1Topic *quoteTopic = [self.topic copy];
                            NSString *htmlString = [S1ContentViewModel generateContentPage:chainQuoteFloors withTopic:quoteTopic];
                            S1QuoteFloorViewController *quoteFloorViewController = [[S1QuoteFloorViewController alloc] initWithNibName:nil bundle:nil];
                            quoteFloorViewController.topic = quoteTopic;
                            quoteFloorViewController.floors = chainQuoteFloors;
                            quoteFloorViewController.htmlString = htmlString;
                            quoteFloorViewController.pageURL = [S1ContentViewModel baseURL];
                            quoteFloorViewController.centerFloorID = [[[chainQuoteFloors lastObject] floorID] integerValue];
                            [[self navigationController] pushViewController:quoteFloorViewController animated:YES];
                            [Answers logCustomEventWithName:@"[Content] Quote Link" customAttributes:nil];
                            return NO;
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
        strongSelf->_presentingWebViewer = YES;
        [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
        if (SYSTEM_VERSION_LESS_THAN(@"9")) {
            DDLogDebug(@"[ContentVC] Open in WebView: %@", request.URL);
            S1WebViewController *webViewController = [[S1WebViewController alloc] initWithURL:request.URL];
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

    return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (self.webView != webView) {
        DDLogWarn(@"[ContentVC] webView delegate unexpected called.");
        return;
    }
    DDLogInfo(@"[ContentVC] webViewDidFinishLoad");
    CGFloat maxOffset = webView.scrollView.contentSize.height - CGRectGetHeight(webView.scrollView.bounds);
    NSNumber *positionForPage = [self.cachedViewPosition objectForKey:[NSNumber numberWithUnsignedInteger:self.currentPage]];

    // Set position
    if (_pullUpForNext) {
        [webView.scrollView setContentOffset:CGPointMake(0.0, -CGRectGetHeight(webView.bounds)) animated:NO];
    } else if (_pullDownForPrevious) {
        [webView.scrollView setContentOffset:CGPointMake(0.0, webView.scrollView.contentSize.height) animated:NO];
    } else if (positionForPage != nil) {
        // Restore last view position from cached position in this view controller.
        [webView.scrollView setContentOffset:CGPointMake(webView.scrollView.contentOffset.x, fmax(fmin(maxOffset, [positionForPage doubleValue]), 0.0))];
    } else if (_needToLoadLastPositionFromModel) {
        // Restore last view position when this content view first be loaded.s
        _needToLoadLastPositionFromModel = NO;
        if (self.topic.lastViewedPosition != 0) {
            [webView.scrollView setContentOffset:CGPointMake(webView.scrollView.contentOffset.x, fmax(fmin(maxOffset, [self.topic.lastViewedPosition doubleValue]), 0.0))];
        }
    }

    // Animated scroll
    if (_needToScrollToBottom) {
        // User want to scroll to bottom.
        _needToScrollToBottom = NO;
        [webView.scrollView setContentOffset:CGPointMake(0, maxOffset) animated:YES];
    } else if (_pullUpForNext) {
        _pullUpForNext = NO;
        [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [webView.scrollView setContentOffset:CGPointMake(0.0, 0.0) animated:NO];
            webView.scrollView.alpha = 1.0;
        } completion:NULL];
    } else if (_pullDownForPrevious) {
        _pullDownForPrevious = NO;
        [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [webView.scrollView setContentOffset:CGPointMake(0.0, maxOffset) animated:NO];
            webView.scrollView.alpha = 1.0;
        } completion:NULL];
    } else {
        // clear the decelerating by animate to scroll to the same position.
        [webView.scrollView setContentOffset:webView.scrollView.contentOffset animated:YES];
    }
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

#pragma mark PullToActionDelegate

- (void)scrollViewDidEndDraggingOutsideTopBoundWithOffset:(CGFloat)offset {
    if (offset < TOP_OFFSET && _finishFirstLoading && self.currentPage != 1) {
        CGPoint currentContentOffset = self.webView.scrollView.contentOffset;
        currentContentOffset.y = -CGRectGetHeight(self.webView.bounds);

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                [self.webView.scrollView setContentOffset:currentContentOffset animated:NO];
                self.webView.scrollView.alpha = 0.0;
            } completion:^(BOOL finished) {
                self->_pullDownForPrevious = YES;
                [self back:nil];
            }];
        });
    }
}

- (void)scrollViewDidEndDraggingOutsideBottomBoundWithOffset:(CGFloat)offset {
    if (offset > BOTTOM_OFFSET && _finishFirstLoading) {
        if (self.currentPage >= self.totalPages) {
            [self forward:nil];
            return;
        }

        CGPoint currentContentOffset = self.webView.scrollView.contentOffset;
        currentContentOffset.y = self.webView.scrollView.contentSize.height;

        // DIRTYHACK: delay 0.01 second to avoid animation to overrided by other animation setted by iOS
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                [self.webView.scrollView setContentOffset:currentContentOffset animated:NO];
                self.webView.scrollView.alpha = 0.0;
            } completion:^(BOOL finished) {
                self->_pullUpForNext = YES;
                [self forward:nil];
            }];
        });
    }
}

- (void)scrollViewContentSizeDidChange:(CGSize)contentSize {
    [self updateDecorationLines:contentSize];
}

- (void)scrollViewContentOffsetProgress:(NSDictionary * __nonnull)progress {
    // When page not finish loading, no animation should be presented.
    if (!_finishFirstLoading) {
        if (self.currentPage >= self.totalPages) {
            [self.forwardButton setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
        }
        self.forwardButton.imageView.layer.transform = CATransform3DIdentity;
        self.backButton.imageView.layer.transform = CATransform3DIdentity;
        return;
    }
    // Process for bottom offset
    double bottomProgress = [progress[@"bottom"] doubleValue];
    if (self.currentPage >= self.totalPages) {
        if (bottomProgress >= 0) {
            [self.forwardButton setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
            self.forwardButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2 * bottomProgress, 0, 0, 1);
        } else {
            [self.forwardButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
            self.forwardButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2, 0, 0, 1);
        }
    } else {
        bottomProgress = fmax(fmin(bottomProgress, 1.0f), 0.0f);
        self.forwardButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2 * bottomProgress, 0, 0, 1);
    }
    
    //Progress for top offset
    if (self.currentPage != 1) {
        double topProgress = [progress[@"top"] doubleValue];
        topProgress = fmax(fmin(topProgress, 1.0f), 0.0f);
        self.backButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2 * topProgress, 0, 0, 1);
    } else {
        self.backButton.imageView.layer.transform = CATransform3DIdentity;
    }
}

#pragma mark REComposeViewControllerDelegate

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result {
    NavigationControllerDelegate *navigationDelegate = self.navigationController.delegate;
    navigationDelegate.panRecognizer.enabled = YES;
    self.attributedReplyDraft = [composeViewController.textView.attributedText mutableCopy];
    if (result == REComposeResultCancelled) {
        [composeViewController dismissViewControllerAnimated:YES completion:NULL];
    } else if (result == REComposeResultPosted) {
        if (composeViewController.plainText.length > 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [[MTStatusBarOverlay sharedInstance] postMessage:@"回复发送中" animated:YES];
            __weak __typeof__(self) weakSelf = self;
            void (^successBlock)() = ^{
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                __strong __typeof__(self) strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }

                strongSelf.attributedReplyDraft = nil;
                if (strongSelf.currentPage == strongSelf.totalPages) {
                    strongSelf->_needToScrollToBottom = YES;
                    [strongSelf fetchContentForPage:strongSelf.currentPage forceUpdate:YES];
                }
            };
            void (^failureBlock)() = ^(NSError *error) {
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                if (error.code == NSURLErrorCancelled) {
                    DDLogDebug(@"[Network] NSURLErrorCancelled");
                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
                } else {
                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复失败" duration:2.5 animated:YES];
                }
            };

            if (self.replyTopicFloor) {
                [self.dataCenter replySpecificFloor:self.replyTopicFloor inTopic:self.topic atPage:[NSNumber numberWithUnsignedInteger:self.currentPage] withText:composeViewController.plainText success: successBlock failure:failureBlock];
            } else {
                [self.dataCenter replyTopic:self.topic withText:composeViewController.plainText success:successBlock failure:failureBlock];
            }
            [composeViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - Networking

- (void)fetchContentForPage:(NSUInteger)page forceUpdate:(BOOL)forceUpdate {
    [self updateToolBar];

    self.userActivity.needsSave = YES;
   
    //remove cache for last page
    if (forceUpdate) {
        [self.dataCenter removePrecachedFloorsForTopic:self.topic withPage:[NSNumber numberWithUnsignedInteger:page]];
    }
    //Set up HUD
    DDLogDebug(@"[ContentVC] check precache exist");

    if (![self.dataCenter hasPrecacheFloorsForTopic:self.topic withPage:[NSNumber numberWithUnsignedInteger:page]]) {
        DDLogDebug(@"[ContentVC] Show HUD");
        [self.refreshHUD showActivityIndicator];

        __weak __typeof__(self) weakSelf = self;
        [self.refreshHUD setRefreshEventHandler:^(S1HUD *aHUD) {
            __strong __typeof__(self) strongSelf = weakSelf;
            if (strongSelf != nil) {
                [aHUD hideWithDelay:0.0];
                [strongSelf fetchContentForPage:strongSelf.currentPage forceUpdate:NO];
            }
        }];
    }

    __weak __typeof__(self) weakSelf = self;
    [self.viewModel contentPageForTopic:self.topic page:page success:^(NSString *contents, NSNumber *shouldRefetch) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        if (strongSelf->_currentPage != page) { // TODO: check this.
            return;
        }

        [strongSelf updateToolBar];
        [strongSelf updateTitleLabelWithTitle:strongSelf.topic.title];

        if (_shouldRestoreViewPosition) {
            [strongSelf saveViewPosition];
            _shouldRestoreViewPosition = NO;
        }

        _finishFirstLoading = YES;

        [strongSelf.webView loadHTMLString:contents baseURL:[S1ContentViewModel baseURL]];

        // Prepare next page
        if (_currentPage < self.totalPages) {
            NSNumber *cachePage = [NSNumber numberWithUnsignedInteger:_currentPage + 1];
            [strongSelf.dataCenter setFinishHandlerForTopic:strongSelf.topic withPage:cachePage andHandler:^(NSArray *floorList) {
                __strong __typeof__(self) strongSelf = weakSelf;
                [strongSelf updateToolBar];
            }];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PrecacheNextPage"]) {
                [strongSelf.dataCenter precacheFloorsForTopic:strongSelf.topic withPage:cachePage shouldUpdate:NO];
            }
        }
        // Dismiss HUD if exist
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf hideHUDIfNoMessageToShow];
        });

        // Auto refresh when current page not full.
        if (shouldRefetch != nil && _currentPage < self.totalPages && [shouldRefetch boolValue]) {
            _shouldRestoreViewPosition = YES;
            [strongSelf fetchContentForPage:_currentPage forceUpdate:YES];
        }
        
    } failure:^(NSError *error) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if (error.code == NSURLErrorCancelled) {
            DDLogDebug(@"request cancelled.");
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

- (void)hideHUDIfNoMessageToShow {
    if (self.topic.message == nil || [self.topic.message isEqualToString:@""]) {
        [self.refreshHUD hideWithDelay:0.3];
    } else {
        [self.refreshHUD showMessage:self.topic.message];
    }
}

- (void)cancelRequest {
    [self.dataCenter cancelRequest];
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
    if (size.width <= 321.0) {
        favoriteItem.customView.bounds = CGRectZero;
        favoriteItem.customView.hidden = YES;
        fixItem2.width = 0.0;
    } else {
        favoriteItem.customView.bounds = CGRectMake(0, 0, 30, 40);
        favoriteItem.customView.hidden = NO;
        fixItem2.width = 48.0;
    }
    self.toolBar.items = items;
}

#pragma mark - Reply

- (void)presentReplyViewToFloor: (S1Floor *)topicFloor {
    // Check in login state.
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"]) {
        S1LoginViewController *loginViewController = [[S1LoginViewController alloc] initWithNibName:nil bundle:nil];
        [self presentViewController:loginViewController animated:YES completion:NULL];
        return;
    }

    if (self.topic.fID == nil || self.topic.formhash == nil) {
        [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"缺少必要信息（请尝试刷新当前页）" duration:2.5 animated:YES];
        return;
    }

    REComposeViewController *replyController = [[REComposeViewController alloc] initWithNibName:nil bundle:nil];
    replyController.textView.keyboardAppearance = [[APColorManager sharedInstance] isDarkTheme] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
    replyController.sheetBackgroundColor = [[APColorManager sharedInstance] colorForKey:@"reply.background"];
    replyController.textView.tintColor = [[APColorManager sharedInstance] colorForKey:@"reply.tint"];
    replyController.textView.textColor = [[APColorManager sharedInstance] colorForKey:@"reply.text"];

    // Set title
    replyController.title = NSLocalizedString(@"ContentView_Reply_Title", @"Reply");
    if (topicFloor) {
        replyController.title = [@"@" stringByAppendingString:topicFloor.author];
        self.replyTopicFloor = topicFloor;
    } else {
        self.replyTopicFloor = nil;
    }

    if (self.attributedReplyDraft != nil) {
        [replyController.textView setAttributedText:self.attributedReplyDraft];
    }

    replyController.delegate = self;
    replyController.accessoryView = [[ReplyAccessoryView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(replyController.view.bounds), 35) withComposeViewController:replyController];
    [ReplyAccessoryView resetTextViewStyle:replyController.textView];

    [self presentViewController:replyController animated:YES completion:NULL];

    NavigationControllerDelegate *navigationDelegate = self.navigationController.delegate;
    navigationDelegate.panRecognizer.enabled = NO;
}

#pragma mark - Notificatons

- (void)saveTopicViewedState:(id)sender {
    DDLogDebug(@"[ContentVC] Save Topic View State Begin.");
    if (_finishFirstLoading) {
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: (float)self.webView.scrollView.contentOffset.y]];
    } else if ((self.topic.lastViewedPosition == nil) || (![self.topic.lastViewedPage isEqualToNumber:[NSNumber numberWithInteger: _currentPage]])) {
        // If last viewed page in record doesn't equal current page it means user has changed page since this view controller is loaded.
        // Then the unfinish loaded new page's last view position should be 0.
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: (float)0.0]];
    }
    [self.topic setLastViewedPage:[NSNumber numberWithInteger: _currentPage]];
    self.topic.lastViewedDate = [NSDate date];
    [self.topic setLastReplyCount:self.topic.replyCount];
    [self.dataCenter hasViewed:self.topic];
    DDLogInfo(@"[ContentVC] Save Topic View State Finish.");
}

- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
    self.view.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.background"];
    self.webView.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];

    self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    if (self.topic.title == nil || [self.topic.title isEqualToString:@""]) {
        self.titleLabel.text = [NSString stringWithFormat: @"%@ 载入中...", self.topic.topicID];
        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.disable"];
    } else {
        self.titleLabel.text = self.topic.title;
        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
    }
    [self.pageButton setTitleColor:[[APColorManager sharedInstance] colorForKey:@"content.pagebutton.text"] forState:UIControlStateNormal];
    self.toolBar.barTintColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.bartint"];
    self.toolBar.tintColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.tint"];

    [self setNeedsStatusBarAppearanceUpdate];

    _needToLoadLastPositionFromModel = NO;
    [self saveViewPosition];
    [self fetchContentForPage:_currentPage forceUpdate:NO];
}

#pragma mark - Helpers

- (void)scrollToBottomAnimated:(BOOL)animated {
    [self.webView.scrollView setContentOffset:CGPointMake(0, self.webView.scrollView.contentSize.height - self.webView.scrollView.bounds.size.height) animated:animated];
}

- (void)updateToolBar {
    [self updatePageLabel];
    [self updateForwardButton];
    [self updateBackwardButton];
}

- (void)updatePageLabel {
    if (self.topic.totalPageCount != nil) {
        self.totalPages = [self.topic.totalPageCount integerValue];
    }
    [self.pageButton setTitle:[self pageButtonString] forState:UIControlStateNormal];
}

- (void)updateForwardButton {
    [self.forwardButton setImage:[self.viewModel forwardButtonImageWithTopic:self.topic currentPage:self.currentPage] forState:UIControlStateNormal];
}

- (void)updateBackwardButton {
    [self.forwardButton setImage:[self.viewModel backwardButtonImageWithTopic:self.topic currentPage:self.currentPage] forState:UIControlStateNormal];
}

- (NSString *)pageButtonString {
    return [NSString stringWithFormat:@"%ld/%ld", (long)_currentPage, _currentPage > self.totalPages ? (long)_currentPage : (long)self.totalPages];
}

- (void)updateTitleLabelWithTitle:(NSString *)title {
    self.titleLabel.text = title;
    self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
}

- (void)updateDecorationLines:(CGSize)contentSize {
    self.topDecorateLine.frame = CGRectMake(0, TOP_OFFSET, contentSize.width, 1);
    self.bottomDecorateLine.frame = CGRectMake(0, contentSize.height + BOTTOM_OFFSET, contentSize.width, 1);
    self.topDecorateLine.hidden = !(_currentPage != 1 && _finishFirstLoading);
    self.bottomDecorateLine.hidden = !_finishFirstLoading;
}

- (CGRect)positionOfElementWithId:(NSString *)elementID {
    NSString *js = @"function f(){ var r = document.getElementById('%@').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();";
    NSString *result = [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:js, elementID]];
    CGRect rect = CGRectFromString(result);
    return rect;
}

- (void)saveViewPosition {
    if (self.webView.scrollView.contentOffset.y != 0) {
        [self.cachedViewPosition setObject:[NSNumber numberWithDouble:self.webView.scrollView.contentOffset.y] forKey:[NSNumber numberWithInteger:_currentPage]];
    }
}

- (BOOL)shouldPresentingFavoriteButtonOnToolBar {
    return CGRectGetWidth(self.view.bounds) > 321.0;
}

#pragma mark - Restore Position

- (void)preChangeCurrentPage {
    [self cancelRequest];
    [self saveViewPosition];
    _needToLoadLastPositionFromModel = NO;
}

- (void)preLoadNextPage {

}

- (void)didFinishBasicPageLoad {

}
    
- (void)didFinishFullPageLoad {
        
}

#pragma mark - UIUserActivity

- (void)updateUserActivityState:(NSUserActivity *)activity {
    DDLogDebug(@"[ContentVC] Hand Off Activity Updated");
    activity.userInfo = @{@"topicID": self.topic.topicID,
                          @"page": [NSNumber numberWithInteger:_currentPage]};
    self.userActivity.webpageURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage]];
}

#pragma mark - Getters and Setters

- (UIButton *)backButton {
    if (_backButton == nil) {
        _backButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_backButton setImage:[UIImage imageNamed:@"Back"] forState:UIControlStateNormal];
        _backButton.frame = CGRectMake(0, 0, 40, 30);
        _backButton.imageView.clipsToBounds = NO;
        _backButton.imageView.contentMode = UIViewContentModeCenter;
        [_backButton addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *backLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backLongPressed:)];
        backLongPressGR.minimumPressDuration = 0.5;
        [_backButton addGestureRecognizer:backLongPressGR];
    }
    return _backButton;
}

- (UIButton *)forwardButton {
    if (_forwardButton == nil) {
        _forwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
        if (_currentPage == self.totalPages) {
            [_forwardButton setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
        } else {
            [_forwardButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
        }
        
        _forwardButton.frame = CGRectMake(0, 0, 40, 30);
        _forwardButton.imageView.clipsToBounds = NO;
        _forwardButton.imageView.contentMode = UIViewContentModeCenter;
        [_forwardButton addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *forwardLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardLongPressed:)];
        forwardLongPressGR.minimumPressDuration = 0.5;
        [_forwardButton addGestureRecognizer:forwardLongPressGR];
    }
    return _forwardButton;
}

- (UIButton *)pageButton {
    if (_pageButton == nil) {
        //Page Label
        _pageButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _pageButton.frame = CGRectMake(0, 0, 80, 30);
        _pageButton.titleLabel.font = [UIFont systemFontOfSize:13.0f];
        [_pageButton setTitleColor:[[APColorManager sharedInstance] colorForKey:@"content.pagebutton.text"] forState:UIControlStateNormal];
        _pageButton.backgroundColor = [UIColor clearColor];
        _pageButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        _pageButton.userInteractionEnabled = YES;
        [_pageButton addTarget:self action:@selector(pickPage:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *forceRefreshGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forceRefreshPressed:)];
        forceRefreshGR.minimumPressDuration = 0.5;
        [_pageButton addGestureRecognizer:forceRefreshGR];
    }
    return _pageButton;
}

- (UIBarButtonItem *)actionBarButtonItem {
    if (_actionBarButtonItem == nil) {
        _actionBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
    }
    return _actionBarButtonItem;
}

- (void)setTopic:(S1Topic *)topic {
    // Make mutable copy for topics from internal list.
    if ([topic isImmutable]) {
        _topic = [topic copy];
    } else {
        _topic = topic;
    }
    
    self.totalPages = ([topic.replyCount unsignedIntegerValue] / 30) + 1;
    if (topic.lastViewedPage) {
        self.currentPage = [topic.lastViewedPage unsignedIntegerValue];
    }
    if (_topic.favorite == nil) {
        _topic.favorite = @(NO);
    }
    DDLogInfo(@"[ContentVC] Topic setted: %@", self.topic.topicID);
}

@end
