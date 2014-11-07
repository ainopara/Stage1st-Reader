//
//  S1ContentViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//


#import <Social/Social.h>
#import "S1RootViewController.h"
#import "S1ContentViewController.h"
#import "S1ContentViewModel.h"
#import "S1Topic.h"
#import "S1Floor.h"
#import "S1Tracer.h"
#import "S1DataCenter.h"
#import "S1HUD.h"
#import "REComposeViewController.h"
#import "SVModalWebViewController.h"
#import "MTStatusBarOverlay.h"
#import "AFNetworking.h"
#import "ActionSheetStringPicker.h"
#import "JTSSimpleImageDownloader.h"
#import "JTSImageViewController.h"


@interface S1ContentViewController () <UIWebViewDelegate, UIScrollViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, JTSImageViewControllerInteractionsDelegate>

@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIView *statusBackgroundView; //for iOS7 and above
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIBarButtonItem *actionBarButtonItem;
@property (nonatomic, weak) JTSImageViewController *imageViewer;

@property (nonatomic, strong) REComposeViewController *replyController;

@property (nonatomic, strong) S1Tracer *tracer;
@property (nonatomic, strong) S1ContentViewModel *viewModel;
@end

@implementation S1ContentViewController {
    NSInteger _currentPage;
    NSInteger _totalPages;
    
    BOOL _needToScrollToBottom;
    BOOL _needToLoadLastPosition;
    BOOL _finishLoading;
    BOOL _presentingImageViewer;
    BOOL _presentingWebViewer;
    NSURL *_urlToOpen; // iOS7 Only
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _webView = [[UIWebView alloc] init];
        
        _currentPage = 1;
        _needToScrollToBottom = NO;
        _needToLoadLastPosition = YES;
        _finishLoading = NO;
        _presentingImageViewer = NO;
        _presentingWebViewer = NO;
    }
    return self;
}

- (void)viewDidLoad
{
#define _BAR_HEIGHT 44.0f
#define _STATUS_BAR_HEIGHT 20.0f
    
    [super viewDidLoad];
    self.tracer = self.dataCenter.tracer;
    self.viewModel = [[S1ContentViewModel alloc] initWithDataCenter:self.dataCenter];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.statusBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, _STATUS_BAR_HEIGHT)];
    self.statusBackgroundView.backgroundColor = [S1GlobalVariables color5];
    self.statusBackgroundView.userInteractionEnabled = NO;
    [self.view addSubview:self.statusBackgroundView];
                
    self.webView.frame = CGRectMake(0, _STATUS_BAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height - _BAR_HEIGHT - _STATUS_BAR_HEIGHT);
    
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.webView.delegate = self;
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.webView.scrollView.scrollsToTop = YES;
    self.webView.scrollView.delegate = self;
    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.webView.opaque = NO;
    self.webView.backgroundColor = [S1GlobalVariables color5];
    //title label
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, -64, self.view.bounds.size.width - 24, 64)];
    titleLabel.numberOfLines = 0;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    titleLabel.text = self.topic.title;
    titleLabel.textColor = [S1GlobalVariables color3];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    [self.webView.scrollView insertSubview:titleLabel atIndex:0];
    
    [self.view addSubview:self.webView];
    
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.frame = CGRectMake(0, self.view.bounds.size.height-44.0f, self.view.bounds.size.width, 44.0f);
    self.toolbar.tintColor = [S1GlobalVariables color3];
    self.toolbar.alpha = 1.0;
    

    UIButton *button = nil;
    
    //Backward Button

    button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage imageNamed:@"Back"] forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 30, 30);
    [button addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    [button setTag:99];
    UILongPressGestureRecognizer *backLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backLongPressed:)];
    backLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:backLongPressGR];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:button];    
    
    
    
    //Forward Button
    button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage imageNamed:@"Forward"] forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 30, 30);
    [button addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
    [button setTag:100];
    UILongPressGestureRecognizer *forwardLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardLongPressed:)];
    forwardLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:forwardLongPressGR];
    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    //Page Label
    self.pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
    self.pageLabel.font = [UIFont systemFontOfSize:13.0f];
    self.pageLabel.textColor = [S1GlobalVariables color3];
    self.pageLabel.backgroundColor = [UIColor clearColor];
    self.pageLabel.textAlignment = NSTextAlignmentCenter;
    self.pageLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *pickPageGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pickPage:)];
    [self.pageLabel addGestureRecognizer:pickPageGR];
    [self updatePageLabel];
    
    UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithCustomView:self.pageLabel];
    labelItem.width = 80;
    
    
    self.actionBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 36.0f;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.toolbar setItems:@[backItem, fixItem, forwardItem, flexItem, labelItem, flexItem, self.actionBarButtonItem]];
    
    [self.view addSubview:self.toolbar];
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.statusBackgroundView.autoresizesSubviews = YES;
    self.statusBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.toolbar.autoresizesSubviews = YES;
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
#undef _BAR_HEIGHT
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTopicViewedState:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self fetchContent];
}

- (void)viewWillAppear:(BOOL)animated
{
    _presentingImageViewer = NO;
    _presentingWebViewer = NO;
    [UIApplication sharedApplication].statusBarHidden = NO;
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (_presentingImageViewer || _presentingWebViewer) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self cancelRequest];
        [self saveTopicViewedState:nil];
        self.topic.floors = [[NSMutableDictionary alloc] init]; //If want to cache floors, remove this line.
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotification *notification = [NSNotification notificationWithName:@"S1ContentViewWillDisappearNotification" object:nil];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        });
        
    });
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setters and Getters

- (void)setTopic:(S1Topic *)topic
{
    // Used to estimate total page number
    #define _REPLY_PER_PAGE 30
    _topic = topic;
    _totalPages = ([topic.replyCount integerValue] / _REPLY_PER_PAGE) + 1;
    if (topic.lastViewedPage) {
        _currentPage = [topic.lastViewedPage integerValue];
    }
}

#pragma mark - Bar Button Actions

- (void)back:(id)sender
{
    [self cancelRequest];
    _needToLoadLastPosition = NO;
    if (_currentPage - 1 >= 1) {
        _currentPage -= 1;
        [self fetchContent];
    } else {
        [[self rootViewController] dismissDetailViewController:0.3];
    }
}

- (void)forward:(id)sender
{
    [self cancelRequest];
    _needToLoadLastPosition = NO;
    if (_currentPage + 1 <= _totalPages) {
        _currentPage += 1;
        [self fetchContent];
    } else {
        if (![self atBottom]) {
            [self scrollToButtomAnimated:YES];
        } else {
            _needToScrollToBottom = YES;
            [self fetchContent];
        }
    }
}

- (void)backLongPressed:(UIGestureRecognizer *)gr
{
    _needToLoadLastPosition = NO;
    if (gr.state == UIGestureRecognizerStateBegan) {
        if (_currentPage > 1) {
            _currentPage = 1;
            [self cancelRequest];
            [self fetchContent];
        }
    }
}

- (void)forwardLongPressed:(UIGestureRecognizer *)gr
{
    _needToLoadLastPosition = NO;
    if (gr.state == UIGestureRecognizerStateBegan) {
        if (_currentPage < _totalPages) {
            _currentPage = _totalPages;
            [self cancelRequest];
            [self fetchContent];
        }
    }
}

- (void)pickPage:(id)sender
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (long i = 0; i < (_currentPage > _totalPages ? _currentPage : _totalPages); i++) {
        [array addObject:[NSString stringWithFormat:@"第 %ld 页", i + 1]];
    }
    [ActionSheetStringPicker showPickerWithTitle:@""
                                            rows:array
                                initialSelection:_currentPage - 1
                                       doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                                           _currentPage = selectedIndex + 1;
                                           [self cancelRequest];
                                           [self fetchContent];
                                       }
                                     cancelBlock:nil
                                          origin:self.pageLabel];

}

- (void)action:(id)sender
{
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel")
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:NSLocalizedString(@"ContentView_ActionSheet_Reply", @"Reply"),
                                      [self.tracer topicIsFavorited:self.topic.topicID]?NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite"),
                                      NSLocalizedString(@"ContentView_ActionSheet_Weibo", @"Weibo"),
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
        UIAlertAction *favoriteAction = [UIAlertAction actionWithTitle:[self.tracer topicIsFavorited:self.topic.topicID]?NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self.tracer setTopicFavoriteState:self.topic.topicID withState:(![self.tracer topicIsFavorited:self.topic.topicID])];
        }];
        // Weibo Action
        UIAlertAction *weiboAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Weibo", @"Weibo") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (!NSClassFromString(@"SLComposeViewController")) {
                [self presentAlertViewWithTitle:@"" andMessage:NSLocalizedString(@"ContentView_Need_Weibo_Service_Support_Message", @"")];
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
        // Origin Page Action
        UIAlertAction *originPageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_OriginPage", @"Origin") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            _presentingWebViewer = YES;
            NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
            SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:pageAddress];
            [controller.view setTintColor:[S1GlobalVariables color3]];
            [self presentViewController:controller animated:YES completion:nil];
        }];
        // Cancel Action
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
        
        [moreActionSheet addAction:replyAction];
        [moreActionSheet addAction:favoriteAction];
        [moreActionSheet addAction:weiboAction];
        [moreActionSheet addAction:originPageAction];
        [moreActionSheet addAction:cancelAction];
        [moreActionSheet.popoverPresentationController setBarButtonItem:self.actionBarButtonItem];
        [self presentViewController:moreActionSheet animated:YES completion:nil];
    }
    
}

#pragma mark - UIActionSheet Delegate (iOS7 Only)

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
//    NSLog(@"%d", buttonIndex);
    if (self.imageViewer) {
        // Save Image
        if (0 == buttonIndex) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImageWriteToSavedPhotosAlbum(self.imageViewer.image, nil, nil, nil);
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
            [self.tracer setTopicFavoriteState:self.topic.topicID withState:(![self.tracer topicIsFavorited:self.topic.topicID])];
        }
        
        // Weibo
        if (2 == buttonIndex) {
            if (!NSClassFromString(@"SLComposeViewController")) {
                [self presentAlertViewWithTitle:@"" andMessage:NSLocalizedString(@"ContentView_Need_Weibo_Service_Support_Message", @"")];
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
        
        // Origin Page
        if (3 == buttonIndex) {
            _presentingWebViewer = YES;
            NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
            SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:pageAddress];
            [controller.view setTintColor:[S1GlobalVariables color3]];
            [self presentViewController:controller animated:YES completion:nil];
        }
    }
    
}

#pragma mark - UIAlertView Delegate (iOS7 Only)

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (1 == buttonIndex) {
        _presentingWebViewer = YES;
        NSLog(@"%@", _urlToOpen);
        SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:_urlToOpen.absoluteString];
        [[controller view] setTintColor:[S1GlobalVariables color3]];
        [self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:controller animated:YES completion:nil];        
    }
}

#pragma mark - UIWebView Delegate


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
                                                   backgroundStyle:JTSImageViewControllerBackgroundOption_None];
            [UIApplication sharedApplication].statusBarHidden = YES;
            [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
            [imageViewer setInteractionsDelegate:self];
        }
        return NO;
    }
    //Image URL opened in image Viewer (TODO: Not Be Tested)
    if ([request.URL.path hasSuffix:@".jpg"] || [request.URL.path hasSuffix:@".gif"]) {
        _presentingImageViewer = YES;
        NSString *imageURL = request.URL.absoluteString;
        NSLog(@"%@", imageURL);
        JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
        imageInfo.imageURL = [[NSURL alloc] initWithString:imageURL];
        JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                               initWithImageInfo:imageInfo
                                               mode:JTSImageViewControllerMode_Image
                                               backgroundStyle:JTSImageViewControllerBackgroundOption_None];
        [UIApplication sharedApplication].statusBarHidden = YES;
        [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOffscreen];
        [imageViewer setInteractionsDelegate:self];
        return NO;
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
            [[controller view] setTintColor:[S1GlobalVariables color3]];
            [self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:controller animated:YES completion:nil];
        }];
        [alert addAction:cancelAction];
        [alert addAction:continueAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_needToLoadLastPosition) {
        if (self.topic.lastViewedPosition != 0) {
            [self.webView.scrollView setContentOffset:CGPointMake(self.webView.scrollView.contentOffset.x, [self.topic.lastViewedPosition floatValue])];
        }
    }
    if (_needToScrollToBottom) {
        [self scrollToButtomAnimated:YES];
    }
    
}

#pragma mark - JTSImageViewController Interactions Delegate
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
        UIAlertAction *saveAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ImageViewer_ActionSheet_Save", @"Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImageWriteToSavedPhotosAlbum(self.imageViewer.image, nil, nil, nil);
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
#pragma mark - UIScrollView Delegate

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    return YES;
}

#pragma mark - Networking

- (void)fetchContent
{
    [self updatePageLabel];
    S1HUD *HUD = [S1HUD showHUDInView:self.view];
    [HUD showActivityIndicator];
    [HUD setRefreshEventHandler:^(S1HUD *aHUD) {
        [aHUD hideWithDelay:0.0];
        [self fetchContent];
    }];
    
    // NSLog(@"Begin Fetch Content");
    NSDate *start = [NSDate date];
    [self.viewModel contentPageForTopic:self.topic withPage:_currentPage success:^(NSString *contents) {
        NSTimeInterval timeInterval = [start timeIntervalSinceNow];
        NSLog(@"Finish Fetch Content time elapsed:%f",-timeInterval);
        [self updatePageLabel];
        [self.webView loadHTMLString:contents baseURL:nil];
        _finishLoading = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [HUD hideWithDelay:0.3];
        });
    } failure:^(NSError *error) {
        if (error.code == -999) {
            NSLog(@"request cancelled.");
            [HUD hideWithDelay:0.3];
        } else {
            NSLog(@"%@", error);
            [HUD showRefreshButton];
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
    
    [self rootViewController].modalPresentationStyle = UIModalPresentationCurrentContext;
    
    NSString *replyDraft;
    if (self.replyController) {
        replyDraft = [self.replyController.text stringByAppendingString:text? text : @""];
    } else {
        replyDraft = text? text : @"";
    }
    
    self.replyController = [[REComposeViewController alloc] init];
    REComposeViewController *replyController = self.replyController;
    replyController.title = NSLocalizedString(@"ContentView_Reply_Title", @"Reply");
    if (topicFloor) {
        replyController.title = [@"@" stringByAppendingString:topicFloor.author];
    }
    __weak typeof(self) myself = self; //Is it necessary to avoid memory leak?
    [replyController setCompletionHandler:^(REComposeViewController *composeViewController, REComposeResult result){
        if (result == REComposeResultCancelled) {
            [composeViewController dismissViewControllerAnimated:YES completion:nil];
        } else if (result == REComposeResultPosted) {
            if (composeViewController.text.length > 0) {
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                [[MTStatusBarOverlay sharedInstance] postMessage:@"回复发送中" animated:YES];
                __strong typeof(self) strongMyself = myself;
                if (topicFloor) {
                    [self.dataCenter replySpecificFloor:topicFloor inTopic:self.topic atPage:[NSNumber numberWithUnsignedInteger:_currentPage ] withText:composeViewController.text success:^{
                        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                        [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                        
                        [strongMyself.replyController setText:@""];
                        if (strongMyself->_currentPage == strongMyself->_totalPages) {
                            strongMyself->_needToScrollToBottom = YES;
                            [strongMyself fetchContent];
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
                        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                        [[MTStatusBarOverlay sharedInstance] postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                        [strongMyself.replyController setText:@""];
                        if (strongMyself->_currentPage == strongMyself->_totalPages) {
                            strongMyself->_needToScrollToBottom = YES;
                            [strongMyself fetchContent];
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
    }];
    
    [self.replyController setText:[self.replyController.text stringByAppendingString:replyDraft]];
    [self.replyController.view setFrame:self.view.bounds];
    [self.replyController presentFromViewController:self];
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
    self.pageLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)_currentPage, _currentPage>_totalPages?(long)_currentPage:(long)_totalPages];
}

- (S1RootViewController *)rootViewController
{
    UIViewController *controller = [self parentViewController];
    while (![controller isKindOfClass:[S1RootViewController class]] || !controller) {
        controller = [controller parentViewController];
    }
    return (S1RootViewController *)controller;
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
    CGImageRef imageRef = nil;
    if (IS_RETINA) {
        imageRef = CGImageCreateWithImageInRect([viewImage CGImage], CGRectMake(0.0, 40.0, viewImage.size.width * 2, viewImage.size.height * 2 - 40.0));
    } else {
        imageRef = CGImageCreateWithImageInRect([viewImage CGImage], CGRectMake(0.0, 20.0, viewImage.size.width, viewImage.size.height - 20.0));
    }
    viewImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return viewImage;
}

- (void)viewDidLayoutSubviews
{
    //NSLog(@"layout called");
    NSNotification *notification = [NSNotification notificationWithName:@"S1ContentViewAutoLayoutedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)saveTopicViewedState:(id)sender
{
    if (_finishLoading) {
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: self.webView.scrollView.contentOffset.y]];
    } else if ((self.topic.lastViewedPosition == nil) || (![self.topic.lastViewedPage isEqualToNumber:[NSNumber numberWithInteger: _currentPage]])) {
        [self.topic setLastViewedPosition:[NSNumber numberWithFloat: 0.0]];
    }
    [self.topic setLastViewedPage:[NSNumber numberWithInteger: _currentPage]];
    [self.topic setFavorite:[NSNumber numberWithBool:[self.tracer topicIsFavorited:self.topic.topicID]]];
    [self.topic setLastReplyCount:self.topic.replyCount];
    [self.tracer hasViewed:self.topic];}

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

@end
