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
#import "S1MahjongFaceViewController.h"
#import "Masonry.h"
#import "NavigationControllerDelegate.h"



@interface S1ContentViewController () <UIWebViewDelegate, UIScrollViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, JTSImageViewControllerInteractionsDelegate, JTSImageViewControllerOptionsDelegate,REComposeViewControllerDelegate, S1MahjongFaceViewControllerDelegate, APPullToActionDelagete>

@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic, strong) APPullToActionViewController *pullToActionViewController;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIBarButtonItem *actionBarButtonItem;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *topDecorateLine;
@property (nonatomic, strong) UIView *bottomDecorateLine;
@property (nonatomic, weak) JTSImageViewController *imageViewer;

@property (nonatomic, strong) NSMutableAttributedString *attributedReplyDraft;
@property (nonatomic, strong) NSMutableDictionary *cachedViewPosition;
@property (nonatomic, strong) S1ContentViewModel *viewModel;

@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *forwardButton;
@property (nonatomic, weak) S1Floor *replyTopicFloor;
@property (nonatomic, weak) REComposeViewController *replyController;
@property (nonatomic, strong) S1MahjongFaceViewController *mahjongController;
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
    NSURL *_urlToOpen; // iOS7 Only
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil // not used
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _currentPage = 1;
        _needToScrollToBottom = NO;
        _needToLoadLastPosition = YES;
        _finishLoading = NO;
        _presentingImageViewer = NO;
        _presentingWebViewer = NO;
        _presentingContentViewController = NO;
        _cachedViewPosition = [[NSMutableDictionary alloc] init];
    }
    return self;
}

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
        _cachedViewPosition = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
//#define _STATUS_BAR_HEIGHT 20.0f
    
    [super viewDidLoad];
    self.viewModel = [[S1ContentViewModel alloc] initWithDataCenter:self.dataCenter];
    
    self.view.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"content.background"];
    
    //web view
    self.webView.delegate = self;
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.webView.scrollView.scrollsToTop = YES;
    self.webView.scrollView.delegate = self;
    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.webView.opaque = NO;
    self.webView.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"content.webview.background"];
    
    self.pullToActionViewController = [[APPullToActionViewController alloc] initWithScrollView:self.webView.scrollView];
    self.pullToActionViewController.delegate = self;
    
    self.topDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, -100, self.view.bounds.size.width - 0, 1)];
    if(_currentPage != 1) {
        self.topDecorateLine.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    }
    
    [self.webView.scrollView addSubview:self.topDecorateLine];
    self.bottomDecorateLine = [[UIView alloc] initWithFrame:CGRectMake(0, -100, self.view.bounds.size.width - 0, 1)];
    self.bottomDecorateLine.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    [self.webView.scrollView addSubview:self.bottomDecorateLine];
    //title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, -64, self.view.bounds.size.width - 24, 64)];
    
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    BOOL hasInvalidTitle = NO;
    if (self.topic.title == nil || [self.topic.title isEqualToString:@""]) {
        self.titleLabel.text = [NSString stringWithFormat: @"%@ 载入中...", self.topic.topicID];
        hasInvalidTitle = YES;
    } else {
        self.titleLabel.text = self.topic.title;
    }
    if (hasInvalidTitle) {
        self.titleLabel.textColor = [[S1ColorManager sharedInstance] colorForKey:@"content.titlelabel.text.disable"];
    }else {
        self.titleLabel.textColor = [[S1ColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
    }
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    [self.webView.scrollView insertSubview:self.titleLabel atIndex:0];
    /*
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.webView.subviews[1])
    }];*/

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
    [button setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
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
    self.pageLabel.textColor = [[S1ColorManager sharedInstance] colorForKey:@"content.pagelabel.text"];
    self.pageLabel.backgroundColor = [UIColor clearColor];
    self.pageLabel.textAlignment = NSTextAlignmentCenter;
    self.pageLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *pickPageGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickPage:)];
    [self.pageLabel addGestureRecognizer:pickPageGR];
    
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
    
    //Set up Activity for Hand Off
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        ; // iOS 7 do not support hand off
    } else {
        NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"Stage1st.view-topic"];
        activity.title = @"Viewing Topic";
        activity.userInfo = @{@"topicID": self.topic.topicID,
                              @"page": [NSNumber numberWithInteger:_currentPage]};
        activity.webpageURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage]];
        self.userActivity = activity;
    }
    
    
    [self fetchContentAndPrecacheNextPage:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    _presentingImageViewer = NO;
    _presentingWebViewer = NO;
    
    [UIApplication sharedApplication].statusBarHidden = NO;
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    _presentingContentViewController = NO;
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    if (_presentingImageViewer || _presentingWebViewer || _presentingContentViewController) {
        return;
    }
    //NSLog(@"Content View did disappear");
    [self cancelRequest];
    [self saveTopicViewedState:nil];
    self.topic.floors = [[NSMutableDictionary alloc] init]; //If want to cache floors, remove this line.
    NSNotification *notification = [NSNotification notificationWithName:@"S1ContentViewWillDisappearNotification" object:nil];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    NSLog(@"Content View Dealloced: %@", self.topic.title);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    [self.dataCenter clearTopicListCache];
    [self updatePageLabel];
    // Dispose of any resources that can be recreated.
}
#pragma mark - Setters and Getters

- (void)setTopic:(S1Topic *)topic
{
    // Used to estimate total page number
    #define _REPLY_PER_PAGE 30
    if ([topic isImmutable]) {
        _topic = [topic copy];
    } else {
        _topic = topic;
    }
    
    _totalPages = ([topic.replyCount integerValue] / _REPLY_PER_PAGE) + 1;
    if (topic.lastViewedPage) {
        _currentPage = [topic.lastViewedPage integerValue];
    }
    if (_topic.favorite == nil) {
        _topic.favorite = @(NO);
    }
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
    [spoilerButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
    [spoilerButton addTarget:self action:@selector(insertSpoilerMark:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *spoilerItem = [[UIBarButtonItem alloc] initWithCustomView:spoilerButton];
    
    UIButton *quoteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [quoteButton setFrame:CGRectMake(0, 0, 44, 35)];
    //[quoteButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
    [quoteButton setTitle:@"Q" forState:UIControlStateNormal];
    [quoteButton addTarget:self action:@selector(insertQuoteMark:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *quoteItem = [[UIBarButtonItem alloc] initWithCustomView:quoteButton];
    
    UIButton *boldButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [boldButton setFrame:CGRectMake(0, 0, 44, 35)];
    //[boldButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
    [boldButton setTitle:@"B" forState:UIControlStateNormal];
    [boldButton addTarget:self action:@selector(insertBoldMark:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *boldItem = [[UIBarButtonItem alloc] initWithCustomView:boldButton];
    
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 26.0f;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [toolbar setItems:@[flexItem, boldItem, fixItem, quoteItem, fixItem, spoilerItem, fixItem, faceItem, flexItem]];
    [accessoryView addSubview:toolbar];
    [toolbar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(accessoryView.mas_left);
        make.right.equalTo(accessoryView.mas_right);
        make.top.equalTo(accessoryView.mas_top);
        make.bottom.equalTo(accessoryView.mas_bottom);
    }];
    return accessoryView;
}

#pragma mark - Bar Button Actions

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
            [self scrollToButtomAnimated:YES];
        } else {
            //_needToScrollToBottom = YES;
            [self fetchContentAndPrecacheNextPage:YES];
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
            [array addObject:[NSString stringWithFormat:@"第 %ld 页✓", i + 1]];
        } else {
            [array addObject:[NSString stringWithFormat:@"第 %ld 页", i + 1]];
        }
    }
    ActionSheetStringPicker *picker = [[ActionSheetStringPicker alloc] initWithTitle:@""
                                            rows:array
                                initialSelection:_currentPage - 1
                                       doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                                           [self saveViewPosition];
                                           _currentPage = selectedIndex + 1;
                                           [self cancelRequest];
                                           _needToLoadLastPosition = NO;
                                           [self fetchContent];
                                       }
                                     cancelBlock:nil
                                          origin:self.pageLabel];
    picker.pickerBackgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"content.picker.background"];
    picker.pickerTextAttributes = @{NSForegroundColorAttributeName: [[S1ColorManager sharedInstance] colorForKey:@"content.picker.text"],};
    [picker showActionSheetPicker];

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
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel")
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:NSLocalizedString(@"ContentView_ActionSheet_Reply", @"Reply"),
                                      [self.topic.favorite boolValue]?NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite"),
                                      NSLocalizedString(@"ContentView_ActionSheet_Weibo", @"Weibo"),
                                      NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link"),
                                      NSLocalizedString(@"ContentView_ActionSheet_OriginPage", @"Origin"), nil];
        actionSheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
        [actionSheet showInView:self.view];
    } else {
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
        // Weibo Action
        UIAlertAction *weiboAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Weibo", @"Weibo") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (!NSClassFromString(@"SLComposeViewController")) {
                return;
            }
            SLComposeViewController *controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
            if (!controller) {
                [self presentAlertViewWithTitle:@"" andMessage:NSLocalizedString(@"ContentView_Need_Chinese_Keyboard_To_Open_Weibo_Service_Message", @"")];
                return;
            }
            [controller setInitialText:[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.topic.title]];
            [controller addURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage]]];
            [controller addImage:[self screenShot]];
            
            __weak SLComposeViewController *weakController = controller;
            [self presentViewController:controller animated:YES completion:nil];
            [controller setCompletionHandler:^(SLComposeViewControllerResult result){
                [weakController dismissViewControllerAnimated:YES completion:nil];
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
            _presentingWebViewer = YES;
            NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
            SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:pageAddress];
            [controller.view setTintColor:[[S1ColorManager sharedInstance] colorForKey:@"content.tint"]];
            [self presentViewController:controller animated:YES completion:nil];
        }];
        // Cancel Action
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
        
        [moreActionSheet addAction:replyAction];
        [moreActionSheet addAction:favoriteAction];
        [moreActionSheet addAction:weiboAction];
        [moreActionSheet addAction:copyLinkAction];
        [moreActionSheet addAction:originPageAction];
        [moreActionSheet addAction:cancelAction];
        [moreActionSheet.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
        [self presentViewController:moreActionSheet animated:YES completion:nil];
    }
    
}
#pragma mark Accessory View
- (void)toggleFace:(id)sender {
    NSLog(@"toggleFace");
    if (self.replyController.inputView == nil) {
        if (self.mahjongController == nil) {
            self.mahjongController = [[S1MahjongFaceViewController alloc] init];
            //[self.mahjongController.view setFrame:CGRectMake(0, 0, 320, 217)];
            //[self.view addSubview:self.mahjongController.view];
            self.mahjongController.delegate = self;
        }
        self.replyController.inputView = self.mahjongController.view;
        [self.replyController reloadInputViews];
    } else {
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
        
        NSRange wholeRange = NSMakeRange(0, self.replyController.textView.textStorage.length);
        [self.replyController.textView.textStorage removeAttribute:NSFontAttributeName range:wholeRange];
        [self.replyController.textView.textStorage addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:17.0f] range:wholeRange];
    }
}




#pragma mark - UIActionSheet Delegate (iOS7 Only)

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
//    NSLog(@"%d", buttonIndex);
    if (self.imageViewer) {
        // Save Image
        if (0 == buttonIndex) {
            UIImage *imageToSave = self.imageViewer.image;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImageWriteToSavedPhotosAlbum(imageToSave, nil, nil, nil);
            });
        }
        // Copy URL
        if (1 == buttonIndex) {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = self.imageViewer.imageInfo.imageURL.absoluteString;
        }
    } else {
        // Reply
        if (0 == buttonIndex) {
            [self presentReplyViewWithAppendText:@"" reply:nil];
        }
        // Favorite
        if (1 == buttonIndex) {
            self.topic.favorite = [NSNumber numberWithBool:![self.topic.favorite boolValue]];
            S1HUD *HUD = [S1HUD showHUDInView:self.view];
            [HUD setText:[self.topic.favorite boolValue] ? NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") : NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite") withWidthMultiplier:2];
            [HUD hideWithDelay:0.3];
        }
        
        // Weibo
        if (2 == buttonIndex) {
            if (!NSClassFromString(@"SLComposeViewController")) {
                return;
            }
            SLComposeViewController *controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
            if (!controller) {
                [self presentAlertViewWithTitle:@"" andMessage:NSLocalizedString(@"ContentView_Need_Chinese_Keyboard_To_Open_Weibo_Service_Message", @"")];
                return;
            }
            [controller setInitialText:[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.topic.title]];
            [controller addURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage]]];
            [controller addImage:[self screenShot]];
            
            __weak SLComposeViewController *weakController = controller;
            [self presentViewController:controller animated:YES completion:nil];
            [controller setCompletionHandler:^(SLComposeViewControllerResult result){
                [weakController dismissViewControllerAnimated:YES completion:nil];
            }];
        }
        // Copy Link
        if (3 == buttonIndex) {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
            S1HUD *HUD = [S1HUD showHUDInView:self.view];
            [HUD setText:NSLocalizedString(@"ContentView_ActionSheet_CopyLink", @"Copy Link") withWidthMultiplier:2];
            [HUD hideWithDelay:0.3];
        }
        // Origin Page
        if (4 == buttonIndex) {
            _presentingWebViewer = YES;
            NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
            SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:pageAddress];
            [controller.view setTintColor:[[S1ColorManager sharedInstance] colorForKey:@"content.tint"]];
            [self presentViewController:controller animated:YES completion:nil];
        }
    }
    
}

#pragma mark UIAlertView Delegate (iOS7 Only)

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (1 == buttonIndex) {
        _presentingWebViewer = YES;
        NSLog(@"%@", _urlToOpen);
        SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:_urlToOpen.absoluteString];
        [[controller view] setTintColor:[[S1ColorManager sharedInstance] colorForKey:@"content.tint"]];
        //[self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:controller animated:YES completion:nil];        
    }
}

#pragma mark UIWebView Delegate


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
                        for (S1Floor *floor in [self.topic.floors allValues]) {
                            if (pid == [floor.floorID integerValue]) {
                                _presentingContentViewController = YES;
                                S1Topic *quoteTopic = [self.topic copy];
                                NSString *htmlString = [S1Parser generateQuotePage:[self chainSearchQuoteByFirstFloorID:@(pid)] withTopic:quoteTopic];
                                S1QuoteFloorViewController *quoteFloorViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"QuoteFloor"];
                                quoteFloorViewController.htmlString = htmlString;
                                quoteFloorViewController.centerFloorID = [floor.floorID integerValue];
                                [[self navigationController] pushViewController:quoteFloorViewController animated:YES];
                                return NO;
                            }
                        }
                    }
                }
            }
            
        }
    }
    
    // Open link
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString delegate:self cancelButtonTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") otherButtonTitles:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @""), nil];
        _urlToOpen = request.URL;
        [alertView show];
    } else {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        UIAlertAction* continueAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            _presentingWebViewer = YES;
            NSLog(@"%@", request.URL);
            SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:request.URL.absoluteString];
            [[controller view] setTintColor:[[S1ColorManager sharedInstance] colorForKey:@"content.tint"]];
            //[self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:controller animated:YES completion:nil];
        }];
        [alert addAction:cancelAction];
        [alert addAction:continueAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    return NO;
}

- (S1Floor *)searchFloorInCacheByFloorID:(NSNumber *)floorID {
    if (floorID == nil) {
        return nil;
    }
    for (S1Floor *floor in [self.topic.floors allValues]) {
        if ([floorID integerValue] == [floor.floorID integerValue]) {
            return floor;
        }
    }
    return nil;
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

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_needToLoadLastPosition) {
        if (self.topic.lastViewedPosition != 0) {
            [self.webView.scrollView setContentOffset:CGPointMake(self.webView.scrollView.contentOffset.x, [self.topic.lastViewedPosition floatValue])];
        }
        _needToLoadLastPosition = NO;
    }
    NSNumber *currentPageNumber = [NSNumber numberWithInteger:_currentPage];
    NSNumber *positionForPage =[self.cachedViewPosition objectForKey:currentPageNumber];
    if (positionForPage) {
        if ([positionForPage doubleValue] >= self.webView.scrollView.contentSize.height - self.webView.scrollView.bounds.size.height) {
            [self.webView.scrollView setContentOffset:CGPointMake(self.webView.scrollView.contentOffset.x, self.webView.scrollView.contentSize.height - self.webView.scrollView.bounds.size.height)];
        } else {
            [self.webView.scrollView setContentOffset:CGPointMake(self.webView.scrollView.contentOffset.x, [positionForPage doubleValue])];
        }
        
    }
    if (_needToScrollToBottom) {
        [self scrollToButtomAnimated:YES];
    }
    
}

#pragma mark JTSImageViewController Interactions Delegate
- (void)imageViewerDidLongPress:(JTSImageViewController *)imageViewer atRect:(CGRect)rect {
    self.imageViewer = imageViewer;
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel")
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:NSLocalizedString(@"ImageViewer_ActionSheet_Save", @"Save"),NSLocalizedString(@"ImageViewer_ActionSheet_CopyURL", @"Copy URL"), nil];
        [actionSheet showInView:imageViewer.view];
    } else {
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
    
}
#pragma mark JTSImageViewController Options Delegate
- (CGFloat)alphaForBackgroundDimmingOverlayInImageViewer:(JTSImageViewController *)imageViewer {
    return 0.3;
}

#pragma mark UIScrollView Delegate

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    return YES;
}

#pragma mark S1MahjongFaceViewControllerDelegate

- (void)mahjongFaceViewController:(S1MahjongFaceViewController *)mahjongFaceViewController didFinishWithResult:(S1MahjongFaceTextAttachment *)attachment {
    UITextView *textView = self.replyController.textView;
    if (textView) {
        [textView.textStorage insertAttributedString:[NSAttributedString attributedStringWithAttachment:attachment] atIndex:textView.selectedRange.location];
        
        //Move selection location
        self.replyController.textView.selectedRange = NSMakeRange(self.replyController.textView.selectedRange.location + 1, self.replyController.textView.selectedRange.length);
        
        //Reset Text Style
        NSRange wholeRange = NSMakeRange(0, textView.textStorage.length);
        [textView.textStorage removeAttribute:NSFontAttributeName range:wholeRange];
        [textView.textStorage addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:17.0f] range:wholeRange];
    }
}

- (void)mahjongFaceViewControllerDidPressBackSpace:(S1MahjongFaceViewController *)mahjongFaceViewController {
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
#pragma mark APPullToAction Delegate

- (void)scrollViewDidEndDraggingOutsideTopBoundWithOffset:(CGFloat)offset {
    if (offset < -80) {
        if (_currentPage != 1 && _finishLoading) {
            [self back:self.backButton];
        }
    }
    
}

- (void)scrollViewDidEndDraggingOutsideBottomBoundWithOffset:(CGFloat)offset {
    if (offset > 80 && _finishLoading) {
        [self forward:self.forwardButton];
    }
}

- (void)scrollViewContentSizeDidChange:(CGSize)contentSize {
    self.topDecorateLine.frame = CGRectMake(0, -80, contentSize.width - 0, 1);
    if(_currentPage != 1) {
        self.topDecorateLine.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"content.decoration.line"];
    } else {
        self.topDecorateLine.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"content.webview.background"];
    }
    self.bottomDecorateLine.frame = CGRectMake(0, contentSize.height + 80, contentSize.width - 0, 1);
}

- (void)scrollViewContentOffsetProgress:(NSDictionary * __nonnull)progress {
    NSNumber *bottomProgress = progress[@"bottom"];
    if (_currentPage >= _totalPages) {
        if ([bottomProgress doubleValue] >= 0) {
            [self.forwardButton setImage:[UIImage imageNamed:@"Refresh_black"] forState:UIControlStateNormal];
            self.forwardButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2 * [bottomProgress doubleValue], 0, 0, 1);
        } else {
            [self.forwardButton setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
            self.forwardButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2, 0, 0, 1);
        }
        
    } else {
        double progress = [bottomProgress doubleValue];
        if (progress < 0) {
            progress = 0;
        } else if (progress > 1){
            progress = 1;
        }
        self.forwardButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2 * progress, 0, 0, 1);
    }
    

    if (_currentPage != 1) {
        NSNumber *topProgress = progress[@"top"];
        double progress = [topProgress doubleValue];
        if (progress < 0) {
            progress = 0;
        } else if (progress > 1){
            progress = 1;
        }
        self.backButton.imageView.layer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI_2 * progress, 0, 0, 1);
    } else {
        self.backButton.imageView.layer.transform = CATransform3DIdentity;
    }
    
    
    
}

#pragma mark - Networking

- (void)fetchContent {
    [self fetchContentAndPrecacheNextPage:NO];
}

- (void)fetchContentAndPrecacheNextPage:(BOOL)shouldUpdate
{
    [self updatePageLabel];
    __weak typeof(self) weakSelf = self;
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        ; // iOS 7 do not support hand off
    } else {
        self.userActivity.needsSave = YES;
    }
    
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
    
    [self.viewModel contentPageForTopic:self.topic withPage:_currentPage success:^(NSString *contents) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf updatePageLabel];
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
        if (HUD != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (strongSelf.topic.message == nil || [strongSelf.topic.message isEqualToString:@""]) {
                    [HUD hideWithDelay:0.3];
                } else {
                    [HUD setText:strongSelf.topic.message withWidthMultiplier:5];
                }
            });
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
    [replyController setKeyboardAppearance:[[S1ColorManager sharedInstance] isDarkTheme] ? UIKeyboardAppearanceDark:UIKeyboardAppearanceDefault];
    [replyController setTextViewTintColor:[[S1ColorManager sharedInstance] colorForKey:@"reply.tint"]];
    [replyController setTintColor:[[S1ColorManager sharedInstance] colorForKey:@"reply.background"]];
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
     
    [replyController presentFromViewController:self];
    NavigationControllerDelegate *navigationDelegate = self.navigationController.delegate;
    navigationDelegate.panRecognizer.enabled = NO;
}

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result {
    NavigationControllerDelegate *navigationDelegate = self.navigationController.delegate;
    navigationDelegate.panRecognizer.enabled = YES;
    if (result == REComposeResultCancelled) {
        self.attributedReplyDraft = [composeViewController.attributedText mutableCopy];
        [composeViewController dismissViewControllerAnimated:YES completion:nil];
    } else if (result == REComposeResultPosted) {
        if (composeViewController.text.length > 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [[MTStatusBarOverlay sharedInstance] postMessage:@"回复发送中" animated:YES];
            __weak typeof(self) weakSelf = self;
            if (self.replyTopicFloor) {
                [self.dataCenter replySpecificFloor:self.replyTopicFloor inTopic:self.topic atPage:[NSNumber numberWithUnsignedInteger:_currentPage ] withText:composeViewController.text success:^{
                    __strong typeof(self) strongSelf = weakSelf;
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                    [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                    strongSelf.attributedReplyDraft = nil;
                    if (strongSelf->_currentPage == strongSelf->_totalPages) {
                        strongSelf->_needToScrollToBottom = YES;
                        [strongSelf fetchContentAndPrecacheNextPage:YES];
                    }
                } failure:^(NSError *error) {
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                    if (error.code == -999) {
                        NSLog(@"Code -999 may means user want to cancel this request.");
                        [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
                    } else {
                        [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复失败" duration:2.5 animated:YES];
                    }
                }];
            } else {
                [self.dataCenter replyTopic:self.topic withText:composeViewController.text success:^{
                    __strong typeof(self) strongSelf = weakSelf;
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                    [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                    strongSelf.attributedReplyDraft = nil;
                    if (strongSelf->_currentPage == strongSelf->_totalPages) {
                        strongSelf->_needToScrollToBottom = YES;
                        [strongSelf fetchContentAndPrecacheNextPage:YES];
                    }
                } failure:^(NSError *error) {
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                    if (error.code == -999) {
                        NSLog(@"Code -999 may means user want to cancel this request.");
                        [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
                    } else {
                        [[MTStatusBarOverlay sharedInstance] postErrorMessage:@"回复失败" duration:2.5 animated:YES];
                    }
                }];
            }
            [composeViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - Helpers

- (void)scrollToButtomAnimated:(BOOL)animated
{
    [self.webView.scrollView setContentOffset:CGPointMake(0, self.webView.scrollView.contentSize.height-self.webView.scrollView.bounds.size.height) animated:animated];
    _needToScrollToBottom = NO;
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
    self.titleLabel.textColor = [[S1ColorManager sharedInstance] colorForKey:@"content.titlelabel.text.normal"];
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

- (void)saveTopicViewedState:(id)sender {
    if (_finishLoading) {
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: self.webView.scrollView.contentOffset.y]];
    } else if ((self.topic.lastViewedPosition == nil) || (![self.topic.lastViewedPage isEqualToNumber:[NSNumber numberWithInteger: _currentPage]])) {
        //if last viewed page in record doesn't equal current page it means user has changed page since this view controller is loaded. Then the unfinished new page's last view position should be 0.
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: 0.0]];
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

- (void)presentAlertViewWithTitle:(NSString *)title andMessage:(NSString *)message
{
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"OK") otherButtonTitles:nil] show];
    } else {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Message_OK", @"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
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
}

- (void)saveViewPosition {
    if (self.webView.scrollView.contentOffset.y != 0) {
        [self.cachedViewPosition setObject:[NSNumber numberWithDouble:self.webView.scrollView.contentOffset.y] forKey:[NSNumber numberWithInteger:_currentPage]];
    }
}

@end
