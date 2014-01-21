//
//  S1TopicListViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TopicListViewController.h"
#import "S1ContentViewController.h"
#import "S1RootViewController.h"
#import "S1SettingViewController.h"
#import "S1HTTPClient.h"
#import "S1Parser.h"
#import "S1TopicCell.h"
#import "S1TopicListCell.h"
#import "S1HUD.h"
#import "S1Topic.h"
#import "S1TabBar.h"
#import "S1Tracer.h"

#import "ODRefreshControl.h"
#import "AFNetworking.h"

static NSString * const cellIdentifier = @"TopicCell";

@interface S1TopicListViewController () <UITableViewDelegate, UITableViewDataSource, S1TabBarDelegate>

@property (nonatomic, strong) UINavigationBar *navigationBar;
@property (nonatomic, strong) UINavigationItem *naviItem;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) ODRefreshControl *refreshControl;
@property (nonatomic, strong) S1TabBar *scrollTabBar;

@property (nonatomic, strong) S1Tracer *tracer;
@property (nonatomic, strong) NSString *currentKey;
@property (nonatomic, strong) NSArray *topics;
@property (nonatomic, strong) NSMutableDictionary *cache;
@property (nonatomic, strong) NSDictionary *threadsInfo;
@property (nonatomic, strong) S1HTTPClient *HTTPClient;

@end

@implementation S1TopicListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
#define _BAR_HEIGHT 44.0f
#define _UPPER_BAR_HEIGHT 64.0f
    
    [super viewDidLoad];
    self.tracer = [[S1Tracer alloc] initWithTracerName:@"RecentViewed_3_1.tracer"];
    self.tracer.identifyKey = @"topicID";
    self.tracer.timeStampKey = @"lastViewedDate";
    
    self.view.backgroundColor = [UIColor colorWithRed: 0.96 green: 0.97 blue: 0.92 alpha: 1];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, _UPPER_BAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height-_BAR_HEIGHT-_UPPER_BAR_HEIGHT) style:UITableViewStylePlain];
    self.tableView.autoresizesSubviews = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.tableView.rowHeight = 54.0f;
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorColor = [UIColor colorWithRed:0.82 green:0.85 blue:0.76 alpha:1.0];
    self.tableView.backgroundColor = [UIColor colorWithRed: 0.96 green: 0.97 blue: 0.92 alpha: 1];
    self.tableView.hidden = YES;
    [self.view addSubview:self.tableView];
    
    self.refreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    self.refreshControl.tintColor = [UIColor colorWithRed: 0.92 green: 0.92 blue: 0.86 alpha: 1];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    self.navigationBar = [[UINavigationBar alloc] init];
    self.navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, _UPPER_BAR_HEIGHT);
    self.navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Stage1st"];
    self.naviItem = item;
    UIBarButtonItem *settingItem = [[UIBarButtonItem alloc] initWithTitle:@"设置" style:UIBarButtonItemStyleBordered target:self action:@selector(settings:)];
    item.leftBarButtonItem = settingItem;
    UIBarButtonItem *recentItem = [[UIBarButtonItem alloc] initWithTitle:@"最近" style:UIBarButtonItemStyleBordered target:self action:@selector(recent:)];
    item.rightBarButtonItem = recentItem;
    [self.navigationBar pushNavigationItem:item animated:NO];
    [self.view addSubview:self.navigationBar];
    
    
    self.scrollTabBar = [[S1TabBar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-_BAR_HEIGHT, self.view.bounds.size.width, _BAR_HEIGHT) andKeys:[self keys]];
    self.scrollTabBar.tabbarDelegate = self;
        
    [self.view addSubview:self.scrollTabBar];
    
    //Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabbar:) name:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateHTTPClient:) name:@"S1BaseURLMayChangedNotification" object:nil];
#undef _BAR_HEIGHT
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![[self rootViewController] presentingDetailViewController]) {
        [self.tableView setUserInteractionEnabled:YES];
        [self.tableView setScrollsToTop:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.tableView setUserInteractionEnabled:NO];
    [self.tableView setScrollsToTop:NO];

    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    self.cache = nil;
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"S1BaseURLMayChangedNotification" object:nil];
}

#pragma mark - Getters and Setters

- (NSDictionary *)threadsInfo
{
    if (_threadsInfo)
        return _threadsInfo;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Threads" ofType:@"plist"];
    _threadsInfo = [NSDictionary dictionaryWithContentsOfFile:path];
    return _threadsInfo;
}

- (NSMutableDictionary *)cache
{
    if (_cache)
        return _cache;
    _cache = [NSMutableDictionary dictionary];
    return _cache;
}

- (S1HTTPClient *)HTTPClient
{
    if (_HTTPClient) return _HTTPClient;
    NSString *baseURLString = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
    _HTTPClient = [[S1HTTPClient alloc] initWithBaseURL:[NSURL URLWithString:[baseURLString stringByAppendingString:@"/2b/"]]];
    return _HTTPClient;
}

#pragma mark - Item Actions

- (void)settings:(id)sender
{
    [self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
    S1SettingViewController *controller = [[S1SettingViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *controllerToPresent = [[UINavigationController alloc] initWithRootViewController:controller];
    [self presentViewController:controllerToPresent animated:YES completion:nil];
}

- (void)recent:(id)sender
{
    self.naviItem.title = @"Recent";
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;        
    }
    self.refreshControl.hidden = YES;
    
    self.topics = [self.tracer recentViewedObjects];
    [self.tableView reloadData];
    if (self.topics && self.topics.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
    [self.scrollTabBar deselectAll];
    self.currentKey = @"";
}

- (void)refresh:(id)sender
{
    if (self.refreshControl.hidden) {
        [self.refreshControl endRefreshing];
        return;
    }
    
    if (self.scrollTabBar.enabled) {
        [self fetchTopicsForKeyFromServer:self.currentKey scrollToTop:NO];
    } else {
        [self.refreshControl endRefreshing];
    }
}

#pragma mark - Tab Bar Delegate

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key
{
    self.naviItem.title = @"Stage1st";
    
    if (self.tableView.hidden) {
        self.tableView.hidden = NO;
    }
    if (self.refreshControl.hidden) {
        self.refreshControl.hidden = NO;
    }
    
    if (![self.currentKey isEqualToString:key]) {
        self.currentKey = key;
        [self fetchTopicsForKey:key];
        if (self.refreshControl.refreshing) {
            [self.refreshControl endRefreshing];
        }
    } else {
        [self fetchTopicsForKeyFromServer:key scrollToTop:YES];
    }
}



#pragma mark - Networking

- (void)fetchTopicsForKey:(NSString *)key
{
    if (self.cache[key]) {
        self.topics = self.cache[key];
        [self.tableView reloadData];
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        return;
    }
    [self fetchTopicsForKeyFromServer:key scrollToTop:YES];
}

- (void)fetchTopicsForKeyFromServer:(NSString *)key scrollToTop:(BOOL)toTop
{
    self.scrollTabBar.enabled = NO;
    S1HUD *HUD = [S1HUD showHUDInView:self.view];
    [HUD showActivityIndicator];
    NSString *path = [NSString stringWithFormat:@"archiver/fid-%@.html", self.threadsInfo[key]];
    NSString *fid = self.threadsInfo[key];
    [self.HTTPClient getPath:path
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                        NSString *HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                        if (HTMLString) {
                            NSArray *topics = [S1Parser topicsFromHTMLString:HTMLString withContext:@{@"FID": fid}];
                            if (topics.count > 0) {
                                self.topics = topics;
                                self.cache[key] = topics;
                                [self.tableView reloadData];
                                if (toTop) {
                                    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
                                }
                            }
                        }
                        if (self.refreshControl.refreshing) {
                            [self.refreshControl endRefreshing];
                        }
                        [HUD hideWithDelay:0.3];
                        self.scrollTabBar.enabled = YES;
                         
                     }
                     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                        [HUD setText:@"Request Failed"];
                        [HUD hideWithDelay:0.3];
                        self.scrollTabBar.enabled = YES;
                        if (self.refreshControl.refreshing) {
                            [self.refreshControl endRefreshing];
                        }
                     }];
}


#pragma mark - UITableView


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.topics count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    S1TopicListCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[S1TopicListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell setTopic:self.topics[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    S1ContentViewController *controller = [[S1ContentViewController alloc] init];
    S1Topic *topicToShow = self.topics[indexPath.row];
    S1Topic *tracedTopic = [self.tracer objectInRecentForKey:topicToShow.topicID];
    if (tracedTopic) {
        topicToShow.lastViewedPage = tracedTopic.lastViewedPage;
    }
    [controller setTopic:topicToShow];
    [controller setTracer:self.tracer];
    [controller setHTTPClient:self.HTTPClient];
    
    [[self rootViewController] presentDetailViewController:controller];
}

#pragma mark - Helpers

- (S1RootViewController *)rootViewController
{
    UIViewController *controller = [self parentViewController];
    while (![controller isKindOfClass:[S1RootViewController class]] || !controller) {
        controller = [controller parentViewController];
    }
    return (S1RootViewController *)controller;
}

- (NSArray *)keys
{
    return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"] objectAtIndex:0];
}

- (void)updateTabbar:(id)sender
{
    [self.scrollTabBar setKeys:[self keys]];
    self.tableView.hidden = YES;
    self.topics = [NSArray array];
    [self.tableView reloadData];
    self.currentKey = nil;
    self.cache = nil;
}

- (void)updateHTTPClient:(id)sender
{
    self.HTTPClient = nil;
}

@end
