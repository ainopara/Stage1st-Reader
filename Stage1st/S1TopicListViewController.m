//
//  S1TopicListViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1TopicListViewController.h"
#import "S1ContentViewController.h"
#import "S1SettingViewController.h"
#import "S1TopicListCell.h"
#import "S1HUD.h"
#import "S1Topic.h"
#import "S1TabBar.h"
#import "S1DataCenter.h"
#import "S1TopicListViewModel.h"

#import "ODRefreshControl.h"
#import "AFNetworking.h"
#import "MTStatusBarOverlay.h"

static NSString * const cellIdentifier = @"TopicCell";

#define _BAR_HEIGHT 44.0f
#define _UPPER_BAR_HEIGHT 64.0f
#define _SEARCH_BAR_HEIGHT 40.0f

@interface S1TopicListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, S1TabBarDelegate>
@property (nonatomic, strong) UINavigationBar *navigationBar;
@property (nonatomic, strong) UINavigationItem *naviItem;
@property (nonatomic, strong) UIBarButtonItem *historyItem;
@property (nonatomic, strong) UISegmentedControl *segControl;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) ODRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray *searchResults; // Filtered search results
@property (weak, nonatomic) IBOutlet S1TabBar *scrollTabBar;

@property (nonatomic, strong) S1DataCenter *dataCenter;
@property (nonatomic, strong) S1TopicListViewModel *viewModel;
@property (nonatomic, strong) NSString *currentKey;
@property (nonatomic, strong) NSString *previousKey;
@property (nonatomic, strong) NSMutableArray *topics;
@property (nonatomic, strong) NSMutableArray *topicHeaderTitles;
@property (nonatomic, strong) NSMutableDictionary *cacheContentOffset;
@property (nonatomic, strong) NSDictionary *threadsInfo;

@property (nonatomic, strong) S1Topic *clipboardTopic;

@end

@implementation S1TopicListViewController {
    BOOL _loadingFlag;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _loadingFlag = NO;
        self.currentKey = @"";
        self.previousKey = @"";
    }
    return self;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dataCenter = [[S1DataCenter alloc] init];
    self.viewModel = [[S1TopicListViewModel alloc] initWithDataCenter:self.dataCenter];
    
    self.view.backgroundColor = [S1GlobalVariables color5];
    
    self.tableView.rowHeight = 54.0f;
    [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    //[self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.separatorColor = [S1GlobalVariables color1];
    self.tableView.backgroundColor = [S1GlobalVariables color5];
    if (self.tableView.backgroundView) {
        self.tableView.backgroundView.backgroundColor = [S1GlobalVariables color5];
    }
    self.tableView.hidden = YES;
    
    //Search or Filter
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, _SEARCH_BAR_HEIGHT)];
    self.searchBar.delegate = self;
    //self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.tintColor = [S1GlobalVariables color4];
    self.searchBar.barTintColor = [S1GlobalVariables color5];
    //[self.searchBar setSearchFieldBackgroundImage:[S1GlobalVariables imageWithColor:[S1GlobalVariables color4] size:CGSizeMake(self.view.bounds.size.width, 32)] forState:UIControlStateNormal];
    UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(clearSearchBarText:)];
    gestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
    [self.searchBar addGestureRecognizer:gestureRecognizer];
    self.tableView.tableHeaderView = self.searchBar;
    
    //self.definesPresentationContext = YES;
    
    self.refreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    self.refreshControl.tintColor = [S1GlobalVariables color8];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    self.navigationBar = [[UINavigationBar alloc] init];
    self.navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, _UPPER_BAR_HEIGHT);
    self.navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.naviItem = [[UINavigationItem alloc] initWithTitle:@"Stage1st"];
    UIBarButtonItem *settingItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Settings"] style:UIBarButtonItemStyleBordered target:self action:@selector(settings:)];
    self.historyItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Archive"] style:UIBarButtonItemStyleBordered target:self action:@selector(archive:)];
    self.naviItem.leftBarButtonItem = settingItem;
    self.naviItem.rightBarButtonItem = self.historyItem;
    [self.navigationBar pushNavigationItem:self.naviItem animated:NO];
    [self.view addSubview:self.navigationBar];
    
    self.scrollTabBar.keys = [self keys];
    self.scrollTabBar.tabbarDelegate = self;
    
    //Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabbar:) name:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableData:) name:@"S1ContentViewWillDisappearNotification" object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self.tableView setUserInteractionEnabled:YES];
    [self.tableView setScrollsToTop:YES];
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
    [self.dataCenter clearTopicListCache];
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

- (NSMutableDictionary *)cacheContentOffset
{
    if(_cacheContentOffset) {
        return _cacheContentOffset;
    }
    _cacheContentOffset = [NSMutableDictionary dictionary];
    return _cacheContentOffset;
}

#pragma mark - Item Actions

- (void)settings:(id)sender
{
    //[self rootViewController].modalPresentationStyle = UIModalPresentationFullScreen;
    NSString * storyboardName = @"Settings";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle: nil];
    UIViewController * controllerToPresent = [storyboard instantiateViewControllerWithIdentifier:@"SettingsNavigation"];
    [self presentViewController:controllerToPresent animated:YES completion:nil];
}

- (void)archive:(id)sender
{
    NSDate *start = [NSDate date];
    [self.naviItem setRightBarButtonItems:@[]];
    if (!self.segControl) {
        self.segControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"TopicListView_SegmentControl_History", @"History"),NSLocalizedString(@"TopicListView_SegmentControl_Favorite", @"Favorite")]];
        [self.segControl setWidth:80 forSegmentAtIndex:0];
        [self.segControl setWidth:80 forSegmentAtIndex:1];
        [self.segControl addTarget:self action:@selector(segSelected:) forControlEvents:UIControlEventValueChanged];
        [self.segControl setSelectedSegmentIndex:0];
        [self presentInternalListForType:S1TopicListHistory];
    } else {
        if (self.segControl.selectedSegmentIndex == 0) {
            [self presentInternalListForType:S1TopicListHistory];
        } else {
            [self presentInternalListForType:S1TopicListFavorite];
        }
    }
    self.naviItem.titleView = self.segControl;
    NSTimeInterval timeInterval = [start timeIntervalSinceNow];
    NSLog(@"Finish present:%f",-timeInterval);
}

- (void)refresh:(id)sender
{
    if (self.refreshControl.hidden) {
        [self.refreshControl endRefreshing];
        return;
    }
    
    if (self.scrollTabBar.enabled) {
        [self fetchTopicsForKey:self.currentKey shouldRefresh:YES andScrollToTop:NO];
    } else {
        [self.refreshControl endRefreshing];
    }
}

-(void)segSelected:(UISegmentedControl *)seg
{
    self.searchBar.text = @"";
    switch (seg.selectedSegmentIndex) {
        case 0:
            [self presentInternalListForType:S1TopicListHistory];
            break;
            
        case 1:
            [self presentInternalListForType:S1TopicListFavorite];
            break;
            
        default:
            break;
    }
}


- (void)presentInternalListForType:(S1InternalTopicListType)type
{
    if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
        [self cancelRequest];
        self.cacheContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
    }
    self.previousKey = self.currentKey;
    self.currentKey = type == S1TopicListHistory ? @"History":@"Favorite";
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;
    }
    self.refreshControl.hidden = YES;
    
    if (type == S1TopicListHistory) {
        self.dataCenter.shouldReloadHistoryCache = YES;
    } else if (type == S1TopicListFavorite) {
        self.dataCenter.shouldReloadFavoriteCache = YES;
    }
    __weak typeof(self) myself = self;
    NSDictionary *result = [self.viewModel internalTopicsInfoFor:type withSearchWord:@"" andLeftCallback:^(NSDictionary *fullResult) {
        __strong typeof(self) strongMyself = myself;
        strongMyself.topics = [fullResult valueForKey:@"topics"];
        strongMyself.topicHeaderTitles = [fullResult valueForKey:@"headers"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongMyself.tableView reloadData];
        });
    }];
    self.topics = [result valueForKey:@"topics"];
    self.topicHeaderTitles = [result valueForKey:@"headers"];
    
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
    self.searchBar.text = @"";
    [self.naviItem setRightBarButtonItem:self.historyItem];
    
    if (self.refreshControl.hidden) { self.refreshControl.hidden = NO; }
    if (NO) {
        if (![self.currentKey isEqualToString:key]) {
            NSLog(@"load key: %@ current key: %@ previous key: %@", key, self.currentKey, self.previousKey);
            [self fetchTopicsForKey:key shouldRefresh:NO andScrollToTop:NO];
        } else { //press the key that selected currently
            NSLog(@"refresh key: %@ current key: %@ previous key: %@", key, self.currentKey, self.previousKey);
            [self fetchTopicsForKey:key shouldRefresh:YES andScrollToTop:YES];
        }
    } else {
        //Force refresh
        [self fetchTopicsForKey:key shouldRefresh:YES andScrollToTop:YES];
    }

}



#pragma mark - Networking

- (void)fetchTopicsForKey:(NSString *)key shouldRefresh:(BOOL)refresh andScrollToTop:(BOOL)scrollToTop
{
    _loadingFlag = YES;
    self.scrollTabBar.enabled = NO;
    S1HUD *HUD;
    if (refresh || ![self.dataCenter hasCacheForKey:self.threadsInfo[key]]) {
        HUD = [S1HUD showHUDInView:self.view];
        [HUD showActivityIndicator];
    }
    
    
    [self.viewModel topicListForKey:self.threadsInfo[key] shouldRefresh:refresh success:^(NSArray *topicList) {
        //reload data
        if (topicList.count > 0) {
            if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
                self.cacheContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
            }
            self.previousKey = self.currentKey == nil ? @"" : self.currentKey;
            self.currentKey = key;
            self.topics = [topicList mutableCopy];
            [self.tableView reloadData];
            if (self.tableView.hidden) { self.tableView.hidden = NO; }
            if (self.cacheContentOffset[key] && !scrollToTop) {
                [self.tableView setContentOffset:[self.cacheContentOffset[key] CGPointValue] animated:NO];
            } else {
                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
            
        } else {
            if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
                self.cacheContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
            }
            self.previousKey = self.currentKey == nil ? @"" : self.currentKey;
            self.currentKey = key;
            if (![key isEqualToString:self.previousKey]) {
                self.topics = [[NSMutableArray alloc] init];
                [self.tableView reloadData];
            }
        }
        //hud hide
        if (refresh || ![self.dataCenter hasCacheForKey:key]) {
            [HUD hideWithDelay:0.3];
        }
        //others
        self.scrollTabBar.enabled = YES;
        if (self.refreshControl.refreshing) {
            [self.refreshControl endRefreshing];
        }
        _loadingFlag = NO;
    } failure:^(NSError *error) {
        //reload data
        if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
            self.cacheContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
        }
        self.previousKey = self.currentKey == nil ? @"" : self.currentKey;
        self.currentKey = key;
        if (![key isEqualToString:self.previousKey]) {
            self.topics = [[NSMutableArray alloc] init];
            [self.tableView reloadData];
        }
        //hud hide
        if (refresh || ![self.dataCenter hasCacheForKey:key]) {
            if (error.code == -999) {
                NSLog(@"Code -999 may means user want to cancel this request.");
                [HUD hideWithDelay:0];
            } else {
                [HUD setText:@"Request Failed"];
                [HUD hideWithDelay:0.3];
            }
        }
        
        //others
        self.scrollTabBar.enabled = YES;
        if (self.refreshControl.refreshing) {
            [self.refreshControl endRefreshing];
        }
        _loadingFlag = NO;
    }];
}

#pragma mark - Orientation

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

#pragma mark - UITableView Delegate and Data Source


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
    } else {
        [cell setTopic:self.topics[indexPath.row]];
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
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
            [self.dataCenter removeTopicFromHistory:topic.topicID];
            [self.topics[indexPath.section] removeObjectAtIndex:indexPath.row];
            [self.tableView reloadData];
        }
        if ([self.currentKey  isEqual: @"Favorite"]) {
            S1Topic *topic = self.topics[indexPath.section][indexPath.row];
            [self.dataCenter setTopicFavoriteState:topic.topicID withState:NO];
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
        [self.dataCenter loadNextPageForKey:self.threadsInfo[self.currentKey] success:^(NSArray *topicList) {
            self.topics = [topicList mutableCopy];
            [self.tableView reloadData];
        } failure:^(NSError *error) {
            NSLog(@"fail to load more...");
        }];
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

#pragma mark - UISearchBar Delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        __weak typeof(self) myself = self;
        NSDictionary *result = [self.viewModel internalTopicsInfoFor:[self.currentKey isEqual: @"History"]?S1TopicListHistory:S1TopicListFavorite withSearchWord:searchText andLeftCallback:^(NSDictionary *fullResult) {
            __strong typeof(self) strongMyself = myself;
            strongMyself.topics = [fullResult valueForKey:@"topics"];
            strongMyself.topicHeaderTitles = [fullResult valueForKey:@"headers"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongMyself.tableView reloadData];
            });
        }];
        self.topics = [result valueForKey:@"topics"];
        self.topicHeaderTitles = [result valueForKey:@"headers"];
        
        [self.tableView reloadData];
        if (self.topics && self.topics.count > 0) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        }
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self.searchBar resignFirstResponder];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

- (void)clearSearchBarText:(UISwipeGestureRecognizer *)gestureRecognizer {
    self.searchBar.text = @"";
    [self.searchBar.delegate searchBar:self.searchBar textDidChange:@""];
}
#pragma mark - Helpers

- (NSArray *)keys
{
    return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"] objectAtIndex:0];
}

- (void)updateTabbar:(NSNotification *)notification
{
    [self.scrollTabBar setKeys:[self keys]];
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        self.cacheContentOffset = nil;
    } else {
        self.tableView.hidden = YES;
        self.topics = [NSMutableArray array];
        self.previousKey = @"";
        self.currentKey = @"";
        self.cacheContentOffset = nil;
        [self.tableView reloadData];
    }
    
}

-(void) cancelRequest
{
    [self.dataCenter cancelRequest];
    
}

- (void)reloadTableData:(NSNotification *)notification
{
    [self.tableView reloadData];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"Show Content"]) {
        S1TopicListCell *cell = sender;
        S1ContentViewController *contentViewController = segue.destinationViewController;
        
        [contentViewController setTopic:cell.topic];
        [contentViewController setDataCenter:self.dataCenter];
    }
}

- (void)handlePasteboardString:(NSString *)URL
{
    if (!URL) {
        return;
    }
    NSString *pattern = @"bbs\\.saraba1st\\.com.*(?:tid=|thread-)([0-9]+)";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [re firstMatchInString:URL options:NSMatchingReportProgress range:NSMakeRange(0, URL.length)];
    if (result) {
        S1Topic *clipboardTopic = [[S1Topic alloc] init];
        NSString *topicIDString = [URL substringWithRange:[result rangeAtIndex:1]];
        NSNumber *topicID = [NSNumber numberWithInteger:[topicIDString integerValue]];
        NSLog(@"Open Clipboard topic ID: %@", topicID);
        clipboardTopic.topicID = topicID;
        [clipboardTopic addDataFromTracedTopic:[self.dataCenter tracedTopic:topicID]];
        S1ContentViewController *contentViewController = [[S1ContentViewController alloc] init];
        [contentViewController setTopic:self.clipboardTopic];
        [contentViewController setDataCenter:self.dataCenter];
        
        [self.navigationController pushViewController:contentViewController animated:YES];
    }
    
}

@end
