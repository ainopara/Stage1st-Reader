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
#import "S1Floor.h"
#import "S1Parser.h"
#import "S1Tracer.h"
#import "S1HUD.h"
#import "REComposeViewController.h"
#import "SVModalWebViewController.h"
#import "MTStatusBarOverlay.h"
#import "AFNetworking.h"
#import "ActionSheetStringPicker.h"
#import "JTSSimpleImageDownloader.h"
#import "JTSImageViewController.h"


#define _REPLY_PER_PAGE 30


@interface S1ContentViewController () <UIWebViewDelegate, UIScrollViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, JTSImageViewControllerInteractionsDelegate>

@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIView *statusBackgroundView; //for iOS7 and above
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, weak) JTSImageViewController *imageViewer;

@property (nonatomic, strong) REComposeViewController *replyController;

@end

@implementation S1ContentViewController {
    NSInteger _currentPage;
    NSInteger _totalPages;
    
    BOOL _needToScrollToBottom;
    BOOL _needToLoadLastPosition;
    BOOL _finishLoading;
    NSURL *_urlToOpen;
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
    }
    return self;
}

- (void)viewDidLoad
{
#define _BAR_HEIGHT 44.0f
#define _STATUS_BAR_HEIGHT 20.0f
    
    [super viewDidLoad];
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTopicViewedState:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self fetchContent];
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self cancelRequest];
        
        if (_finishLoading) {
            [self.topic setLastViewedPosition:[NSNumber numberWithFloat: self.webView.scrollView.contentOffset.y]];
        } else if ((self.topic.lastViewedPosition == nil) || (![self.topic.lastViewedPage isEqualToNumber:[NSNumber numberWithInteger: _currentPage]])) {
            [self.topic setLastViewedPosition:[NSNumber numberWithFloat: 0.0]];
        }
        [self.topic setLastViewedPage:[NSNumber numberWithInteger: _currentPage]];
        [self.topic setFavorite:[NSNumber numberWithBool:[self.tracer topicIsFavorited:self.topic.topicID]]];
        [self.topic setLastReplyCount:self.topic.replyCount];
        [self.tracer hasViewed:self.topic];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotification *notification = [NSNotification notificationWithName:@"S1ContentViewWillDisappearNotification" object:nil];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        });
        
    });
    
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
            [self fetchContent];
            _needToScrollToBottom = YES;
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
    for (long i = 0; i < _totalPages; i++) {
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
}

#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
//    NSLog(@"%d", buttonIndex);
    if (self.imageViewer) {
        if (0 == buttonIndex) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImageWriteToSavedPhotosAlbum(self.imageViewer.image, nil, nil, nil);
            });
        }
        //Favorite
        if (1 == buttonIndex) {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = self.imageViewer.imageInfo.imageURL.absoluteString;
        }
    } else {
        //Reply
        if (0 == buttonIndex) {
            [self presentReplyViewWithAppendText:@"" reply:nil];
            //[self presentViewController:replyController animated:NO completion:nil];
        }
        //Favorite
        if (1 == buttonIndex) {
            [self.tracer setTopicFavoriteState:self.topic.topicID withState:(![self.tracer topicIsFavorited:self.topic.topicID])];
        }
        
        //Weibo
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
        
        if (3 == buttonIndex) {
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !SYSTEM_VERSION_LESS_THAN(@"8")) {
                NSLog(@"special");
                [self dismissViewControllerAnimated:NO completion:^(void){
                    NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
                    SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:pageAddress];
                    [controller.view setTintColor:[S1GlobalVariables color3]];
                    [self presentViewController:controller animated:YES completion:nil];
                }];
            } else {
                NSString *pageAddress = [NSString stringWithFormat:@"%@thread-%@-%ld-1.html",[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"], self.topic.topicID, (long)_currentPage];
                SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:pageAddress];
                [controller.view setTintColor:[S1GlobalVariables color3]];
                [self presentViewController:controller animated:YES completion:nil];
            }
        }
    }
    
}

#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (1 == buttonIndex) {
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
    //load
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        return YES;
    }
    //reply
    if ([request.URL.absoluteString hasPrefix:@"applewebdata://"]) {
        if ([request.URL.path isEqualToString:@"/reply"]) {
            for (S1Floor * topicFloor in _topicFloors) {
                NSString *decodedQuery = [request.URL.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                if ([decodedQuery isEqualToString:topicFloor.indexMark]) {
                    NSLog(@"%@", topicFloor.author);
                    [self presentReplyViewWithAppendText:nil reply:topicFloor];
                }
            }
        }
        if ([request.URL.path hasPrefix:@"/present-image:"]) {
            NSString *imageURL = [request.URL.path stringByReplacingCharactersInRange:NSRangeFromString(@"0 15") withString:@""];
            NSLog(@"%@", imageURL);
            JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
            imageInfo.imageURL = [[NSURL alloc] initWithString:imageURL];
            imageInfo.referenceRect = self.webView.frame;
            imageInfo.referenceView = self.webView;
            JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                                   initWithImageInfo:imageInfo
                                                   mode:JTSImageViewControllerMode_Image
                                                   backgroundStyle:JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred];
            [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOffscreen];
            [imageViewer setInteractionsDelegate:self];
        }
        return NO;
    }
    //open link
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString delegate:self cancelButtonTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") otherButtonTitles:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @""), nil];
        _urlToOpen = request.URL;
        [alertView show];
    } else {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Title", @"") message:request.URL.absoluteString preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Cancel", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        UIAlertAction* continueAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ContentView_WebView_Open_Link_Alert_Open", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            _urlToOpen = request.URL;
            NSLog(@"%@", _urlToOpen);
            SVModalWebViewController *controller = [[SVModalWebViewController alloc] initWithAddress:_urlToOpen.absoluteString];
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
- (void)imageViewerDidLongPress:(JTSImageViewController *)imageViewer {
    self.imageViewer = imageViewer;
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"ContentView_ActionSheet_Cancel", @"Cancel")
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedString(@"ImageViewer_ActionSheet_Save", @"Save"),NSLocalizedString(@"ImageViewer_ActionSheet_CopyURL", @"Copy URL"), nil];
    //actionSheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [actionSheet showInView:imageViewer.view];
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
        path = [NSString stringWithFormat:@"forum.php?mod=viewthread&tid=%@&page=%ld&mobile=no", self.topic.topicID, (long)_currentPage];
    }
    // NSLog(@"Begin Fetch Content");
    NSDate *start = [NSDate date];
    
    [self.HTTPClient GET:path parameters:nil
                     success:^(NSURLSessionDataTask *operation, id responseObject) {
                         //NSLog(@"%@", operation.request.allHTTPHeaderFields);
                         NSTimeInterval timeInterval = [start timeIntervalSinceNow];
                         NSLog(@"Finish Fetch Content time elapsed:%f",-timeInterval);
                         NSArray *floorList = [S1Parser contentsFromHTMLData:responseObject withOffset:_currentPage];
                         _topicFloors = floorList;
                         NSString *string = [S1Parser generateContentPage:floorList withTopic:self.topic];
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
                         [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
                         
                         [self.webView loadHTMLString:string baseURL:nil];
                         _finishLoading = YES;
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [HUD hideWithDelay:0.3];
                         });
                     }
                     failure:^(NSURLSessionDataTask *operation, NSError *error) {
                         if (error.code == -999) {
                             NSLog(@"request cancelled.");
                             [HUD hideWithDelay:0];
                         } else {
                             NSLog(@"%@", error);
                             [HUD showRefreshButton];
                         }
                     }];
}

- (void)replyWithTextInDiscuz:(NSString *)text withPath:(NSString *)path andParams:(NSMutableDictionary *)params
{
    MTStatusBarOverlay *overlay = [MTStatusBarOverlay sharedInstance];
    overlay.animation = MTStatusBarOverlayAnimationNone;
    [overlay postMessage:@"回复发送中" animated:YES];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    BOOL appendSuffix = [[NSUserDefaults standardUserDefaults] boolForKey:@"AppendSuffix"];
    NSString *suffix = appendSuffix?@"\n\n——— 来自[url=http://itunes.apple.com/us/app/stage1st-reader/id509916119?mt=8]Stage1st Reader For iOS[/url]":@"";
    NSString *replyWithSuffix = [text stringByAppendingString:suffix];
    [params setObject:replyWithSuffix forKey:@"message"];
    __weak typeof(self) myself = self;
    [self.HTTPClient POST:path parameters:params
                  success:^(NSURLSessionDataTask *operation, id responseObject) {
                      NSString *HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                      NSLog(@"%@", HTMLString);
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                          [overlay postFinishMessage:@"回复成功" duration:2.5 animated:YES];
                          _needToScrollToBottom = YES;
                          [myself.replyController setText:@""];
                          [myself fetchContent];
                      });
                  }
                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                          if (error.code == -999) {
                              NSLog(@"Code -999 may means user want to cancel this request.");
                              [overlay postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
                          } else {
                              [overlay postErrorMessage:@"回复可能未成功" duration:2.5 animated:YES];
                          }
                      });
                  }];

}

-(void)replySepecificFloor:(S1Floor *)topicFloor withText:(NSString *)text
{
    NSString *pathTemplate = @"forum.php?mod=post&action=reply&fid=%@&tid=%@&repquote=%@&extra=&page=%ld&infloat=yes&handlekey=reply&inajax=1&ajaxtarget=fwin_content_reply";
    NSString *path = [NSString stringWithFormat:pathTemplate, self.topic.fID, self.topic.topicID, topicFloor.floorID, (long)_currentPage];
    
    MTStatusBarOverlay *overlay = [MTStatusBarOverlay sharedInstance];
    [self.HTTPClient GET:path parameters:nil
                 success:^(NSURLSessionDataTask *operation, id responseObject) {
                     NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                     NSMutableDictionary *params = [S1Parser replyFloorInfoFromResponseString:responseString];
                     if ([params[@"requestSuccess"]  isEqual: @YES]) {
                         [params removeObjectForKey:@"requestSuccess"];
                         [params setObject:@"true" forKey:@"replysubmit"];
                         NSString *postPathTemplate = @"forum.php?mod=post&infloat=yes&action=reply&fid=%@&extra=page%%3D%ld&tid=%@&replysubmit=yes&inajax=1";
                         NSString *postPath = [NSString stringWithFormat:postPathTemplate, self.topic.fID, (long)_currentPage, self.topic.topicID];
                         [self replyWithTextInDiscuz:text withPath:postPath andParams:params];
                     } else {
                         NSLog(@"fail to fetch reply info!");
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [overlay postErrorMessage:@"引用信息无效" duration:2.5 animated:YES];
                         });
                     }

                 }
                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
                     NSLog(@"fail to fetch reply info!");
                     dispatch_async(dispatch_get_main_queue(), ^{
                         if (error.code == -999) {
                             NSLog(@"Code -999 may means user want to cancel this request.");
                             [overlay postErrorMessage:@"回复请求取消" duration:1.0 animated:YES];
                         } else {
                             [overlay postErrorMessage:@"网络连接失败" duration:2.5 animated:YES];
                         }
                     });
                 }];
}

-(void) cancelRequest
{
    [[self.HTTPClient session] getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        // NSLog(@"%lu,%lu,%lu",(unsigned long)dataTasks.count, (unsigned long)uploadTasks.count, (unsigned long)downloadTasks.count);
        for (NSURLSessionDataTask* task in downloadTasks) {
            [task cancel];
        }
    }];
    
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
    [replyController setCompletionHandler:^(REComposeViewController *composeViewController, REComposeResult result){
        if (result == REComposeResultCancelled) {
            [composeViewController dismissViewControllerAnimated:YES completion:nil];
        } else if (result == REComposeResultPosted) {
            if (composeViewController.text.length > 0) {
                if (topicFloor) {
                    [self replySepecificFloor:topicFloor withText:composeViewController.text];
                } else {
                    NSString *timestamp = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970])];
                    NSString *path = [NSString stringWithFormat:@"forum.php?mod=post&action=reply&fid=%@&tid=%@&extra=page%%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost&inajax=1", self.topic.fID, self.topic.topicID];
                    NSMutableDictionary *params = [@{@"posttime" : timestamp,
                                                     @"formhash" : self.topic.formhash,
                                                     @"usesig" : @"1",
                                                     @"subject" : @"",
                                                     } mutableCopy];
                    [self replyWithTextInDiscuz:composeViewController.text withPath:path andParams:params];
                }
                [composeViewController dismissViewControllerAnimated:YES completion:nil];
            }
        }
    }];
    
    [self.replyController setText:[self.replyController.text stringByAppendingString:replyDraft]];
    [self.replyController.view setFrame:self.view.bounds];
    [self.replyController presentFromViewController:self];
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
    [self.tracer hasViewed:self.topic];
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
@end
