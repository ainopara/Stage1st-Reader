//
//  S1ContentViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#define _URL_PATTERN @"http://bbs.saraba1st.com/2b/simple/?t%@.html"

#import "S1ContentViewController.h"
#import "S1HTTPClient.h"
#import "S1Topic.h"
#import "S1Parser.h"
#import "S1HUD.h"


@interface S1ContentViewController () <UIWebViewDelegate, UIScrollViewDelegate>

@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIView *maskView;

@end

@implementation S1ContentViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _webView = [[UIWebView alloc] init];

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
//    self.webView.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 44, 0);
//    self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 44, 0);
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
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Back.png"] style:UIBarButtonItemStylePlain target:self action:@selector(back:)];
    backItem.imageInsets = UIEdgeInsetsMake(1, 0, -1, 0);
    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Forward.png"] style:UIBarButtonItemStylePlain target:self action:@selector(forward:)];
    forwardItem.imageInsets = UIEdgeInsetsMake(1, 0, -1, 0);
    UIBarButtonItem *actionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
    UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixItem.width = 36.0f;
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.toolbar setItems:@[backItem, fixItem, forwardItem, flexItem, actionItem]];
    
    [self.view addSubview:self.toolbar];
    
#undef _BAR_HEIGHT
}

- (void)viewWillAppear:(BOOL)animated
{
    NSAssert(self.topic != nil, @"topic object can not be nil");
    [self fetchContent];

}

- (void)viewDidAppear:(BOOL)animated
{
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Bar Button Actions

- (void)back:(id)sender
{
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    }
    
}

- (void)forward:(id)sender
{
    
    
}

- (void)action:(id)sender
{
    
}

#pragma mark - UIWebView Delegate


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        return YES;
    }
    return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIView animateWithDuration:0.8 animations:^{
        self.maskView.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.maskView.hidden = YES;
    }];
}

#pragma mark - UIScrollView Delegate

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    return YES;
}

#pragma mark - Networking

- (void)fetchContent
{
    S1HUD *HUD = [S1HUD showHUDInView:self.webView];
    NSString *path = [NSString stringWithFormat:@"?t%@.html", self.topic.topicID];
    [[S1HTTPClient sharedClient] getPath:path
                              parameters:nil
                                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                     NSMutableString *HTMLString = [[NSMutableString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                     if (HTMLString) {
                                         NSString *string = [S1Parser contentsFromHTMLString:HTMLString];
                                         [self.webView loadHTMLString:string baseURL:nil];
                                     }
                                     [HUD hideWithDelay:0.5];
                                 }
                                 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                     NSLog(@"%@", error);
                                     [HUD hideWithDelay:0.5];
                                 }];
}


@end
