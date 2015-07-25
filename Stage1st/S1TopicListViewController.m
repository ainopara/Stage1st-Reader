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
#import "Masonry.h"

#import "ODRefreshControl.h"
#import "AFNetworking.h"
#import "MTStatusBarOverlay.h"

static NSString * const cellIdentifier = @"TopicCell";

#define _UPPER_BAR_HEIGHT 64.0f
#define _SEARCH_BAR_HEIGHT 40.0f

@interface S1TopicListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, S1TabBarDelegate>
@property (nonatomic, strong) UINavigationBar *navigationBar;
@property (nonatomic, strong) UINavigationItem *naviItem;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIBarButtonItem *historyItem;
@property (nonatomic, strong) UIBarButtonItem *settingsItem;
@property (nonatomic, strong) UISegmentedControl *segControl;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) ODRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet S1TabBar *scrollTabBar;

@property (nonatomic, strong) S1DataCenter *dataCenter;
@property (nonatomic, strong) S1TopicListViewModel *viewModel;
@property (nonatomic, strong) NSString *currentKey;
@property (nonatomic, strong) NSString *previousKey;
@property (nonatomic, strong) NSMutableArray *topics;
@property (nonatomic, strong) NSMutableArray *topicHeaderTitles;
@property (nonatomic, strong) NSMutableArray *searchResults; // Filtered search results
@property (nonatomic, strong) NSMutableDictionary *cachedContentOffset;
@property (nonatomic, strong) NSMutableDictionary *cachedLastRefreshTime;
@property (nonatomic, strong) NSDictionary *forumKeyMap;

@property (nonatomic, strong) S1Topic *clipboardTopic;

@end

#pragma mark -

@implementation S1TopicListViewController {
    BOOL _loadingFlag;
    BOOL _loadingMore;
}

#pragma mark - Life Cycle

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _loadingFlag = NO;
        _loadingMore = NO;
        self.currentKey = @"";
        self.previousKey = @"";
    }
    return self;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dataCenter = [S1DataCenter sharedDataCenter];
    self.viewModel = [[S1TopicListViewModel alloc] initWithDataCenter:self.dataCenter];
    
    self.view.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.background"];
    
    //Setup Navigation Bar
    [self.view addSubview:self.navigationBar];
    
    //Setup Table View
    self.tableView.rowHeight = 54.0f;
    [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    //[self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.separatorColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.tableview.separator"];
    self.tableView.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.tableview.background"];
    if (self.tableView.backgroundView) {
        self.tableView.backgroundView.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.tableview.background"];
    }
    self.tableView.hidden = YES;
    self.tableView.tableHeaderView = self.searchBar;
    //self.definesPresentationContext = YES;
    
    self.refreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView];
    self.refreshControl.tintColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.refreshcontrol.tint"];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    [self.tableView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    [self.tableView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:nil];
    
    //Setup Tab Bar
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


- (void)dealloc
{
    NSLog(@"Topic List View Dealloced.");
    [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
    [self.tableView removeObserver:self forKeyPath:@"contentInset"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"S1ContentViewWillDisappearNotification" object:nil];
}

#pragma mark - Item Actions

- (void)settings:(id)sender
{
    NSString * storyboardName = @"Settings";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle: nil];
    UIViewController * controllerToPresent = [storyboard instantiateViewControllerWithIdentifier:@"SettingsNavigation"];
    [self presentViewController:controllerToPresent animated:YES completion:nil];
}

- (void)archive:(id)sender
{
    [self.naviItem setRightBarButtonItems:@[]];
    [self cancelRequest];
    self.naviItem.titleView = self.segControl;
    if (self.segControl.selectedSegmentIndex == 0) {
        [self presentInternalListForType:S1TopicListHistory];
    } else {
        [self presentInternalListForType:S1TopicListFavorite];
    }
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
    cell.backgroundColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.cell.background.normal"];
    
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
    if (_loadingFlag || _loadingMore) {
        return;
    }
    if(indexPath.row == [self.topics count] - 15)
    {
        NSLog(@"Reach last topic, load more.");
        if ([self.currentKey isEqual: @"Search"]) {
            ;
        } else {
            _loadingMore = YES;
            __weak typeof(self) weakSelf = self;
            [self.dataCenter loadNextPageForKey:self.forumKeyMap[self.currentKey] success:^(NSArray *topicList) {
                __strong typeof(self) strongSelf = weakSelf;
                strongSelf.topics = [topicList mutableCopy];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf.tableView reloadData];
                    _loadingMore = NO;
                });
            } failure:^(NSError *error) {
                _loadingMore = NO;
                NSLog(@"fail to load more...");
            }];
        }
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 20)];
        [view setBackgroundColor:[[S1ColorManager sharedInstance] colorForKey:@"topiclist.tableview.header.background"]];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, self.view.bounds.size.width, 20)];
        NSMutableAttributedString *labelTitle = [[NSMutableAttributedString alloc] initWithString:[self.topicHeaderTitles objectAtIndex:section] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:12.0], NSForegroundColorAttributeName: [[S1ColorManager sharedInstance] colorForKey:@"topiclist.tableview.header.text"]}];
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

#pragma mark Tab Bar Delegate

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key
{
    self.naviItem.titleView = self.titleLabel;
    self.searchBar.text = @"";
    _loadingMore = NO;
    [self.naviItem setRightBarButtonItem:self.historyItem];
    
    if (self.refreshControl.hidden) { self.refreshControl.hidden = NO; }
    NSDate *lastRefreshDateForKey = [self.cachedLastRefreshTime valueForKey:key];
    //NSLog(@"cache: %@, date: %@",self.cachedLastRefreshTime, lastRefreshDateForKey);
    //NSLog(@"diff: %f", [[NSDate date] timeIntervalSinceDate:lastRefreshDateForKey]);
    if (lastRefreshDateForKey && ([[NSDate date] timeIntervalSinceDate:lastRefreshDateForKey] <= 20.0)) {
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

#pragma mark UISearchBar Delegate

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
    
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        [self.searchBar resignFirstResponder];
        NSString *text = searchBar.text;
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        NSNumber *topicID = [nf numberFromString:text];
        if (topicID != nil) {
            S1Topic *topic = [self.dataCenter tracedTopic:topicID];
            if (topic == nil) {
                topic = [[S1Topic alloc] init];
                topic.topicID = topicID;
            }
            S1ContentViewController *contentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"Content"];
            [contentViewController setTopic:topic];
            [contentViewController setDataCenter:self.dataCenter];
            [[self navigationController] pushViewController:contentViewController animated:YES];
            return;
            
        }
    } else { // search topics
        [self.searchBar resignFirstResponder];
        _loadingFlag = YES;
        self.scrollTabBar.enabled = NO;
        S1HUD *HUD;
        HUD = [S1HUD showHUDInView:self.view];
        [HUD showActivityIndicator];
        if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
            [self cancelRequest];
            self.cachedContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
        }
        self.previousKey = self.currentKey;
        self.currentKey = @"Search";
        self.refreshControl.hidden = YES;
        
        [self.dataCenter searchTopicsForKeyword:searchBar.text success:^(NSArray *topicList) {
            self.topics = [topicList mutableCopy];
            [self.tableView reloadData];
            if (self.topics && self.topics.count > 0) {
                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
            [self.scrollTabBar deselectAll];
            self.scrollTabBar.enabled = YES;
            [HUD hideWithDelay:0.3];
            _loadingFlag = NO;
        } failure:^(NSError *error) {
            if (error.code == -999) {
                NSLog(@"Code -999 may means user want to cancel this request.");
                [HUD hideWithDelay:0];
            } else {
                [HUD setText:@"Request Failed" withWidthMultiplier:2];
                [HUD hideWithDelay:0.3];
            }
            self.scrollTabBar.enabled = YES;
            if (self.refreshControl.refreshing) {
                [self.refreshControl endRefreshing];
            }
            _loadingFlag = NO;
        }];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.tableView.contentOffset.y > 0) {
        [self.searchBar resignFirstResponder];
    }
    
}

- (void)clearSearchBarText:(UISwipeGestureRecognizer *)gestureRecognizer {
    self.searchBar.text = @"";
    [self.searchBar.delegate searchBar:self.searchBar textDidChange:@""];
}


#pragma mark - Orientation

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"]) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            return UIInterfaceOrientationMaskPortrait;
        }
    }
    return [super supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"]) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            return UIInterfaceOrientationPortrait;
        }
    }
    return [super preferredInterfaceOrientationForPresentation];
}


#pragma mark Networking

- (void)fetchTopicsForKey:(NSString *)key shouldRefresh:(BOOL)refresh andScrollToTop:(BOOL)scrollToTop
{
    _loadingFlag = YES;
    self.scrollTabBar.enabled = NO;
    S1HUD *HUD;
    if (refresh || ![self.dataCenter hasCacheForKey:self.forumKeyMap[key]]) {
        HUD = [S1HUD showHUDInView:self.view];
        [HUD showActivityIndicator];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.viewModel topicListForKey:self.forumKeyMap[key] shouldRefresh:refresh success:^(NSArray *topicList) {
        //reload data
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (topicList.count > 0) {
                if (strongSelf.currentKey && (![strongSelf.currentKey  isEqual: @"History"]) && (![strongSelf.currentKey  isEqual: @"Favorite"])) {
                    strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
                }
                strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
                strongSelf.currentKey = key;
                
                strongSelf.topics = [topicList mutableCopy];
                [strongSelf.tableView reloadData];
                if (strongSelf.tableView.hidden) { strongSelf.tableView.hidden = NO; }
                if (strongSelf.cachedContentOffset[key] && !scrollToTop) {
                    [strongSelf.tableView setContentOffset:[strongSelf.cachedContentOffset[key] CGPointValue] animated:NO];
                } else {
                    [strongSelf.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
                }
                //Force scroll to first cell when finish loading. in case cocoa didn't do that for you.
                if (strongSelf.tableView.contentOffset.y < 0) {
                    [strongSelf.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
                }
                [self.cachedLastRefreshTime setValue:[NSDate date] forKey:key];
            } else {
                if (strongSelf.currentKey && (![strongSelf.currentKey  isEqual: @"History"]) && (![strongSelf.currentKey  isEqual: @"Favorite"])) {
                    strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
                }
                strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
                strongSelf.currentKey = key;
                if (![key isEqualToString:strongSelf.previousKey]) {
                    strongSelf.topics = [[NSMutableArray alloc] init];
                    [strongSelf.tableView reloadData];
                }
            }
            //hud hide
            if (refresh || ![strongSelf.dataCenter hasCacheForKey:key]) {
                [HUD hideWithDelay:0.3];
            }
            //others
            strongSelf.scrollTabBar.enabled = YES;
            if (strongSelf.refreshControl.refreshing) {
                [strongSelf.refreshControl endRefreshing];
            }
            
            [strongSelf.searchBar setHidden: ([strongSelf.dataCenter canMakeSearchRequest] == NO)];
            _loadingFlag = NO;
        });
    } failure:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (error.code == -999) {
            NSLog(@"Code -999 may means user want to cancel this request.");
            [HUD hideWithDelay:0];
            //others
            strongSelf.scrollTabBar.enabled = YES;
            if (strongSelf.refreshControl.refreshing) {
                [strongSelf.refreshControl endRefreshing];
            }
            _loadingFlag = NO;
        } else {
            //reload data
            if (strongSelf.currentKey && (![strongSelf.currentKey  isEqual: @"History"]) && (![strongSelf.currentKey  isEqual: @"Favorite"])) {
                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
            }
            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
            strongSelf.currentKey = key;
            if (![key isEqualToString:strongSelf.previousKey]) {
                strongSelf.topics = [[NSMutableArray alloc] init];
                [strongSelf.tableView reloadData];
            }
            //hud hide
            if (refresh || ![strongSelf.dataCenter hasCacheForKey:key]) {
                if (error.code == -999) {
                    NSLog(@"Code -999 may means user want to cancel this request.");
                    [HUD hideWithDelay:0];
                } else {
                    [HUD setText:@"Request Failed" withWidthMultiplier:2];
                    [HUD hideWithDelay:0.3];
                }
            }
            
            //others
            strongSelf.scrollTabBar.enabled = YES;
            if (strongSelf.refreshControl.refreshing) {
                [strongSelf.refreshControl endRefreshing];
            }
            _loadingFlag = NO;
        }
        
    }];
}


#pragma mark Helpers

- (NSArray *)keys
{
    return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"] objectAtIndex:0];
}

- (void)updateTabbar:(NSNotification *)notification
{
    [self.scrollTabBar setKeys:[self keys]];
    if ([self.currentKey isEqual: @"History"] || [self.currentKey isEqual: @"Favorite"]) {
        self.cachedContentOffset = nil;
    } else {
        self.tableView.hidden = YES;
        self.topics = [NSMutableArray array];
        self.previousKey = @"";
        self.currentKey = @"";
        self.cachedContentOffset = nil;
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



- (void)presentInternalListForType:(S1InternalTopicListType)type
{
    if (self.currentKey && (![self.currentKey  isEqual: @"History"]) && (![self.currentKey  isEqual: @"Favorite"])) {
        [self cancelRequest];
        self.cachedContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
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
        if ([strongMyself.currentKey isEqualToString:type == S1TopicListHistory ? @"History" : @"Favorite"]) {
            strongMyself.topics = [fullResult valueForKey:@"topics"];
            strongMyself.topicHeaderTitles = [fullResult valueForKey:@"headers"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongMyself.tableView reloadData];
            });
        }
    }];
    self.topics = [result valueForKey:@"topics"];
    self.topicHeaderTitles = [result valueForKey:@"headers"];
    
    [self.tableView reloadData];
    if (self.topics && self.topics.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
    [self.scrollTabBar deselectAll];
    
}
#pragma mark - Observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentInset"]) {
        return;
    }
    if ([keyPath isEqualToString:@"contentOffset"]) {
        if ([self.currentKey isEqualToString:@"History"] || [self.currentKey isEqualToString:@"Favorite"]) {
            if ([[change objectForKey:@"new"] CGPointValue].y < -10) {
                [self.searchBar becomeFirstResponder];
            }
        }
        //NSLog(@"%f",[[change objectForKey:@"new"] CGPointValue].y);
        return;
    }
}

/*
- (void)handlePasteboardString:(NSString *)URL
{
    if (!URL) {
        return;
    }
    if (NO) {
        S1Topic *clipboardTopic = [S1Parser extract];
        NSLog(@"Open Clipboard topic ID: %@", clipboardTopic.topicID);
        [clipboardTopic addDataFromTracedTopic:[self.dataCenter tracedTopic:topicID]];
    }
    
}

- (void)handleDatabaseImport:(NSURL *)databaseURL {
    [self.dataCenter handleDatabaseImport:databaseURL];
}
 */

#pragma mark - Getters and Setters

- (UINavigationBar *)navigationBar {
    if (!_navigationBar) {
        _navigationBar = [[UINavigationBar alloc] init];
        _navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, _UPPER_BAR_HEIGHT);
        _navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_navigationBar pushNavigationItem:self.naviItem animated:NO];
    }
    return _navigationBar;
}

- (UINavigationItem *)naviItem {
    if (!_naviItem) {
        _naviItem = [[UINavigationItem alloc] init];
        _naviItem.titleView = self.titleLabel;
        _naviItem.leftBarButtonItem = self.settingsItem;
        _naviItem.rightBarButtonItem = self.historyItem;
    }
    return _naviItem;
}

- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"Stage1st";
        _titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
        _titleLabel.textColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.navigationbar.titlelabel"];
        [_titleLabel sizeToFit];
    }
    return _titleLabel;
}

- (UIBarButtonItem *)historyItem {
    if (!_historyItem) {
        _historyItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Archive"] style:UIBarButtonItemStyleBordered target:self action:@selector(archive:)];
    }
    return _historyItem;
}

- (UIBarButtonItem *)settingsItem {
    if (!_settingsItem) {
        _settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Settings"] style:UIBarButtonItemStyleBordered target:self action:@selector(settings:)];
    }
    return _settingsItem;
}

- (UISearchBar *)searchBar {
    if (!_searchBar) {
        _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, _SEARCH_BAR_HEIGHT)];
        _searchBar.delegate = self;
        if ([[S1ColorManager sharedInstance] isDarkTheme]) {
            _searchBar.searchBarStyle = UISearchBarStyleMinimal;
        }
        _searchBar.tintColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.searchbar.tint"];
        _searchBar.barTintColor = [[S1ColorManager sharedInstance] colorForKey:@"topiclist.searchbar.bartint"];
        _searchBar.placeholder = NSLocalizedString(@"TopicListView_SearchBar_Hint", @"Search");
        //[_searchBar setSearchFieldBackgroundImage:[S1Global imageWithColor:[[S1ColorManager sharedInstance] color4] size:CGSizeMake(self.view.bounds.size.width, 32)] forState:UIControlStateNormal];
        UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(clearSearchBarText:)];
        gestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
        [_searchBar addGestureRecognizer:gestureRecognizer];
    }
    return _searchBar;
}

- (UISegmentedControl *)segControl {
    if (!_segControl) {
        _segControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"TopicListView_SegmentControl_History", @"History"),NSLocalizedString(@"TopicListView_SegmentControl_Favorite", @"Favorite")]];
        [_segControl setWidth:80 forSegmentAtIndex:0];
        [_segControl setWidth:80 forSegmentAtIndex:1];
        [_segControl addTarget:self action:@selector(segSelected:) forControlEvents:UIControlEventValueChanged];
        [_segControl setSelectedSegmentIndex:0];
    }
    return _segControl;
}

- (NSDictionary *)forumKeyMap
{
    if (!_forumKeyMap) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"ForumKeyMap" ofType:@"plist"];
        _forumKeyMap = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return _forumKeyMap;
}

- (NSMutableDictionary *)cachedContentOffset
{
    if(!_cachedContentOffset) {
        _cachedContentOffset = [NSMutableDictionary dictionary];
    }
    return _cachedContentOffset;
}

- (NSMutableDictionary *)cachedLastRefreshTime {
    if (!_cachedLastRefreshTime) {
        _cachedLastRefreshTime = [NSMutableDictionary dictionary];
    }
    return _cachedLastRefreshTime;
}

@end
