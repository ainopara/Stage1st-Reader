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
#import "MTStatusBarOverlay.h"

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
@property (nonatomic, strong) NSMutableArray *topicHeaderTitles;
@property (nonatomic, strong) NSNumber *topicPageNumber;
@property (nonatomic, strong) NSMutableDictionary *cache;
@property (nonatomic, strong) NSMutableDictionary *cachePageNumber;
@property (nonatomic, strong) NSMutableDictionary *cacheContentOffset;
@property (nonatomic, strong) NSDictionary *threadsInfo;
@property (nonatomic, strong) S1HTTPClient *HTTPClient;

@end

@implementation S1TopicListViewController {
    BOOL _loadingFlag;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _loadingFlag = NO;
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
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, _UPPER_BAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height-_BAR_HEIGHT-_UPPER_BAR_HEIGHT) style:UITableViewStylePlain];
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
    self.navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, _UPPER_BAR_HEIGHT);
    self.navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    //self.navigationBar.backgroundColor = [S1GlobalVariables color9];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Stage1st"];
    self.naviItem = item;
    UIBarButtonItem *settingItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Settings"] style:UIBarButtonItemStyleBordered target:self action:@selector(settings:)];
    item.leftBarButtonItem = settingItem;
    
    self.historyItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Archive"] style:UIBarButtonItemStyleBordered target:self action:@selector(history:)];
    //self.composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(test:)];
    
    NSArray *actionButtonItems = @[self.historyItem/*, self.composeItem*/];
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableData:) name:@"S1ContentViewWillDisappearNotification" object:nil];
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
    self.cachePageNumber = nil;
    self.cacheContentOffset = nil;
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"S1ContentViewWillDisappearNotification" object:nil];
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
- (NSMutableDictionary *)cachePageNumber
{
    if(_cachePageNumber) {
        return _cachePageNumber;
    }
    _cachePageNumber = [NSMutableDictionary dictionary];
    return _cachePageNumber;
}

- (NSMutableDictionary *)cacheContentOffset
{
    if(_cacheContentOffset) {
        return _cacheContentOffset;
    }
    _cacheContentOffset = [NSMutableDictionary dictionary];
    return _cacheContentOffset;
}

- (S1HTTPClient *)HTTPClient
{
    return [S1HTTPClient sharedClient];
}

#pragma mark - Item Actions

- (void)settings:(id)sender
{
    [self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
    S1SettingViewController *controller = [[S1SettingViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *controllerToPresent = [[UINavigationController alloc] initWithRootViewController:controller];
    [self presentViewController:controllerToPresent animated:YES completion:nil];
}
/*
- (void)test:(id)sender
{
    MTStatusBarOverlay *overlay = [MTStatusBarOverlay sharedInstance];
    overlay.animation = MTStatusBarOverlayAnimationNone;
    [overlay postMessage:@"testing" duration:2.0 animated:YES];
    [overlay postImmediateFinishMessage:@"测试数据测试数据!" duration:5.0 animated:YES];
}*/
- (void)history:(id)sender
{
    [self.naviItem setRightBarButtonItems:@[]];
    if (!self.segControl) {
        self.segControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"TopicListView_SegmentControl_History", @"History"),NSLocalizedString(@"TopicListView_SegmentControl_Favorite", @"Favorite")]];
        [self.segControl setWidth:80 forSegmentAtIndex:0];
        [self.segControl setWidth:80 forSegmentAtIndex:1];
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
    if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
        self.cache[self.currentKey] = self.topics;
        self.cacheContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
        self.cachePageNumber[self.currentKey] = self.topicPageNumber;
    }
    self.currentKey = @"History";
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;
    }
    self.refreshControl.hidden = YES;
    
    NSArray *topics = [self.tracer historyObjects];
    NSMutableArray *processedTopics = [[NSMutableArray alloc] init];
    NSMutableArray *topicHeaderTitles = [[NSMutableArray alloc] init];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:NSLocalizedString(@"TopicListView_ListHeader_Style", @"Header Style")];
    for (S1Topic *topic in topics) {
        NSString *topicTitle = [formatter stringFromDate:topic.lastViewedDate];
        if ([[formatter stringFromDate:topic.lastViewedDate] isEqualToString:[formatter stringFromDate:[[NSDate alloc] initWithTimeIntervalSinceNow:0]]]) {
            topicTitle = [topicTitle stringByAppendingString:NSLocalizedString(@"TopicListView_ListHeader_Today", @"Today")];
        }
        if ([topicHeaderTitles containsObject:topicTitle]) {
            [[processedTopics objectAtIndex:[topicHeaderTitles indexOfObject:topicTitle]] addObject:topic];
        } else {
            [topicHeaderTitles addObject:topicTitle];
            [processedTopics addObject:[[NSMutableArray alloc] initWithObjects:topic, nil]];
        }
    }
    self.topics = processedTopics;
    self.topicHeaderTitles = topicHeaderTitles;
    
    [self.tableView reloadData];
    if (self.topics && self.topics.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
    [self.scrollTabBar deselectAll];
    
}

- (void)presentFavorite
{
    if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
        self.cache[self.currentKey] = self.topics;
        self.cacheContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
        self.cachePageNumber[self.currentKey] = self.topicPageNumber;
    }
    self.currentKey = @"Favorite";
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;
    }
    self.refreshControl.hidden = YES;
    
    //bool favoriteTopicShouldOrderByLastVisitDate = [[NSUserDefaults standardUserDefaults] boolForKey:@"FavoriteTopicShouldOrderByLastVisitDate"];
    BOOL favoriteTopicShouldOrderByLastVisitDate = YES;
    NSArray *topics = [self.tracer favoritedObjects:(favoriteTopicShouldOrderByLastVisitDate ? S1TopicOrderByLastVisitDate : S1TopicOrderByFavoriteSetDate)];
    NSMutableArray *processedTopics = [[NSMutableArray alloc] init];
    NSMutableArray *topicHeaderTitles = [[NSMutableArray alloc] init];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:NSLocalizedString(@"TopicListView_ListHeader_Style", @"Header Style")];
    for (S1Topic *topic in topics) {
        NSDate *date = favoriteTopicShouldOrderByLastVisitDate ? topic.lastViewedDate : topic.favoriteDate;
        NSString *topicTitle = [formatter stringFromDate:date];
        if ([[formatter stringFromDate:date] isEqualToString:[formatter stringFromDate:[[NSDate alloc] initWithTimeIntervalSinceNow:0]]]) {
            topicTitle = [topicTitle stringByAppendingString:NSLocalizedString(@"TopicListView_ListHeader_Today", @"Today")];
        }
        if ([topicHeaderTitles containsObject:topicTitle]) {
            [[processedTopics objectAtIndex:[topicHeaderTitles indexOfObject:topicTitle]] addObject:topic];
        } else {
            [topicHeaderTitles addObject:topicTitle];
            [processedTopics addObject:[[NSMutableArray alloc] initWithObjects:topic, nil]];
        }
    }
    self.topics = processedTopics;
    self.topicHeaderTitles = topicHeaderTitles;
    
    [self.tableView reloadData];
    if (self.topics && self.topics.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
    [self.scrollTabBar deselectAll];
    
}

#pragma mark - Tab Bar Delegate

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key
{
    self.naviItem.titleView = nil;
    self.naviItem.title = @"Stage1st";
    [self.naviItem setRightBarButtonItems:@[self.historyItem/*, self.composeItem*/]];
    
    if (self.tableView.hidden) {
        self.tableView.hidden = NO;
    }
    if (self.refreshControl.hidden) {
        self.refreshControl.hidden = NO;
    }
    
    if (![self.currentKey isEqualToString:key]) {
        if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
            self.cache[self.currentKey] = self.topics;
            self.cacheContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
            self.cachePageNumber[self.currentKey] = self.topicPageNumber;
        }
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
        if (self.cachePageNumber[key]) {
            self.topicPageNumber = self.cachePageNumber[key];
        }
        [self.tableView reloadData];
        if (self.cacheContentOffset[key]) {
            [self.tableView setContentOffset:[self.cacheContentOffset[key] CGPointValue] animated:NO];
        } else {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        }
        return;
    }
    [self fetchTopicsForKeyFromServer:key withPage:1 scrollToTop:YES];
}

- (void)fetchTopicsForKeyFromServer:(NSString *)key withPage:(NSUInteger)page scrollToTop:(BOOL)toTop
{
    _loadingFlag = YES;
    self.scrollTabBar.enabled = NO;
    S1HUD *HUD = nil;
    if (page == 1) {
        HUD = [S1HUD showHUDInView:self.view];
        [HUD showActivityIndicator];
    }
    NSString *path;
    if (page == 1) {
        path = [NSString stringWithFormat:@"forum.php?mod=forumdisplay&fid=%@&mobile=no", self.threadsInfo[key]];
    } else {
        path = [NSString stringWithFormat:@"forum.php?mod=forumdisplay&fid=%@&page=%lu&mobile=no", self.threadsInfo[key], (unsigned long)page];
    }
    NSString *fid = self.threadsInfo[key];
    [self.HTTPClient GET:path parameters:nil
                 success:^(NSURLSessionDataTask *operation, id responseObject) {
                     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                         //check login state
                         NSString* HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                         [[NSUserDefaults standardUserDefaults] setValue:[S1Parser loginUserName:HTMLString] forKey:@"InLoginStateID"];
                         //parse topics
                         NSMutableArray *topics = [[S1Parser topicsFromHTMLData:responseObject withContext:@{@"FID": fid}] mutableCopy];
                         for (S1Topic *topic in topics) {
                             //append tracer message to topics
                             S1Topic *tempTopic = [self.tracer tracedTopic:topic.topicID];
                             if (tempTopic) {
                                 [topic setLastReplyCount:tempTopic.replyCount];
                                 [topic setLastViewedPage:tempTopic.lastViewedPage];
                                 [topic setLastViewedPosition:tempTopic.lastViewedPosition];
                                 [topic setVisitCount:tempTopic.visitCount];
                                 [topic setFavorite:tempTopic.favorite];
                                 NSLog(@"Traced: %@", topic.title);
                                 NSLog(@"Position & Favorite: %@:%@",tempTopic.lastViewedPosition, tempTopic.favorite);
                             }
                             // remove duplicate topics
                             if (page > 1) {
                                 for (S1Topic *compareTopic in self.topics) {
                                     if ([topic.topicID isEqualToNumber:compareTopic.topicID]) {
                                         NSLog(@"Remove duplicate topic: %@", topic.title);
                                         [self.topics removeObject:compareTopic];
                                         break;
                                     }
                                 }
                             }
                         }
                         if (topics.count > 0) {
                             if (page == 1) {
                                 self.topics = topics;
                                 self.topicPageNumber = @1;
                             } else {
                                 self.topics = [[self.topics arrayByAddingObjectsFromArray:topics] mutableCopy];
                                 self.topicPageNumber = [[NSNumber alloc] initWithInteger:page];
                             }
                         } else {
                             if(page == 1) {
                                 self.topics = [[NSMutableArray alloc] init];
                                 self.topicPageNumber = @1;
                             }
                         }
                         dispatch_async(dispatch_get_main_queue(), ^{
                             if (topics.count > 0) {
                                 [self.tableView reloadData];
                                 if (toTop) {
                                     [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
                                 }
                                 
                             }
                             if (self.refreshControl.refreshing) {
                                 [self.refreshControl endRefreshing];
                             }
                             if (page == 1) {
                                 [HUD hideWithDelay:0.3];
                             }
                             self.scrollTabBar.enabled = YES;
                             _loadingFlag = NO;
                         });
                     });
                 }
                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
                     NSLog(@"%@", error);
                     dispatch_async(dispatch_get_main_queue(), ^{
                         if (error.code == -999) {
                             NSLog(@"Code -999 may means user want to cancel this request.");
                         } else {
                             if(page == 1) {
                                 [HUD setText:@"Request Failed"];
                                 [HUD hideWithDelay:0.3];
                             }
                         }
                         if (![key isEqualToString:self.currentKey]) {
                             self.topics = [[NSMutableArray alloc] init];
                             self.topicPageNumber = @1;
                             [self.tableView reloadData];
                         }
                         self.scrollTabBar.enabled = YES;
                         if (self.refreshControl.refreshing) {
                             [self.refreshControl endRefreshing];
                         }
                         _loadingFlag = NO;
                     });
                 }];
}

#pragma mark - Orientation

- (void)viewOrientationDidChanged:(NSNotification *)notification
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return;
    }
    [self.scrollTabBar updateButtonFrame];
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    }
    return [super supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationPortrait;
    }
    return [super preferredInterfaceOrientationForPresentation];
}

#pragma mark - UITableView


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([self.currentKey  isEqual: @"History"] || [self.currentKey  isEqual: @"Favorite"]) {
        return [self.topicHeaderTitles count];
    }

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self.currentKey  isEqual: @"History"] || [self.currentKey  isEqual: @"Favorite"]) {
        return [[self.topics objectAtIndex:section] count];
    }
    
    return [self.topics count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    S1TopicListCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[S1TopicListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([self.currentKey  isEqual: @"History"] || [self.currentKey  isEqual: @"Favorite"]) {
        [cell setTopic:[[self.topics objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
        return cell;
    }
    [cell setTopic:self.topics[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    S1ContentViewController *controller = [[S1ContentViewController alloc] init];
    S1Topic *topicToShow = nil;
    if ([self.currentKey  isEqual: @"History"] || [self.currentKey  isEqual: @"Favorite"]) {
        topicToShow = [[self.topics objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    } else {
        topicToShow = self.topics[indexPath.row];
    }
    
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
            S1Topic *topic = self.topics[indexPath.section][indexPath.row];
            [self.tracer removeTopicFromHistory:topic.topicID];
            [self.topics[indexPath.section] removeObjectAtIndex:indexPath.row];
            [self.tableView reloadData];
        }
        if ([self.currentKey  isEqual: @"Favorite"]) {
            S1Topic *topic = self.topics[indexPath.section][indexPath.row];
            [self.tracer setTopicFavoriteState:topic.topicID withState:NO];
            [self.topics[indexPath.section] removeObjectAtIndex:indexPath.row];
            [self.tableView reloadData];
        }
        
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *) cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        return;
    }
    if (_loadingFlag) {
        return;
    }
    if(indexPath.row == [self.topics count] - 15)
    {
        NSLog(@"Reach last topic, load more.");
        [self fetchTopicsForKeyFromServer:self.currentKey withPage:[self.topicPageNumber integerValue] + 1 scrollToTop:NO];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 20)];
        [view setBackgroundColor:[UIColor colorWithRed:0.822 green:0.853 blue:0.756 alpha:0.300]];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 320, 20)];
        NSMutableAttributedString *labelTitle = [[NSMutableAttributedString alloc] initWithString:[self.topicHeaderTitles objectAtIndex:section]];
        
        [labelTitle addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:12.0] range:NSMakeRange(0, [labelTitle length])];
        [labelTitle addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.220 green:0.329 blue:0.529 alpha:1.000] range:NSMakeRange(0, [labelTitle length])];
        [label setAttributedText:labelTitle];
        
        label.backgroundColor = [UIColor clearColor];
        [view addSubview:label];
        
        return view;
    }
    
    return nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        return 20;
    }
    return 0;
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

- (void)updateTabbar:(NSNotification *)notification
{
    [self.scrollTabBar setKeys:[self keys]];
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        self.cache = nil;
        self.cachePageNumber = nil;
        self.cacheContentOffset = nil;
    } else {
        self.tableView.hidden = YES;
        self.topics = [NSMutableArray array];
        self.currentKey = nil;
        self.cache = nil;
        self.cachePageNumber = nil;
        self.cacheContentOffset = nil;
        [self.tableView reloadData];
    }
    
}
- (void)reloadTableData:(NSNotification *)notification
{
    [self.tableView reloadData];
}
@end
