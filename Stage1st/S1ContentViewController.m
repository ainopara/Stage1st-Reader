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
#import "S1HTTPClient.h"
#import "S1Topic.h"
#import "S1Parser.h"
#import "S1Tracer.h"
#import "S1HUD.h"
#import "REComposeViewController.h"
#import "SVModalWebViewController.h"
#import "MTStatusBarOverlay.h"
#import "AFNetworking.h"


#define _REPLY_PER_PAGE 30


@interface S1ContentViewController () <UIWebViewDelegate, UIScrollViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIView *maskView;
@property (nonatomic, strong) UIView *statusBackgroundView;
@property (nonatomic, strong) UILabel *pageLabel;

@property (nonatomic, strong) REComposeViewController *replyController;

@end

@implementation S1ContentViewController {
    NSInteger _currentPage;
    NSInteger _totalPages;
    
    BOOL _needToScrollToBottom;
    NSURL *_urlToOpen;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _webView = [[UIWebView alloc] init];
        [_webView loadHTMLString:@"<html><body style=\"background-color:#f6f7e7;\"></body></html>" baseURL:nil];
        _currentPage = 1;
        _needToScrollToBottom = NO;
    }
    return self;
}

- (void)viewDidLoad
{
#define _BAR_HEIGHT 44.0f
#define _STATUS_BAR_HEIGHT 20.0f
    
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        self.webView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - _BAR_HEIGHT);
    } else {
        self.statusBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, _STATUS_BAR_HEIGHT)];
        self.statusBackgroundView.backgroundColor = [S1GlobalVariables color5];
        self.statusBackgroundView.userInteractionEnabled = NO;
        [self.view addSubview:self.statusBackgroundView];
                
        self.webView.frame = CGRectMake(0, _STATUS_BAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height - _BAR_HEIGHT - _STATUS_BAR_HEIGHT);
    }
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.webView.delegate = self;
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.webView.scrollView.scrollsToTop = YES;
    self.webView.scrollView.delegate = self;
    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        self.webView.backgroundColor = [S1GlobalVariables color6];
    } else {
        self.webView.backgroundColor = [S1GlobalVariables color5];
    }
    [self.view addSubview:self.webView];
    
    self.maskView = [[UIView alloc] initWithFrame:self.webView.bounds];
    self.maskView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.maskView.backgroundColor = [S1GlobalVariables color5];
    self.maskView.userInteractionEnabled = NO;
    [self.webView addSubview:self.maskView];
    
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.frame = CGRectMake(0, self.view.bounds.size.height-44.0f, self.view.bounds.size.width, 44.0f);
    self.toolbar.tintColor = [S1GlobalVariables color3];
    self.toolbar.alpha = 1.0;
    

    UIButton *button = nil;
    
    
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setImage:[UIImage imageNamed:@"Back.png"] forState:UIControlStateNormal];
        [button setShowsTouchWhenHighlighted:YES];
    } else {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setImage:[UIImage imageNamed:@"Back_iOS7.png"] forState:UIControlStateNormal];
    }
    button.frame = CGRectMake(0, 0, 30, 30);
    [button addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    [button setTag:99];
    UILongPressGestureRecognizer *backLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backLongPressed:)];
    backLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:backLongPressGR];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:button];    
    
    
    
    
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setImage:[UIImage imageNamed:@"Forward.png"] forState:UIControlStateNormal];
        [button setShowsTouchWhenHighlighted:YES];
    } else {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setImage:[UIImage imageNamed:@"Forward_iOS7.png"] forState:UIControlStateNormal];
    }
    button.frame = CGRectMake(0, 0, 30, 30);
    [button addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
    [button setTag:100];
    UILongPressGestureRecognizer *forwardLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardLongPressed:)];
    forwardLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:forwardLongPressGR];
    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    self.pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
    self.pageLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        self.pageLabel.textColor = [UIColor whiteColor];
    } else {
        self.pageLabel.textColor = [S1GlobalVariables color3];
    }
    self.pageLabel.backgroundColor = [UIColor clearColor];
    self.pageLabel.textAlignment = NSTextAlignmentCenter;
    [self updatePageLabel];
    
    UIBarButtonItem *labelItem = [[UIBarButtonItem alloc] initWithCustomView:self.pageLabel];
    labelItem.width = 80;
    
    
    UIBarButtonItem *actionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 36.0f;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.toolbar setItems:@[backItem, fixItem, forwardItem, flexItem, labelItem, flexItem, actionItem]];
    
    [self.view addSubview:self.toolbar];
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.statusBackgroundView.autoresizesSubviews = YES;
    self.statusBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.toolbar.autoresizesSubviews = YES;
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
#undef _BAR_HEIGHT
    
    [UIView animateWithDuration:0.15 delay:0.1 options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.maskView.alpha = 0.0;
                     }
                     completion:^(BOOL finished) {
                         [self.maskView removeFromSuperview];
                         [self fetchContent];
                     }];
}

- (void)viewWillAppear:(BOOL)animated
{
    
}

- (void)viewDidAppear:(BOOL)animated
{
//    [self.webView.scrollView setScrollsToTop:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self cancelRequest];
    
    [self.topic setLastViewedPage:[NSNumber numberWithInteger: _currentPage]];
    [self.tracer hasViewed:self.topic];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setters and Getters

- (void)setTopic:(S1Topic *)topic
{
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
    if (_currentPage - 1 >= 1) {
        _currentPage -= 1;
        [self fetchContent];
    } else {
        [[self rootViewController] dismissDetailViewController];
    }
}

- (void)forward:(id)sender
{
    [self cancelRequest];
    if (_currentPage + 1 <= _totalPages) {
        _currentPage += 1;
        [self fetchContent];
    } else {
        if (![self atBottom]) {
            [self scrollToButtomAnimated:YES];
        } else {
            [self fetchContent];
            _needToScrollToBottom = YES;
        }
    }
}

- (void)backLongPressed:(UIGestureRecognizer *)gr
{
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
    if (gr.state == UIGestureRecognizerStateBegan) {
        if (_currentPage < _totalPages) {
            _currentPage = _totalPages;
            [self cancelRequest];
            [self fetchContent];
        }
    }
}

- (void)action:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel")
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedString(@"ContentView_ActionSheet_Reply", @"Reply"),
                                  [self.tracer topicIsFavorited:self.topic.topicID]?NSLocalizedString(@"ContentView_ActionSheet_Cancel_Favorite", @"Cancel Favorite"):NSLocalizedString(@"ContentView_ActionSheet_Favorite", @"Favorite"),
                                  NSLocalizedString(@"ContentView_ActionSheet_Weibo", @"Weibo"),
                                  NSLocalizedString(@"ContentView_ActionSheet_OriginPage", @"Origin"), nil];
    actionSheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [actionSheet showFromToolbar:self.toolbar];    
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
//    NSLog(@"%d", buttonIndex);
    //Reply
    if (0 == buttonIndex) {
        if (![[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"]) {
            [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ContentView_Reply_Need_Login_Message", @"Need Login in Settings") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"OK") otherButtonTitles:nil] show];
            return;
        }
        [self rootViewController].modalPresentationStyle = UIModalPresentationCurrentContext;
        if (!self.replyController) {
            self.replyController = [[REComposeViewController alloc] init];
            REComposeViewController *replyController = self.replyController;
            replyController.title = NSLocalizedString(@"ContentView_Reply_Title", @"Reply");
            
            
            [replyController setCompletionHandler:^(REComposeViewController *composeViewController, REComposeResult result){
                if (result == REComposeResultCancelled) {
                    [composeViewController dismissViewControllerAnimated:YES completion:nil];
                }
                else if (result == REComposeResultPosted) {
                    if (composeViewController.text.length > 0) {
                        [self replyWithTextInDiscuz:composeViewController.text];
                        [composeViewController dismissViewControllerAnimated:YES completion:nil];
                    }
                }
            }];
        
        }
        [self.replyController.view setFrame:self.view.bounds];
        [self.replyController presentFromViewController:self];
        //[self presentViewController:replyController animated:NO completion:nil];
    }
    //Favorite
    if (1 == buttonIndex) {
        [self.tracer setTopicFavoriteState:self.topic.topicID withState:(![self.tracer topicIsFavorited:self.topic.topicID])];
    }
    
    //Weibo
    if (2 == buttonIndex) {
        if (!NSClassFromString(@"SLComposeViewController")) {
            [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ContentView_Need_Weibo_Service_Support_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"OK") otherButtonTitles:nil] show];
            return;
        }
        SLComposeViewController *controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
        if (!controller) {
            [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ContentView_Need_Chinese_Keyboard_To_Open_Weibo_Service_Message", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Message_OK", @"OK") otherButtonTitles:nil] show];
            return;
        }
        [controller setInitialText:[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.topic.title]];
        [controller addURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@thread-%@-1-1.html", [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID]]];
        [controller addImage:[self screenShot]];
        
        __weak SLComposeViewController *weakController = controller;
        [self presentViewController:controller animated:YES completion:nil];
        [controller setCompletionHandler:^(SLComposeViewControllerResult result){
            [weakController dismissViewControllerAnimated:YES completion:nil];
        }];
    }
    
    if (3 == buttonIndex) {
        //[self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
        SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:[NSString stringWithFormat:@"%@thread-%@-%d-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, _currentPage]];
        
        if (SYSTEM_VERSION_LESS_THAN(@"7")) {
            ;
        } else {
            controller.modalPresentationStyle = UIModalPresentationPageSheet;
            [[controller view] setTintColor:[S1GlobalVariables color3]];
        }
        
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (1 == buttonIndex) {
        NSLog(@"%@", _urlToOpen);
        SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:_urlToOpen.absoluteString];
        if (SYSTEM_VERSION_LESS_THAN(@"7")) {
            ;
        } else {
            [[controller view] setTintColor:[S1GlobalVariables color3]];
        }
        [self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:controller animated:YES completion:nil];        
    }
}

#pragma mark - UIWebView Delegate


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        return YES;
    }
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString delegate:self cancelButtonTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") otherButtonTitles:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @""), nil];
    _urlToOpen = request.URL;
    [alertView show];
    return NO;
//    NSLog(@"Request: %@", request.URL.absoluteString);
//    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_needToScrollToBottom) {
        [self scrollToButtomAnimated:YES];
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
    NSString *path;
    if (_currentPage == 1) {
        path = [NSString stringWithFormat:@"forum.php?mod=viewthread&tid=%@&mobile=no", self.topic.topicID];
    } else {
        path = [NSString stringWithFormat:@"forum.php?mod=viewthread&tid=%@&page=%d&mobile=no", self.topic.topicID, _currentPage];
    }
    NSLog(@"Begin Fetch Content");
    NSDate *start = [NSDate date];
    
    [self.HTTPClient getPath:path
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                         //NSLog(@"%@", operation.request.allHTTPHeaderFields);
                         NSTimeInterval timeInterval = [start timeIntervalSinceNow];
                         NSLog(@"Finish Fetch Content time elapsed:%f",-timeInterval);
                         NSString *string = [S1Parser contentsFromHTMLData:responseObject withOffset:_currentPage];
                         NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                         [self.topic setFormhash:[S1Parser formhashFromThreadString:HTMLString]];
                         if (_currentPage == 1) {
                             NSInteger parsedReplyCount =[S1Parser replyCountFromThreadString:HTMLString];
                             if (parsedReplyCount != 0) {
                                 [self.topic setReplyCount:[NSNumber numberWithInteger:parsedReplyCount]];
                             }
                         }
                         NSInteger parsedTotalPages = [S1Parser totalPagesFromThreadString:HTMLString];
                         if (parsedTotalPages != 0) {
                             _totalPages = parsedTotalPages;
                             [self updatePageLabel];
                         }
                         //check login state
                         if (![S1Parser checkLoginState:HTMLString])
                         {
                             [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"InLoginStateID"];
                         }
                         [self.webView loadHTMLString:string baseURL:nil];
                         [HUD hideWithDelay:0.5];
                     }
                     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                         NSLog(@"%@", error);
                         if (error.code == -999) {
                             NSLog(@"Code -999 may means user want to cancel this request.");
                             [HUD hideWithDelay:0];
                         } else {
                             [HUD showRefreshButton];
                         }
                         
                     }];
}

- (void)replyWithTextInDiscuz:(NSString *)text
{
    MTStatusBarOverlay *overlay = [MTStatusBarOverlay sharedInstance];
    overlay.animation = MTStatusBarOverlayAnimationShrink;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    BOOL appendSuffix = [[NSUserDefaults standardUserDefaults] boolForKey:@"AppendSuffix"];
    NSString *suffix = appendSuffix?@"\n\n——— 来自[url=http://itunes.apple.com/us/app/stage1st-reader/id509916119?mt=8]Stage1st Reader For iOS[/url]":@"";
    NSString *replyWithSuffix = [text stringByAppendingString:suffix];
    NSString *timestamp = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970])];
    NSString *path = [NSString stringWithFormat:@"forum.php?mod=post&action=reply&fid=%@&tid=%@&extra=page%%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost&inajax=1", self.topic.fID, self.topic.topicID];
    NSDictionary *params = @{@"message" : replyWithSuffix,
                             @"posttime" : timestamp,
                             @"formhash" : self.topic.formhash,
                             @"usesig" : @"1",
                             @"subject" : @"",
                             };
    __weak typeof(self) myself = self;
    [self.HTTPClient postPath:path
                   parameters:params
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          NSString *HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                          NSLog(@"%@", HTMLString);
                          [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                          if (SYSTEM_VERSION_LESS_THAN(@"7")) {
                              [overlay postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                          }
                          _needToScrollToBottom = YES;
                          [myself fetchContent];
                      }
                      failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                          [overlay postErrorMessage:@"回复可能未成功" duration:2.5 animated:YES];
                      }];

}

-(void) cancelRequest
{
    NSString *path = [NSString stringWithFormat:@"forum.php"];
    [self.HTTPClient cancelAllHTTPOperationsWithMethod:@"GET" path:path];
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
    self.pageLabel.text = [NSString stringWithFormat:@"%d/%d", _currentPage, _totalPages];
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
    UIGraphicsBeginImageContext(self.view.bounds.size);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return viewImage;
}

-(void)viewDidLayoutSubviews
{
    //NSLog(@"layout called");
    NSNotification *notification = [NSNotification notificationWithName:@"S1ContentViewAutoLayoutedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

@end
