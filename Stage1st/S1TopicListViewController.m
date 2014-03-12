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
@property (nonatomic, strong) UIBarButtonItem *historyItem;
@property (nonatomic, strong) UIBarButtonItem *composeItem;
@property (nonatomic, strong) UISegmentedControl *segControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) ODRefreshControl *refreshControl;
@property (nonatomic, strong) S1TabBar *scrollTabBar;

@property (nonatomic, strong) S1Tracer *tracer;
@property (nonatomic, strong) NSString *currentKey;
@property (nonatomic, strong) NSMutableArray *topics;
@property (nonatomic, strong) NSNumber *topicPageNumber;
@property (nonatomic, strong) NSMutableDictionary *cache;
@property (nonatomic, strong) NSMutableDictionary *cachePageNumber;
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
    self.tracer = [[S1Tracer alloc] init];
    
    self.view.backgroundColor = [S1GlobalVariables color5];
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, _BAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height-2 * _BAR_HEIGHT) style:UITableViewStylePlain];
    }
    else {
        self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, _UPPER_BAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height-_BAR_HEIGHT-_UPPER_BAR_HEIGHT) style:UITableViewStylePlain];
    }
    self.tableView.autoresizesSubviews = YES;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    self.tableView.rowHeight = 54.0f;
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    //[self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.separatorColor = [S1GlobalVariables color1];
    self.tableView.backgroundColor = [S1GlobalVariables color5];
    self.tableView.hidden = YES;
    [self.view addSubview:self.tableView];
    
    self.refreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    self.refreshControl.tintColor = [S1GlobalVariables color8];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    self.navigationBar = [[UINavigationBar alloc] init];
    if (SYSTEM_VERSION_LESS_THAN(@"7")) {
        self.navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, _BAR_HEIGHT);
        self.navigationBar.tintColor = [S1GlobalVariables color3];
    } else {
        self.navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, _UPPER_BAR_HEIGHT);
    }
    self.navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    //self.navigationBar.backgroundColor = [S1GlobalVariables color9];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Stage1st"];
    self.naviItem = item;
    UIBarButtonItem *settingItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"TopicListView_NavigationBar_Settings", "Settings") style:UIBarButtonItemStyleBordered target:self action:@selector(settings:)];
    item.leftBarButtonItem = settingItem;
    self.historyItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(history:)];
    self.composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:nil];
    
    NSArray *actionButtonItems = @[self.historyItem, self.composeItem];
    item.rightBarButtonItems = actionButtonItems;
    [self.navigationBar pushNavigationItem:item animated:NO];
    [self.view addSubview:self.navigationBar];
    
    
    self.scrollTabBar = [[S1TabBar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-_BAR_HEIGHT, self.view.bounds.size.width, _BAR_HEIGHT) andKeys:[self keys]];
    self.scrollTabBar.tabbarDelegate = self;
        
    [self.view addSubview:self.scrollTabBar];

    self.scrollTabBar.autoresizesSubviews = YES;
    self.scrollTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabbar:) name:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateHTTPClient:) name:@"S1BaseURLMayChangedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewOrientationDidChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
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
    _HTTPClient = [[S1HTTPClient alloc] initWithBaseURL:[NSURL URLWithString:baseURLString]];
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

- (void)history:(id)sender
{
    [self.naviItem setRightBarButtonItems:@[]];
    if (!self.segControl) {
        self.segControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"TopicListView_SegmentControl_History", @"History"),NSLocalizedString(@"TopicListView_SegmentControl_Favorite", @"Favorite")]];
        [self.segControl setWidth:80 forSegmentAtIndex:0];
        [self.segControl setWidth:80 forSegmentAtIndex:1];
        if (SYSTEM_VERSION_LESS_THAN(@"7")) {
            [self.segControl setSegmentedControlStyle:UISegmentedControlStyleBar];
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
                //TODO:fit iOS6 & iPhone
            }
        }
        [self.segControl addTarget:self action:@selector(segSelected:) forControlEvents:UIControlEventValueChanged];
        [self.segControl setSelectedSegmentIndex:0];
        [self presentHistory];
    } else {
        if (self.segControl.selectedSegmentIndex == 0) {
            [self presentHistory];
        } else {
            [self presentFavorite];
        }
    }
    self.naviItem.titleView = self.segControl;
}

- (void)refresh:(id)sender
{
    if (self.refreshControl.hidden) {
        [self.refreshControl endRefreshing];
        return;
    }
    
    if (self.scrollTabBar.enabled) {
        [self fetchTopicsForKeyFromServer:self.currentKey withPage:1 scrollToTop:NO];
    } else {
        [self.refreshControl endRefreshing];
    }
}

-(void)segSelected:(UISegmentedControl *)seg
{
    switch (seg.selectedSegmentIndex) {
        case 0:
            [self presentHistory];
            break;
            
        case 1:
            [self presentFavorite];
            break;
            
        default:
            break;
    }
}


- (void)presentHistory
{
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;
    }
    self.refreshControl.hidden = YES;
    
    self.topics = [[self.tracer historyObjects] mutableCopy];
    [self.tableView reloadData];
    if (self.topics && self.topics.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
    [self.scrollTabBar deselectAll];
    self.currentKey = @"History";
}

- (void)presentFavorite
{
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;
    }
    self.refreshControl.hidden = YES;
    
    self.topics = [[self.tracer favoritedObjects] mutableCopy];
    [self.tableView reloadData];
    if (self.topics && self.topics.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
    [self.scrollTabBar deselectAll];
    self.currentKey = @"Favorite";
}

#pragma mark - Tab Bar Delegate

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key
{
    self.naviItem.titleView = nil;
    self.naviItem.title = @"Stage1st";
    [self.naviItem setRightBarButtonItems:@[self.historyItem, self.composeItem]];
    
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
        [self fetchTopicsForKeyFromServer:key withPage:1 scrollToTop:YES];
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
    [self fetchTopicsForKeyFromServer:key withPage:1 scrollToTop:YES];
}

- (void)fetchTopicsForKeyFromServer:(NSString *)key withPage:(NSUInteger)page scrollToTop:(BOOL)toTop
{
    self.scrollTabBar.enabled = NO;
    S1HUD *HUD = [S1HUD showHUDInView:self.view];
    [HUD showActivityIndicator];
    NSString *path;
    if (page == 1) {
        path = [NSString stringWithFormat:@"forum.php?mod=forumdisplay&fid=%@&mobile=no", self.threadsInfo[key]];
    } else {
        path = [NSString stringWithFormat:@"forum.php?mod=forumdisplay&fid=%@&page=%lu&mobile=no", self.threadsInfo[key], (unsigned long)page];
    }
    NSString *fid = self.threadsInfo[key];
    [self.HTTPClient getPath:path
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                        //check login state
                        NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                        if (![S1Parser checkLoginState:HTMLString])
                        {
                            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"InLoginStateID"];
                        }
                        //parse topics
                        NSArray *topics = [S1Parser topicsFromHTMLData:responseObject withContext:@{@"FID": fid}];
                        //append tracer message to topics
                         for (S1Topic *topic in topics) {
                             S1Topic *tempTopic = [self.tracer tracedTopic:topic.topicID];
                             if (tempTopic) {
                                 [topic setLastViewedPage:tempTopic.lastViewedPage];
                                 [topic setVisitCount:tempTopic.visitCount];
                                 [topic setFavorite:tempTopic.favorite];
                             }
                         }
                        if (topics.count > 0) {
                            if (page == 1) {
                                self.topics = [topics mutableCopy];
                                self.topicPageNumber = @1;
                                self.cache[key] = topics;
                                self.cachePageNumber[key] = self.topicPageNumber;
                                [self.tableView reloadData];
                                if (toTop) {
                                    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
                                }
                            } else {
                                self.topics = [[self.topics arrayByAddingObjectsFromArray:topics] mutableCopy];
                                self.topicPageNumber = [[NSNumber alloc] initWithInteger:page];
                                self.cache[key] = self.topics;
                                self.cachePageNumber[key] = self.topicPageNumber;
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

#pragma mark - Orientation

- (void)viewOrientationDidChanged:(NSNotification *)notification
{
    [self.scrollTabBar updateButtonFrame];
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
    [controller setTopic:topicToShow];
    [controller setTracer:self.tracer];
    [controller setHTTPClient:self.HTTPClient];
    
    [[self rootViewController] presentDetailViewController:controller];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return YES if you want the specified item to be editable.
    return ([self.currentKey  isEqual: @"History"] || [self.currentKey  isEqual: @"Favorite"])?YES:NO;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        //add code here for when you hit delete
        if ([self.currentKey  isEqual: @"History"]) {
            S1Topic *topic = self.topics[indexPath.row];
            [self.tracer removeTopicFromHistory:topic.topicID];
            [self.topics removeObjectAtIndex:indexPath.row];
            [self.tableView reloadData];
        }
        if ([self.currentKey  isEqual: @"Favorite"]) {
            S1Topic *topic = self.topics[indexPath.row];
            [self.tracer setTopicFavoriteState:topic.topicID withState:NO];
            [self.topics removeObjectAtIndex:indexPath.row];
            [self.tableView reloadData];
        }
        
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *) cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        return;
    }
    if(indexPath.row == [self.topics count] - 1)
    {
        NSLog(@"Reach last topic, load more.");
        [self fetchTopicsForKeyFromServer:self.currentKey withPage:[self.topicPageNumber integerValue] + 1 scrollToTop:NO];
    }
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
    self.topics = [NSMutableArray array];
    [self.tableView reloadData];
    self.currentKey = nil;
    self.cache = nil;
}

- (void)updateHTTPClient:(id)sender
{
    self.HTTPClient = nil;
}

@end
