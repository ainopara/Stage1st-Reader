//
//  S1ContentViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//


#import <Social/Social.h>
#import "S1ContentViewController.h"
#import "S1ContentViewModel.h"
#import "S1Topic.h"
#import "S1Floor.h"
#import "S1Parser.h"
#import "S1DataCenter.h"
#import "S1HUD.h"
#import "REComposeViewController.h"
#import "SVModalWebViewController.h"
#import "MTStatusBarOverlay.h"
#import "ActionSheetStringPicker.h"
#import "JTSSimpleImageDownloader.h"
#import "JTSImageViewController.h"
#import "S1MahjongFaceView.h"
#import "Masonry.h"
#import "NavigationControllerDelegate.h"
#import <Crashlytics/Answers.h>

#define TOP_OFFSET -80.0
#define BOTTOM_OFFSET 60.0

@interface S1ContentViewController () <UIWebViewDelegate, UIScrollViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, JTSImageViewControllerInteractionsDelegate, JTSImageViewControllerOptionsDelegate,REComposeViewControllerDelegate, S1MahjongFaceViewDelegate, PullToActionDelagete>

@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic, strong) PullToActionController *pullToActionController;

@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *forwardButton;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIBarButtonItem *actionBarButtonItem;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *topDecorateLine;
@property (nonatomic, strong) UIView *bottomDecorateLine;

@property (nonatomic, weak) JTSImageViewController *imageViewer;

@property (nonatomic, strong) NSMutableAttributedString *attributedReplyDraft;
@property (nonatomic, strong) NSMutableDictionary *cachedViewPosition;
@property (nonatomic, strong) S1ContentViewModel *viewModel;

@property (nonatomic, weak) S1Floor *replyTopicFloor;
@property (nonatomic, weak) REComposeViewController *replyController;
@property (nonatomic, strong) S1MahjongFaceView *mahjongFaceView;
@end

@implementation S1ContentViewController {
    NSInteger _currentPage;
    NSInteger _totalPages;
    
    BOOL _needToScrollToBottom;
    BOOL _needToLoadLastPosition;
    BOOL _finishLoading;
    BOOL _presentingImageViewer;
    BOOL _presentingWebViewer;
    BOOL _presentingContentViewController;
    BOOL _shouldRestoreViewPosition;
}
#pragma mark - Life Cycle

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        // Custom initialization
        _currentPage = 1;
        _needToScrollToBottom = NO;
        _needToLoadLastPosition = YES;
        _finishLoading = NO;
        _presentingImageViewer = NO;
        _presentingWebViewer = NO;
        _presentingContentViewController = NO;
        _shouldRestoreViewPosition = NO;
        _cachedViewPosition = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
//#define _STATUS_BAR_HEIGHT 20.0f
    
    [super viewDidLoad];
    CLS_LOG(@"ContentVC | View Did Load");
    self.viewModel = [[S1ContentViewModel alloc] initWithDataCenter:self.dataCenter];
    
    self.view.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.background"];
    
    //web view
    self.webView.delegate = self;
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    [self.webView.scrollView.panGestureRecognizer requireGestureRecognizerToFail:[(NavigationControllerDelegate *)self.navigationController.delegate colorPanRecognizer]];
    self.webView.opaque = NO;
    self.webView.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];
    
    self.pullToActionController = [[PullToActionController alloc] initWithScrollView:self.webView.scrollView];
    [self.pullToActionController addConfigurationWithName:@"top" baseLine:OffsetBaseLineTop beginPosition:0.0 endPosition:TOP_OFFSET];
    [self.pullToActionController addConfigurationWithName:@"bottom" baseLine:OffsetBaseLineBottom beginPosition:0.0 endPosition:BOTTOM_OFFSET];
    self.pullToActionController.delegate = self;
    
    self.topDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, TOP_OFFSET, self.view.bounds.size.width, 1)];
    if(_currentPage != 1) {
        self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    }
    
    [self.webView.scrollView addSubview:self.topDecorateLine];
    self.bottomDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, TOP_OFFSET, self.view.bounds.size.width, 1)]; // will be updated soon in delegate.
    self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    [self.webView.scrollView addSubview:self.bottomDecorateLine];
    //title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, -64, self.view.bounds.size.width - 24, 64)];
    
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
        make.centerX.equalTo(self.view.mas_centerX);
        make.height.equalTo(@64);
        make.width.equalTo(self.view.mas_width).with.offset(-24);
    }];

    UIButton *button = nil;
    
    //Backward Button

    button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage imageNamed:@"Back"] forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 40, 30);
    button.imageView.clipsToBounds = NO;
    button.imageView.contentMode = UIViewContentModeCenter;
    [button addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    [button setTag:99];
    UILongPressGestureRecognizer *backLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backLongPressed:)];
    backLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:backLongPressGR];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:button];    
    self.backButton = button;
    
    
    //Forward Button
    button = [UIButton buttonWithType:UIButtonTypeSystem];
    if (_currentPage == _totalPages) {
        [button setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
    } else {
        [button setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
    }
    
    button.frame = CGRectMake(0, 0, 40, 30);
    button.imageView.clipsToBounds = NO;
    button.imageView.contentMode = UIViewContentModeCenter;
    [button addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
    [button setTag:100];
    UILongPressGestureRecognizer *forwardLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardLongPressed:)];
    forwardLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:forwardLongPressGR];
    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.forwardButton = button;
    
    //Page Label
    self.pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
    self.pageLabel.font = [UIFont systemFontOfSize:13.0f];
    self.pageLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.pagelabel.text"];
    self.pageLabel.backgroundColor = [UIColor clearColor];
    self.pageLabel.textAlignment = NSTextAlignmentCenter;
    self.pageLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *pickPageGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickPage:)];
    [self.pageLabel addGestureRecognizer:pickPageGR];
    UILongPressGestureRecognizer *forceRefreshGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forceRefreshPressed:)];
    forceRefreshGR.minimumPressDuration = 0.5;
    [self.pageLabel addGestureRecognizer:forceRefreshGR];
    
    //disable this function for now
    //UIPanGestureRecognizer *panGR =[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panPageLabel:)];
    //[self.pageLabel addGestureRecognizer:panGR];
    [self updatePageLabel];
    
    UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithCustomView:self.pageLabel];
    labelItem.width = 80;
    
    
    self.actionBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 26.0f;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.toolBar setItems:@[backItem, fixItem, forwardItem, flexItem, labelItem, flexItem, self.actionBarButtonItem]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTopicViewedState:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePaletteChangeNotification:) name:@"S1PaletteDidChangeNotification" object:nil];
    
    //Set up Activity for Hand Off

    NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"Stage1st.view-topic"];
    activity.title = self.topic.title;
    activity.userInfo = @{@"topicID": self.topic.topicID,
                          @"page": [NSNumber numberWithInteger:_currentPage]};
    activity.webpageURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage]];
    //iOS 9 Search api
    if (!SYSTEM_VERSION_LESS_THAN(@"9")) {
        activity.eligibleForSearch = YES;
        activity.requiredUserInfoKeys = [NSSet setWithObjects:@"topicID", nil];
    }
    self.userActivity = activity;

    
    
    [self fetchContentAndForceUpdate:_currentPage == _totalPages];
}

- (void)viewWillAppear:(BOOL)animated {
    _presentingImageViewer = NO;
    _presentingWebViewer = NO;
    
    [UIApplication sharedApplication].statusBarHidden = NO;
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _presentingContentViewController = NO;
    [CrashlyticsKit setObjectValue:@"ContentViewController" forKey:@"lastViewController"];
    CLS_LOG(@"ContentVC | View Did Appear");
    
}

- (void)viewDidDisappear:(BOOL)animated {
    if (_presentingImageViewer || _presentingWebViewer || _presentingContentViewController) {
        return;
    }
    //NSLog(@"Content View did disappear");
    [self cancelRequest];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self saveTopicViewedState:nil];
        self.topic.floors = [[NSMutableDictionary alloc] init]; //clear cache floors to reduce memory useage
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotification *notification = [NSNotification notificationWithName:@"S1ContentViewWillDisappearNotification" object:nil];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        });
    });
    
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    CLS_LOG(@"ContentVC | Deallocing");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // TempFix: Try to resolve crash issue in UIKit, not sure if this will work.
    self.pullToActionController.delegate = nil;
    self.pullToActionController = nil;
    CLS_LOG(@"ContentVC | Pull Controller set nil");
    self.webView.delegate = nil;
    self.webView.scrollView.delegate = nil;
    [self.webView stopLoading];
    CLS_LOG(@"ContentVC | Dealloced");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - TabBar Actions

- (void)back:(id)sender
{
    [self cancelRequest];
    _needToLoadLastPosition = NO;
    [self saveViewPosition];
    if (_currentPage - 1 >= 1) {
        _currentPage -= 1;
        [self fetchContent];
    } else {
        [[self navigationController] popViewControllerAnimated:YES];
    }
}

- (void)forward:(id)sender
{
    [self cancelRequest];
    _needToLoadLastPosition = NO;
    [self saveViewPosition];
    if (_currentPage + 1 <= _totalPages) {
        _currentPage += 1;
        [self fetchContent];
    } else {
        if (![self atBottom]) {
            [self scrollToBottomAnimated:YES];
        } else {
            //_needToScrollToBottom = YES;
            [self fetchContentAndForceUpdate:YES];
        }
    }
}

- (void)backLongPressed:(UIGestureRecognizer *)gr
{
    if (gr.state == UIGestureRecognizerStateBegan) {
        [self saveViewPosition];
        if (_currentPage > 1) {
            _currentPage = 1;
            [self cancelRequest];
            _needToLoadLastPosition = NO;
            [self fetchContent];
        }
    }
}

- (void)forwardLongPressed:(UIGestureRecognizer *)gr
{
    if (gr.state == UIGestureRecognizerStateBegan) {
        [self saveViewPosition];
        if (_currentPage < _totalPages) {
            _currentPage = _totalPages;
            [self cancelRequest];
            _needToLoadLastPosition = NO;
            [self fetchContent];
        }
    }
}

- (void)pickPage:(id)sender
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (long i = 0; i < (_currentPage > _totalPages ? _currentPage : _totalPages); i++) {
        if ([self.dataCenter hasPrecacheFloorsForTopic:self.topic withPage:[NSNumber numberWithLong:i + 1]]) {
            [array addObject:[NSString stringWithFormat:@"✓第 %ld 页✓", i + 1]];
        } else {
            [array addObject:[NSString stringWithFormat:@"第 %ld 页", i + 1]];
        }
    }
    ActionSheetStringPicker *picker = [[ActionSheetStringPicker alloc] initWithTitle:@""
                                            rows:array
                                initialSelection:_currentPage - 1
                                       doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                                           [self saveViewPosition];
                                           
                                           [self cancelRequest];
                                           _needToLoadLastPosition = NO;
                                           if (_currentPage != selectedIndex + 1) {
                                               _currentPage = selectedIndex + 1;
                                               [self fetchContent];
                                           } else {
                                               [self fetchContentAndForceUpdate:YES];
                                           }
                                           
                                       }
                                     cancelBlock:nil
                                          origin:self.pageLabel];
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
        NSLog(@"forceRefresh pressed");
        [self cancelRequest];
        _needToLoadLastPosition = NO;
        [self saveViewPosition];
        [self fetchContentAndForceUpdate:YES];
    }
    
}
- (void)panPageLabel:(UIPanGestureRecognizer *)gr {
    
    CGFloat distance = [gr translationInView:self.view].x;
    NSInteger offset = distance / 50.0;
    NSInteger destinationPage = _currentPage + offset;
    while (destinationPage <= 0) {
        destinationPage += _totalPages;
    }
    while (destinationPage > _totalPages) {
        destinationPage -= _totalPages;
    }
    //NSLog(@"%f %ld", distance, (long)offset);
    if (gr.state == UIGestureRecognizerStateBegan || gr.state == UIGestureRecognizerStateChanged) {
        self.pageLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)destinationPage, (long)_totalPages];
    } else if (gr.state == UIGestureRecognizerStateEnded) {
        NSLog(@"open %ld", (long)destinationPage);
        if (_currentPage != destinationPage) {
            [self saveViewPosition];
            _currentPage = destinationPage;
            [self cancelRequest];
            _needToLoadLastPosition = NO;
            [self fetchContent];
        }
    } else {
        NSLog(@"unexpected state:%ld", (long)gr.state);
        [self updatePageLabel];
    }
    
    
}
- (void)action:(id)sender
{

    UIAlertController *moreActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    // Reply Action
    UIAlertAction *replyAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Reply", @"Reply") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self presentReplyViewWithAppendText:@"" reply:nil];
    }];
    // Favorite Action
    UIAlertAction *favoriteAction = [UIAlertAction actionWithTitle:[self.topic.favorite boolValue]?NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.topic.favorite = [NSNumber numberWithBool:![self.topic.favorite boolValue]];
        if ([self.topic.favorite boolValue]) {
            self.topic.favoriteDate = [NSDate date];
        }
        S1HUD *HUD = [S1HUD showHUDInView:self.view];
        [HUD setText:[self.topic.favorite boolValue] ? NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") : NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite") withWidthMultiplier:2];
        [HUD hideWithDelay:0.3];
    }];
    // Share Action
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Share", @"Share") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.topic.title], [NSURL URLWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage]], [self screenShot]] applicationActivities:nil];
        if ([activityController respondsToSelector:@selector(popoverPresentationController)]) {
            [activityController.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
        }
        [self presentViewController:activityController animated:YES completion:nil];
        [activityController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            NSLog(@"finish:%@",activityType);
        }];
    }];
    // Copy Link
    UIAlertAction *copyLinkAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
        S1HUD *HUD = [S1HUD showHUDInView:self.view];
        [HUD setText:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link") withWidthMultiplier:2];
        [HUD hideWithDelay:0.3];
    }];
    // Origin Page Action
    UIAlertAction *originPageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_OriginPage", @"Origin") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
        _presentingWebViewer = YES;
        [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
        SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:pageAddress];
        [controller.view setTintColor:[[APColorManager sharedInstance] colorForKey:@"content.tint"]];
        [self presentViewController:controller animated:YES completion:nil];
    }];
    // Cancel Action
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
    
    [moreActionSheet addAction:replyAction];
    [moreActionSheet addAction:favoriteAction];
    [moreActionSheet addAction:shareAction];
    [moreActionSheet addAction:copyLinkAction];
    [moreActionSheet addAction:originPageAction];
    [moreActionSheet addAction:cancelAction];
    [moreActionSheet.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
    [self presentViewController:moreActionSheet animated:YES completion:nil];

    
}
#pragma mark Accessory View
- (void)toggleFace:(id)sender {
    NSLog(@"toggleFace");
    if (self.replyController.inputView == nil) {
        if (self.mahjongFaceView == nil) {
            self.mahjongFaceView = [[S1MahjongFaceView alloc] init];
            //[self.mahjongController.view setFrame:CGRectMake(0, 0, 320, 217)];
            //[self.view addSubview:self.mahjongController.view];
            self.mahjongFaceView.delegate = self;
            self.mahjongFaceView.historyCountLimit = 99;
        }
        [(UIButton *)sender setImage:[UIImage imageNamed:@"KeyboardButton"] forState:UIControlStateNormal];
        self.replyController.inputView = self.mahjongFaceView;
        [self.replyController reloadInputViews];
    } else {
        [(UIButton *)sender setImage:[UIImage imageNamed:@"MahjongFaceButton"] forState:UIControlStateNormal];
        self.replyController.inputView = nil;
        [self.replyController reloadInputViews];
    }
}

- (void)insertSpoilerMark:(id)sender {
    [self insertMarkWithAPart:@"[color=LemonChiffon]" andBPart:@"[/color]"];
}

- (void)insertQuoteMark:(id)sender {
    [self insertMarkWithAPart:@"[quote]" andBPart:@"[/quote]"];
}

- (void)insertBoldMark:(id)sender {
    [self insertMarkWithAPart:@"[b]" andBPart:@"[/b]"];
}
- (void)insertMarkWithAPart:(NSString *)aPart andBPart:(NSString *)bPart {
    NSLog(@"insert %@ %@ %lu", aPart, bPart, (unsigned long)[aPart length]);
    if (self.replyController.textView != nil) {
        NSRange selectRange = self.replyController.textView.selectedRange;
        NSUInteger aPartLenght = [aPart length];
        if (selectRange.length == 0) {
            NSString *wholeMark = [aPart stringByAppendingString:bPart];
            [self.replyController.textView.textStorage insertAttributedString:[[NSAttributedString alloc] initWithString:wholeMark] atIndex:selectRange.location];
            self.replyController.textView.selectedRange = NSMakeRange(selectRange.location + aPartLenght, selectRange.length);
        } else {
            [self.replyController.textView.textStorage insertAttributedString:[[NSAttributedString alloc] initWithString:bPart] atIndex:selectRange.location + selectRange.length];
            [self.replyController.textView.textStorage insertAttributedString:[[NSAttributedString alloc] initWithString:aPart] atIndex:selectRange.location];
            self.replyController.textView.selectedRange = NSMakeRange(selectRange.location + aPartLenght, selectRange.length);
        }
        
        [self resetTextViewStyle:self.replyController.textView];
    }
}

#pragma mark UIWebView


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // Load
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        return YES;
    }
    
    if ([request.URL.absoluteString hasPrefix:@"applewebdata://"]) {
        // Reply
        if ([request.URL.path isEqualToString:@"/reply"]) {
            NSString *decodedQuery = [request.URL.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            S1Floor *floor = [self.topic.floors valueForKey:decodedQuery];
            if (floor != nil) {
                NSLog(@"%@", floor.author);
                [self presentReplyViewWithAppendText:@"" reply:floor];
            }
        // Present image
        } else if ([request.URL.path hasPrefix:@"/present-image:"]) {
            _presentingImageViewer = YES;
            [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
            NSString *imageID = request.URL.fragment;
            NSString *imageURL = [request.URL.path stringByReplacingCharactersInRange:NSRangeFromString(@"0 15") withString:@""];
            NSLog(@"%@", imageURL);
            JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
            imageInfo.imageURL = [[NSURL alloc] initWithString:imageURL];
            imageInfo.referenceRect = [self positionOfElementWithId:imageID];
            imageInfo.referenceView = self.webView;
            JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                                   initWithImageInfo:imageInfo
                                                   mode:JTSImageViewControllerMode_Image
                                                   backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
            [UIApplication sharedApplication].statusBarHidden = YES;
            [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
            [imageViewer setInteractionsDelegate:self];
            [imageViewer setOptionsDelegate:self];
        }
        return NO;
    }
    //Image URL opened in image Viewer
    if ([request.URL.path hasSuffix:@".jpg"] || [request.URL.path hasSuffix:@".gif"]) {
        _presentingImageViewer = YES;
        [CrashlyticsKit setObjectValue:@"ImageViewController" forKey:@"lastViewController"];
        NSString *imageURL = request.URL.absoluteString;
        NSLog(@"%@", imageURL);
        JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
        imageInfo.imageURL = request.URL;
        JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                               initWithImageInfo:imageInfo
                                               mode:JTSImageViewControllerMode_Image
                                               backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
        [UIApplication sharedApplication].statusBarHidden = YES;
        [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOffscreen];
        [imageViewer setInteractionsDelegate:self];
        return NO;
    }
    
    // Open S1 topic
    if ([request.URL.absoluteString hasPrefix:[[NSUserDefaults standardUserDefaults] stringForKey:@"BaseURL"]]) {
        S1Topic *topic = [S1Parser extractTopicInfoFromLink:request.URL.absoluteString];
        if (topic.topicID != nil) {
            S1Topic *tracedTopic = [self.dataCenter tracedTopic:topic.topicID];
            if (tracedTopic != nil) {
                NSNumber *lastViewedPage = topic.lastViewedPage;
                topic = [tracedTopic copy];
                topic.lastViewedPage = lastViewedPage;
            }
            _presentingContentViewController = YES;
            S1ContentViewController *contentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"Content"];
            [contentViewController setTopic:topic];
            [contentViewController setDataCenter:self.dataCenter];
            [[self navigationController] pushViewController:contentViewController animated:YES];
            return NO;
        }
        // Open Quote Link
        NSDictionary *quarys = [S1Parser extractQuerysFromURLString:request.URL.absoluteString];
        if (quarys) {
            NSLog(@"%@",quarys);
            if ([[quarys valueForKey:@"mod"] isEqualToString:@"redirect"]) {
                /*
                [self.dataCenter findTopicFloor:[NSNumber numberWithInteger:[[quarys valueForKey:@"pid"] integerValue]] inTopicID:[NSNumber numberWithInteger:[[quarys valueForKey:@"ptid"] integerValue]] success:^{
                    NSLog(@"finish");
                } failure:^(NSError *error) {
                    NSLog(@"%@",error);
                }];*/
                if ([[quarys valueForKey:@"ptid"] integerValue] == [self.topic.topicID integerValue]) {
                    NSInteger tid = [[quarys valueForKey:@"ptid"] integerValue];
                    NSInteger pid = [[quarys valueForKey:@"pid"] integerValue];
                    if (tid == [self.topic.topicID integerValue]) {
                        NSArray *chainQuoteFloors = [self chainSearchQuoteByFirstFloorID:@(pid)];
                        if ([chainQuoteFloors count] > 0) {
                            _presentingContentViewController = YES;
                            S1Topic *quoteTopic = [self.topic copy];
                            NSString *htmlString = [S1Parser generateQuotePage:chainQuoteFloors withTopic:quoteTopic];
                            S1QuoteFloorViewController *quoteFloorViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"QuoteFloor"];
                            quoteFloorViewController.topic = quoteTopic;
                            quoteFloorViewController.floors = chainQuoteFloors;
                            quoteFloorViewController.htmlString = htmlString;
                            quoteFloorViewController.centerFloorID = [[[chainQuoteFloors lastObject] floorID] integerValue];
                            [[self navigationController] pushViewController:quoteFloorViewController animated:YES];
                            return NO;
                        }
                        
                    }
                }
            }
            
        }
    }
    
    // Open link

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString preferredStyle:UIAlertControllerStyleAlert];
    if (SYSTEM_VERSION_LESS_THAN(@"9")) {
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        UIAlertAction* continueAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            _presentingWebViewer = YES;
            [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
            NSLog(@"%@", request.URL);
            SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:request.URL.absoluteString];
            [[controller view] setTintColor:[[APColorManager sharedInstance] colorForKey:@"content.tint"]];
            //[self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:controller animated:YES completion:nil];
        }];
        [alert addAction:cancelAction];
        [alert addAction:continueAction];
    } else {
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        UIAlertAction* continueAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            _presentingWebViewer = YES;
            [CrashlyticsKit setObjectValue:@"WebViewer" forKey:@"lastViewController"];
            NSLog(@"%@", request.URL);
            if (![[UIApplication sharedApplication] openURL:request.URL]) {
                NSLog(@"%@%@",@"Failed to open url:",[request.URL description]);
            }
        }];
        [alert addAction:cancelAction];
        [alert addAction:continueAction];
    }
    
    [self presentViewController:alert animated:YES completion:nil];

    return NO;
}



- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    CGFloat maxOffset = self.webView.scrollView.contentSize.height - self.webView.scrollView.bounds.size.height;
    // Restore last view position when this content view first be loaded.
    if (_needToLoadLastPosition) {
        if (self.topic.lastViewedPosition != 0) {
            [self.webView.scrollView setContentOffset:CGPointMake(self.webView.scrollView.contentOffset.x, fmax(fmin(maxOffset, [self.topic.lastViewedPosition doubleValue]), 0.0))];
        }
        _needToLoadLastPosition = NO;
    }

    // Restore last view position from cached position in this view controller.
    NSNumber *positionForPage = [self.cachedViewPosition objectForKey:[NSNumber numberWithInteger:_currentPage]];
    if (positionForPage) {
        [self.webView.scrollView setContentOffset:CGPointMake(self.webView.scrollView.contentOffset.x, fmax(fmin(maxOffset, [positionForPage doubleValue]), 0.0))];
    }
    
    // User want to scroll to bottom.
    if (_needToScrollToBottom) {
        _needToScrollToBottom = NO;
        [self scrollToBottomAnimated:YES];
    } else {
        // clear the decelerating by animate to scroll to the same position.
        [self.webView.scrollView setContentOffset:self.webView.scrollView.contentOffset animated:YES];
    }
}

#pragma mark JTSImageViewController
- (void)imageViewerDidLongPress:(JTSImageViewController *)imageViewer atRect:(CGRect)rect {
    self.imageViewer = imageViewer;
    UIAlertController *imageActionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) myself = self;
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ImageViewer_ActionSheet_Save", @"Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(self) strongMyself = myself;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImageWriteToSavedPhotosAlbum(strongMyself.imageViewer.image, nil, nil, nil);
        });
    }];
    UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ImageViewer_ActionSheet_CopyURL", @"Copy URL") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.imageViewer.imageInfo.imageURL.absoluteString;
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
    [imageActionSheet addAction:saveAction];
    [imageActionSheet addAction:copyURLAction];
    [imageActionSheet addAction:cancelAction];
    [imageActionSheet.popoverPresentationController setSourceView:imageViewer.view];
    [imageActionSheet.popoverPresentationController setSourceRect:rect];
    [imageViewer presentViewController:imageActionSheet animated:YES completion:nil];
    
}

- (CGFloat)alphaForBackgroundDimmingOverlayInImageViewer:(JTSImageViewController *)imageViewer {
    return 0.3;
}

#pragma mark Mahjong Face

- (void)mahjongFaceViewController:(S1MahjongFaceView *)mahjongFaceView didFinishWithResult:(S1MahjongFaceTextAttachment *)attachment {
    UITextView *textView = self.replyController.textView;
    if (textView) {
        [textView.textStorage insertAttributedString:[NSAttributedString attributedStringWithAttachment:attachment] atIndex:textView.selectedRange.location];
        
        //Move selection location
        textView.selectedRange = NSMakeRange(self.replyController.textView.selectedRange.location + 1, self.replyController.textView.selectedRange.length);
        
        //Reset Text Style
        [self resetTextViewStyle:textView];
    }
}

- (void)mahjongFaceViewControllerDidPressBackSpace:(S1MahjongFaceView *)mahjongFaceView {
    UITextView *textView = self.replyController.textView;
    if (textView) {
        NSRange range = textView.selectedRange;
        if (range.length == 0) {
            if (range.location > 0) {
                range.location -= 1;
                range.length = 1;
            }
        }
        textView.selectedRange = range;
        [textView.textStorage deleteCharactersInRange:textView.selectedRange];
        textView.selectedRange = NSMakeRange(self.replyController.textView.selectedRange.location, 0);
        
    }
}

- (void)saveHistoryArray:(NSMutableArray *)historyArray {
    self.dataCenter.mahjongFaceHistoryArray = historyArray;
}

- (NSMutableArray *)restoreHistoryArray {
    return self.dataCenter.mahjongFaceHistoryArray;
}

#pragma mark Pull To Action

- (void)scrollViewDidEndDraggingOutsideTopBoundWithOffset:(CGFloat)offset {
    if (offset < TOP_OFFSET && _finishLoading) {
        if (_currentPage != 1) {
            [self back:nil];
        }
    }
    
}

- (void)scrollViewDidEndDraggingOutsideBottomBoundWithOffset:(CGFloat)offset {
    if (offset > BOTTOM_OFFSET && _finishLoading) {
        [self forward:nil];
    }
}

- (void)scrollViewContentSizeDidChange:(CGSize)contentSize {
    self.topDecorateLine.frame = CGRectMake(0, TOP_OFFSET, contentSize.width - 0, 1);
    self.bottomDecorateLine.frame = CGRectMake(0, contentSize.height + BOTTOM_OFFSET, contentSize.width - 0, 1);
    if(_currentPage != 1 && _finishLoading) {
        self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    } else {
        self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];
    }
    if (_finishLoading) {
        self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    } else {
        self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];
    }
}

- (void)scrollViewContentOffsetProgress:(NSDictionary * __nonnull)progress {
    
    // When page not finish loading, no animation should be presented.
    if (!_finishLoading) {
        if (_currentPage >= _totalPages) {
            [self.forwardButton setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
        }
        self.forwardButton.imageView.layer.transform = CATransform3DIdentity;
        self.backButton.imageView.layer.transform = CATransform3DIdentity;
        return;
    }
    // Process for bottom offset
    double bottomProgress = [progress[@"bottom"] doubleValue];
    if (_currentPage >= _totalPages) {
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
    if (_currentPage != 1) {
        double topProgress = [progress[@"top"] doubleValue];
        topProgress = fmax(fmin(topProgress, 1.0f), 0.0f);
        self.backButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2 * topProgress, 0, 0, 1);
    } else {
        self.backButton.imageView.layer.transform = CATransform3DIdentity;
    }
}

#pragma mark - Networking

- (void)fetchContent {
    [self fetchContentAndForceUpdate:NO];
}

- (void)fetchContentAndForceUpdate:(BOOL)shouldUpdate
{
    [self updatePageLabel];
    __weak typeof(self) weakSelf = self;

    self.userActivity.needsSave = YES;
   
    S1HUD *HUD = nil;
    //remove cache for last page
    if (shouldUpdate) {
        [self.dataCenter removePrecachedFloorsForTopic:self.topic withPage:[NSNumber numberWithUnsignedInteger:_currentPage]];
    }
    //Set up HUD
    if (![self.dataCenter hasPrecacheFloorsForTopic:self.topic withPage:[NSNumber numberWithUnsignedInteger:_currentPage]]) {
        NSLog(@"Show HUD");
        HUD = [S1HUD showHUDInView:self.view];
        [HUD showActivityIndicator];
        [HUD setRefreshEventHandler:^(S1HUD *aHUD) {
            __strong typeof(self) strongSelf = weakSelf;
            [aHUD hideWithDelay:0.0];
            [strongSelf fetchContent];
        }];
    }
    
    [self.viewModel contentPageForTopic:self.topic withPage:_currentPage success:^(NSString *contents, NSNumber *shouldRefetch) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf updatePageLabel];
        if (_shouldRestoreViewPosition) {
            [strongSelf saveViewPosition];
            _shouldRestoreViewPosition = NO;
        }
        [strongSelf.webView loadHTMLString:contents baseURL:nil];
        [strongSelf updateTitleLabelWithTitle:strongSelf.topic.title];
        _finishLoading = YES;
        // prepare next page
        if (_currentPage < _totalPages) {
            NSNumber *cachePage = [NSNumber numberWithUnsignedInteger:_currentPage + 1];
            [strongSelf.dataCenter setFinishHandlerForTopic:strongSelf.topic withPage:cachePage andHandler:^(NSArray *floorList) {
                __strong typeof(self) strongSelf = weakSelf;
                [strongSelf updatePageLabel];
            }];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PrecacheNextPage"]) {
                [strongSelf.dataCenter precacheFloorsForTopic:strongSelf.topic withPage:cachePage shouldUpdate:NO];
            }
        }
        // dismiss hud
        if (HUD != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (strongSelf.topic.message == nil || [strongSelf.topic.message isEqualToString:@""]) {
                    [HUD hideWithDelay:0.3];
                } else {
                    [HUD setText:strongSelf.topic.message withWidthMultiplier:5];
                }
            });
        }
        // auto refresh when current page not full.
        if (shouldRefetch != nil && _currentPage < _totalPages && [shouldRefetch boolValue]) {
            _shouldRestoreViewPosition = YES;
            [strongSelf fetchContentAndForceUpdate:YES];
        }
        
    } failure:^(NSError *error) {
        if (error.code == -999) {
            NSLog(@"request cancelled.");
            if (HUD != nil) {
                [HUD hideWithDelay:0.3];
            }
        } else {
            NSLog(@"%@", error);
            if (HUD != nil) {
                [HUD showRefreshButton];
            }
        }
    }];
}

-(void) cancelRequest
{
    [self.dataCenter cancelRequest];
    
}

#pragma mark - Layout
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    CGRect frame = self.view.frame;
    frame.size = size;
    self.view.frame = frame;
}

#pragma mark - Reply
- (void)presentReplyViewWithAppendText: (NSString *)text reply: (S1Floor *)topicFloor
{
    //check in login state.
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"]) {
        [self presentAlertViewWithTitle:@"" andMessage:NSLocalizedString(@"ContentView_Reply_Need_Login_Message", @"Need Login in Settings")];
        return;
    }
    
    if (self.attributedReplyDraft) {
        if (text) {
            [self.attributedReplyDraft appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:nil]];
        }
    } else {
        if (text) {
            self.attributedReplyDraft = [[NSMutableAttributedString alloc] initWithString:text];
        }
        self.attributedReplyDraft = [[NSMutableAttributedString alloc] init];
    }
    
    REComposeViewController *replyController = [[REComposeViewController alloc] init];
    [replyController setKeyboardAppearance:[[APColorManager sharedInstance] isDarkTheme] ? UIKeyboardAppearanceDark:UIKeyboardAppearanceDefault];
    [replyController setTextViewTintColor:[[APColorManager sharedInstance] colorForKey:@"reply.tint"]];
    [replyController setTintColor:[[APColorManager sharedInstance] colorForKey:@"reply.background"]];
    [replyController.textView setTextColor:[[APColorManager sharedInstance] colorForKey:@"reply.text"]];
    self.replyController = replyController;
    [replyController.view setFrame:self.view.bounds];
    // set title
    replyController.title = NSLocalizedString(@"ContentView_Reply_Title", @"Reply");
    if (topicFloor) {
        replyController.title = [@"@" stringByAppendingString:topicFloor.author];
        self.replyTopicFloor = topicFloor;
    } else {
        self.replyTopicFloor = nil;
    }
    
    replyController.delegate = self;
    [replyController setAttributedText:self.attributedReplyDraft];
    replyController.accessoryView = [self accessoryView];
    [self resetTextViewStyle:replyController.textView];
     
    [replyController presentFromViewController:self];
    NavigationControllerDelegate *navigationDelegate = self.navigationController.delegate;
    navigationDelegate.panRecognizer.enabled = NO;
}

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result {
    NavigationControllerDelegate *navigationDelegate = self.navigationController.delegate;
    navigationDelegate.panRecognizer.enabled = YES;
    self.attributedReplyDraft = [composeViewController.attributedText mutableCopy];
    if (result == REComposeResultCancelled) {
        [composeViewController dismissViewControllerAnimated:YES completion:nil];
    } else if (result == REComposeResultPosted) {
        if (composeViewController.text.length > 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [[MTStatusBarOverlay sharedInstance] postMessage:@"回复发送中" animated:YES];
            __weak typeof(self) weakSelf = self;
            void (^successBlock)() = ^{
                __strong typeof(self) strongSelf = weakSelf;
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                strongSelf.attributedReplyDraft = nil;
                if (strongSelf->_currentPage == strongSelf->_totalPages) {
                    strongSelf->_needToScrollToBottom = YES;
                    [strongSelf fetchContentAndForceUpdate:YES];
                }
            };
            void (^failureBlock)() = ^(NSError *error) {
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                if (error.code == -999) {
                    NSLog(@"Code -999 may means user want to cancel this request.");
                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
                } else if (error.code == -998){
                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"缺少必要信息（请刷新当前页）" duration:2.5 animated:YES];
                } else {
                    [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复失败" duration:2.5 animated:YES];
                }
            };
            if (self.replyTopicFloor) {
                [self.dataCenter replySpecificFloor:self.replyTopicFloor inTopic:self.topic atPage:[NSNumber numberWithUnsignedInteger:_currentPage ] withText:composeViewController.text success: successBlock failure:failureBlock];
            } else {
                [self.dataCenter replyTopic:self.topic withText:composeViewController.text success:successBlock failure:failureBlock];
            }
            [composeViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - Notificatons

- (void)saveTopicViewedState:(id)sender {
    if (_finishLoading) {
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: (float)self.webView.scrollView.contentOffset.y]];
    } else if ((self.topic.lastViewedPosition == nil) || (![self.topic.lastViewedPage isEqualToNumber:[NSNumber numberWithInteger: _currentPage]])) {
        //if last viewed page in record doesn't equal current page it means user has changed page since this view controller is loaded. Then the unfinished new page's last view position should be 0.
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: (float)0.0]];
    }
    [self.topic setLastViewedPage:[NSNumber numberWithInteger: _currentPage]];
    self.topic.lastViewedDate = [NSDate date];
    [self.topic setLastReplyCount:self.topic.replyCount];
    [self.dataCenter hasViewed:self.topic];
}

- (void)deviceOrientationDidChange:(id)sender {
    if (self.titleLabel) {
        [self.titleLabel setFrame:CGRectMake(12, -64, self.view.bounds.size.width - 24, 64)];
    }
}

- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
    self.view.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.background"];
    self.webView.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.webview.background"];
    if(_currentPage != 1) {
        self.topDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    }
    self.bottomDecorateLine.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    if (self.topic.title == nil || [self.topic.title isEqualToString:@""]) {
        self.titleLabel.text = [NSString stringWithFormat: @"%@ 载入中...", self.topic.topicID];
        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.disable"];
    } else {
        self.titleLabel.text = self.topic.title;
        self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
    }
    self.pageLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.pagelabel.text"];
    self.toolBar.barTintColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.bartint"];
    self.toolBar.tintColor = [[APColorManager sharedInstance] colorForKey:@"appearance.toolbar.tint"];

    _needToLoadLastPosition = NO;
    [self saveViewPosition];
    [self fetchContentAndForceUpdate:NO];
}

#pragma mark - Helpers

- (void)scrollToBottomAnimated:(BOOL)animated
{
    [self.webView.scrollView setContentOffset:CGPointMake(0, self.webView.scrollView.contentSize.height-self.webView.scrollView.bounds.size.height) animated:animated];
}

- (BOOL)atBottom
{
    UIScrollView *scrollView = self.webView.scrollView;
    return (scrollView.contentOffset.y >= (scrollView.contentSize.height - self.webView.bounds.size.height));
}

- (void)updatePageLabel
{
    //update page label
    if (self.topic.totalPageCount) {
        _totalPages = [self.topic.totalPageCount integerValue];
    }
    self.pageLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)_currentPage, _currentPage>_totalPages?(long)_currentPage:(long)_totalPages];
    //update forward button
    if ([self.dataCenter hasPrecacheFloorsForTopic:self.topic withPage:@(_currentPage + 1)]) {
        [self.forwardButton setImage:[UIImage imageNamed:@"Forward-Cached"] forState:UIControlStateNormal];
    } else {
        [self.forwardButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
    }
    //update back button
    if ([self.dataCenter hasPrecacheFloorsForTopic:self.topic withPage:@(_currentPage - 1)]) {
        [self.backButton setImage:[UIImage imageNamed:@"Back-Cached"] forState:UIControlStateNormal];
    } else {
        [self.backButton setImage:[UIImage imageNamed:@"Back"] forState:UIControlStateNormal];
    }
}

- (void)updateTitleLabelWithTitle:(NSString *)title {
    self.titleLabel.text = title;
    self.titleLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
}

- (UIImage *)screenShot
{
    if (IS_RETINA) {
        UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, [UIScreen mainScreen].scale);
    } else {
        UIGraphicsBeginImageContext(self.view.bounds.size);
    }
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //clip
    CGImageRef imageRef = CGImageCreateWithImageInRect([viewImage CGImage], CGRectMake(0.0, 20.0 * viewImage.scale, viewImage.size.width * viewImage.scale, viewImage.size.height * viewImage.scale - 20.0 * viewImage.scale));
    viewImage = [UIImage imageWithCGImage:imageRef scale:1 orientation:viewImage.imageOrientation];
    CGImageRelease(imageRef);
    return viewImage;
}



- (void)presentAlertViewWithTitle:(NSString *)title andMessage:(NSString *)message
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Message_OK", @"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];

}

- (CGRect)positionOfElementWithId:(NSString *)elementID {
    NSString *js = @"function f(){ var r = document.getElementById('%@').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();";
    NSString *result = [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:js, elementID]];
    CGRect rect = CGRectFromString(result);
    return rect;
}

- (void)updateUserActivityState:(NSUserActivity *)activity {
    NSLog(@"Hand Off Activity Updated");
    activity.userInfo = @{@"topicID": self.topic.topicID,
                          @"page": [NSNumber numberWithInteger:_currentPage]};
    self.userActivity.webpageURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage]];
}

- (void)saveViewPosition {
    if (self.webView.scrollView.contentOffset.y != 0) {
        [self.cachedViewPosition setObject:[NSNumber numberWithDouble:self.webView.scrollView.contentOffset.y] forKey:[NSNumber numberWithInteger:_currentPage]];
    }
}

- (S1Floor *)searchFloorInCacheByFloorID:(NSNumber *)floorID {
    if (floorID == nil) {
        return nil;
    }
    return [self.dataCenter searchFloorInCacheByFloorID:floorID];
}

- (NSMutableArray *)chainSearchQuoteByFirstFloorID:(NSNumber *)floorID {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    S1Floor *floor = [self searchFloorInCacheByFloorID:floorID];
    while (floor) {
        [result insertObject:floor atIndex:0];
        floor = [self searchFloorInCacheByFloorID:floor.firstQuoteReplyFloorID];
    }
    return result;
}

- (void)resetTextViewStyle:(UITextView *)textView {
    NSRange wholeRange = NSMakeRange(0, textView.textStorage.length);
    [textView.textStorage removeAttribute:NSFontAttributeName range:wholeRange];
    [textView.textStorage addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:17.0f] range:wholeRange];
    [textView.textStorage removeAttribute:NSForegroundColorAttributeName range:wholeRange];
    [textView.textStorage addAttribute:NSForegroundColorAttributeName value:[[APColorManager sharedInstance] colorForKey:@"reply.text"] range:wholeRange];
    [textView setFont:[UIFont systemFontOfSize:17.0f]];
    [textView setTextColor:[[APColorManager sharedInstance] colorForKey:@"reply.text"]];
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
        [_backButton setTag:99];
        UILongPressGestureRecognizer *backLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backLongPressed:)];
        backLongPressGR.minimumPressDuration = 0.5;
        [_backButton addGestureRecognizer:backLongPressGR];
    }
    return _backButton;
}

- (UIButton *)forwardButton {
    if (_forwardButton == nil) {
        _forwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
        if (_currentPage == _totalPages) {
            [_forwardButton setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
        } else {
            [_forwardButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
        }
        
        _forwardButton.frame = CGRectMake(0, 0, 40, 30);
        _forwardButton.imageView.clipsToBounds = NO;
        _forwardButton.imageView.contentMode = UIViewContentModeCenter;
        [_forwardButton addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
        [_forwardButton setTag:100];
        UILongPressGestureRecognizer *forwardLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardLongPressed:)];
        forwardLongPressGR.minimumPressDuration = 0.5;
        [_forwardButton addGestureRecognizer:forwardLongPressGR];
    }
    return _forwardButton;
}

- (UILabel *)pageLabel {
    if (_pageLabel == nil) {
        //Page Label
        _pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
        _pageLabel.font = [UIFont systemFontOfSize:13.0f];
        _pageLabel.textColor = [[APColorManager sharedInstance] colorForKey:@"content.pagelabel.text"];
        _pageLabel.backgroundColor = [UIColor clearColor];
        _pageLabel.textAlignment = NSTextAlignmentCenter;
        _pageLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *pickPageGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickPage:)];
        [_pageLabel addGestureRecognizer:pickPageGR];
        UILongPressGestureRecognizer *forceRefreshGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forceRefreshPressed:)];
        forceRefreshGR.minimumPressDuration = 0.5;
        [_pageLabel addGestureRecognizer:forceRefreshGR];
    }
    return _pageLabel;
}

- (UIBarButtonItem *)actionBarButtonItem {
    if (_actionBarButtonItem == nil) {
        _actionBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
    }
    return _actionBarButtonItem;
}

- (void)setTopic:(S1Topic *)topic
{
    
    if ([topic isImmutable]) {
        _topic = [topic copy];
    } else {
        _topic = topic;
    }
    
    _totalPages = ([topic.replyCount integerValue] / 30) + 1;
    if (topic.lastViewedPage) {
        _currentPage = [topic.lastViewedPage integerValue];
    }
    if (_topic.favorite == nil) {
        _topic.favorite = @(NO);
    }
    CLS_LOG(@"ContentVC | Topic setted: %@", self.topic.topicID);
}

- (UIView *)accessoryView {
    //setup accessory view
    UIView *accessoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.replyController.view.bounds.size.width, 35)];
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:accessoryView.bounds];
    
    UIButton *faceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [faceButton setFrame:CGRectMake(0, 0, 44, 35)];
    [faceButton setImage:[UIImage imageNamed:@"MahjongFaceButton"] forState:UIControlStateNormal];
    [faceButton addTarget:self action:@selector(toggleFace:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *faceItem = [[UIBarButtonItem alloc] initWithCustomView:faceButton];
    
    UIButton *spoilerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [spoilerButton setFrame:CGRectMake(0, 0, 44, 35)];
    [spoilerButton setTitle:@"H" forState:UIControlStateNormal];
    [spoilerButton addTarget:self action:@selector(insertSpoilerMark:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *spoilerItem = [[UIBarButtonItem alloc] initWithCustomView:spoilerButton];
    /*
     UIButton *quoteButton = [UIButton buttonWithType:UIButtonTypeSystem];
     [quoteButton setFrame:CGRectMake(0, 0, 44, 35)];
     //[quoteButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
     [quoteButton setTitle:@"「-」" forState:UIControlStateNormal];
     [quoteButton addTarget:self action:@selector(insertQuoteMark:) forControlEvents:UIControlEventTouchUpInside];
     UIBarButtonItem *quoteItem = [[UIBarButtonItem alloc] initWithCustomView:quoteButton];
     
     UIButton *boldButton = [UIButton buttonWithType:UIButtonTypeSystem];
     [boldButton setFrame:CGRectMake(0, 0, 44, 35)];
     //[boldButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
     [boldButton setTitle:@"B" forState:UIControlStateNormal];
     [boldButton addTarget:self action:@selector(insertBoldMark:) forControlEvents:UIControlEventTouchUpInside];
     UIBarButtonItem *boldItem = [[UIBarButtonItem alloc] initWithCustomView:boldButton];
     */
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 26.0f;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [toolbar setItems:@[flexItem, spoilerItem, fixItem, faceItem, flexItem]];
    [accessoryView addSubview:toolbar];
    [toolbar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(accessoryView.mas_left);
        make.right.equalTo(accessoryView.mas_right);
        make.top.equalTo(accessoryView.mas_top);
        make.bottom.equalTo(accessoryView.mas_bottom);
    }];
    return accessoryView;
}



@end
