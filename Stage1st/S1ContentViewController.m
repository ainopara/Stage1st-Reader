//
//  S1ContentViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#define _URL_PATTERN @"http://bbs.saraba1st.com/2b/simple/?t%@.html"

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


#define _REPLY_PER_PAGE 50
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


@interface S1ContentViewController () <UIWebViewDelegate, UIScrollViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIView *maskView;

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
    
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    self.webView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - _BAR_HEIGHT);
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.webView.delegate = self;
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    self.webView.scrollView.scrollsToTop = YES;
    self.webView.scrollView.delegate = self;
    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.webView.backgroundColor = [UIColor colorWithWhite:0.20f alpha:1.0f];
    [self.view addSubview:self.webView];
    
    self.maskView = [[UIView alloc] initWithFrame:self.webView.bounds];
    self.maskView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.maskView.backgroundColor = [UIColor colorWithRed:0.96 green:0.97 blue:0.90 alpha:1.0];
    self.maskView.userInteractionEnabled = NO;
    [self.webView addSubview:self.maskView];
    
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.frame = CGRectMake(0, self.view.bounds.size.height-44.0f, self.view.bounds.size.width, 44.0f);
    self.toolbar.tintColor = [UIColor colorWithWhite:0.10f alpha:1.0];
    self.toolbar.alpha = 1.0;
    

    UIButton *button = nil;
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 30, 30);
    [button setImage:[UIImage imageNamed:@"Back.png"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    [button setShowsTouchWhenHighlighted:YES];
    [button setTag:99];
    UILongPressGestureRecognizer *backLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backLongPressed:)];
    backLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:backLongPressGR];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:button];    
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 30, 30);
    [button setImage:[UIImage imageNamed:@"Forward.png"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(forward:) forControlEvents:UIControlEventTouchUpInside];
    [button setShowsTouchWhenHighlighted:YES];
    [button setTag:100];
    UILongPressGestureRecognizer *forwardLongPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardLongPressed:)];
    forwardLongPressGR.minimumPressDuration = 0.5;
    [button addGestureRecognizer:forwardLongPressGR];
    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    self.pageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
    self.pageLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    self.pageLabel.textColor = [UIColor whiteColor];
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
    NSString *path = [NSString stringWithFormat:@"simple/?t%@.html", self.topic.topicID];
    [[S1HTTPClient sharedClient] cancelAllHTTPOperationsWithMethod:@"GET" path:path];
    
    [self.topic setLastViewedPage:[NSString stringWithFormat:@"%d", _currentPage]];
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
    if (_currentPage - 1 >= 1) {
        _currentPage -= 1;
        [self fetchContent];
    } else {
        [[self rootViewController] dismissDetailViewController];
    }
}

- (void)forward:(id)sender
{
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
            [self fetchContent];
        }
    }
}

- (void)forwardLongPressed:(UIGestureRecognizer *)gr
{
    if (gr.state == UIGestureRecognizerStateBegan) {
        if (_currentPage < _totalPages) {
            _currentPage = _totalPages;
            [self fetchContent];
        }
    }
}

- (void)action:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"取消", @"Cancel")
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedString(@"回复", @"Reply"), NSLocalizedString(@"分享到微博", @"Weibo"), NSLocalizedString(@"打开原网页", @"Origin"), nil];
    actionSheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [actionSheet showFromToolbar:self.toolbar];    
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
//    NSLog(@"%d", buttonIndex);
    //Reply
    if (0 == buttonIndex) {
        if (![[NSUserDefaults standardUserDefaults] valueForKey:@"UserID"]) {
            [[[UIAlertView alloc] initWithTitle:@"请先获取登录状态" message:nil delegate:nil cancelButtonTitle:@"完成" otherButtonTitles:nil] show];
            return;
        }
        [self rootViewController].modalPresentationStyle = UIModalPresentationCurrentContext;
        if (!self.replyController) {
            self.replyController = [[REComposeViewController alloc] init];
        }
        REComposeViewController *replyController = self.replyController;
        replyController.title = NSLocalizedString(@"回复", @"Reply");
        replyController.navigationItem.leftBarButtonItem.title = @"取消";
        replyController.navigationItem.rightBarButtonItem.title = @"发送";
        
        
        [replyController setCompletionHandler:^(REComposeViewController *composeViewController, REComposeResult result){
            if (result == REComposeResultCancelled) {
                [composeViewController dismissViewControllerAnimated:NO completion:nil];
            }
            else if (result == REComposeResultPosted) {
                if (composeViewController.text.length > 0) {
                    [self replyWithReplyController:composeViewController];
                }
            }
        }];
        [self presentViewController:replyController animated:NO completion:nil];
    }
    //Weibo
    if (1 == buttonIndex) {
        if (!NSClassFromString(@"SLComposeViewController")) {
            [[[UIAlertView alloc] initWithTitle:@"需要6.0以上的系统才能使用" message:nil delegate:nil cancelButtonTitle:@"完成" otherButtonTitles:nil] show];
            return;
        }
        SLComposeViewController *controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
        [controller setInitialText:[NSString stringWithFormat:@"%@ #Stage1st Reader#", self.topic.title]];
        [controller addURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://bbs.saraba1st.com/2b/read-htm-tid-%@.html", self.topic.topicID]]];
        [controller addImage:[self screenShot]];
        
        __weak SLComposeViewController *weakController = controller;
        [self presentViewController:controller animated:YES completion:nil];
        [controller setCompletionHandler:^(SLComposeViewControllerResult result){
            [weakController dismissViewControllerAnimated:YES completion:nil];
        }];
    }
    
    if (2 == buttonIndex) {
        [self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
        SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:[NSString stringWithFormat:@"http://bbs.saraba1st.com/2b/read-htm-tid-%@.html", self.topic.topicID]];
        [self presentViewController:controller animated:YES completion:nil];        
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (1 == buttonIndex) {
        NSLog(@"%@", _urlToOpen);
        SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:_urlToOpen.absoluteString];
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
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"打开链接" message:request.URL.absoluteString delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"打开", nil];
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
    NSString *path = [NSString stringWithFormat:@"simple/?t%@_%d.html", self.topic.topicID, _currentPage];
    [[S1HTTPClient sharedClient] getPath:path
                              parameters:nil
                                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                     NSMutableString *HTMLString = [[NSMutableString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                     if (HTMLString) {
                                         NSString *string = [S1Parser contentsFromHTMLString:HTMLString withOffset:_currentPage];
                                         [self.webView loadHTMLString:string baseURL:nil];
                                     }
                                     [HUD hideWithDelay:0.5];
                                 }
                                 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                     NSLog(@"%@", error);
                                     [HUD showRefreshButton];
                                 }];
}

- (void)replyWithReplyController:(REComposeViewController *)composeViewController
{
    NSString *suffix = @"\n\n——— 来自Stage1st Reader Evolution";
    NSString *replyWithSuffix = [composeViewController.text stringByAppendingString:suffix];
    NSString *timestamp = [[NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]] substringToIndex:10];
    NSString *path = [NSString stringWithFormat:@"m/post.php?action=reply&tid=%@&tmp=%@", self.topic.topicID, timestamp];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.HTTPClient postPath:path
                   parameters:@{ @"fid":self.topic.fID, @"content":replyWithSuffix }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                              NSString *HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                              NSLog(@"Reply Response: %@", HTMLString);
                              if (_currentPage == _totalPages) {
                                  _needToScrollToBottom = YES;
                                  [self fetchContent];
                              }
                              [composeViewController dismissViewControllerAnimated:NO completion:nil];
                              [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                          
                      }
                      failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                              NSLog(@"%@", error);
                              [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                      }];
}

#pragma mark - Helpers

- (void)scrollToButtomAnimated:(BOOL)animated
{
    [self.webView.scrollView setContentOffset:CGPointMake(0, self.webView.scrollView.contentSize.height-self.webView.scrollView.bounds.size.height) animated:animated];
    _needToScrollToBottom = NO;
}

- (BOOL)atBottom;
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

@end
