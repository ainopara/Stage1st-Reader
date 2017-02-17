//
//  S1TopicListViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1AppDelegate.h"
#import "S1TopicListViewController.h"
#import "SettingsViewController.h"
#import "S1TopicListCell.h"
#import "S1HUD.h"
#import "S1Topic.h"
#import "S1TabBar.h"
#import "S1DataCenter.h"
#import "Masonry.h"

#import "ODRefreshControl.h"
#import "DatabaseManager.h"
#import "CloudKitManager.h"

#import "NavigationControllerDelegate.h"
#import <Crashlytics/Answers.h>

#import <YapDatabase/YapDatabase.h>
#import <YapDatabase/YapDatabaseFilteredView.h>
#import <YapDatabase/YapDatabaseSearchResultsView.h>
#import <YapDatabase/YapDatabaseView.h>
#import <YapDatabase/YapDatabaseCloudKit.h>

static NSString * const cellIdentifier = @"TopicCell";

#define _SEARCH_BAR_HEIGHT 40.0f

@interface S1TopicListViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, S1TabBarDelegate>
// UI
@property (nonatomic, strong) UINavigationBar *navigationBar;
@property (nonatomic, strong) UINavigationItem *naviItem;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIBarButtonItem *historyItem;
@property (nonatomic, strong) AnimationButton *archiveButton;
@property (nonatomic, strong) UIBarButtonItem *settingsItem;
@property (nonatomic, strong) UISegmentedControl *segControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) ODRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) S1TabBar *scrollTabBar;

@property (nonatomic, strong) S1HUD *refreshHUD;
// Model
@property (nonatomic, strong) S1DataCenter *dataCenter;
@property (nonatomic, strong) S1TopicListViewModel *viewModel;

@property (nonatomic, strong) NSString *currentKey;
@property (nonatomic, strong) NSString *previousKey;
@property (nonatomic, strong) NSString *searchKeyword;
@property (nonatomic, strong) NSMutableArray<S1Topic *> *topics;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *cachedContentOffset;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *cachedLastRefreshTime;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *forumKeyMap;

@end

#pragma mark -

@implementation S1TopicListViewController {
    BOOL _loadingFlag;
    BOOL _loadingMore;
}

#pragma mark - Life Cycle

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _loadingFlag = NO;
        _loadingMore = NO;
        _currentKey = @"";
        _previousKey = @"";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.dataCenter = [S1DataCenter sharedDataCenter];
    self.viewModel = [[S1TopicListViewModel alloc] initWithDataCenter:self.dataCenter];
    
    self.view.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.background"];
    
    //Setup Navigation Bar
    [self.view addSubview:self.navigationBar];
    [self.navigationBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_top);
        make.leading.with.trailing.equalTo(self.view);
        make.bottom.equalTo(self.mas_topLayoutGuideBottom).offset(44);
    }];

    //Setup Table View
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.navigationBar.mas_bottom);
        make.leading.with.trailing.equalTo(self.view);
    }];
    
    //Setup Tab Bar
    [self.view addSubview:self.scrollTabBar];
    [self.scrollTabBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.tableView.mas_bottom);
        make.leading.with.trailing.equalTo(self.view);
        make.bottom.equalTo(self.mas_bottomLayoutGuideTop);
    }];

    [self.view addSubview:self.refreshHUD];
    [self.refreshHUD mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];

    //Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabbar:) name:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableData:) name:@"S1TopicUpdateNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePaletteChangeNotification:) name:@"APPaletteDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseConnectionDidUpdate:) name:UIDatabaseConnectionDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitStateChanged:) name:YapDatabaseCloudKitStateChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitStateChanged:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)dealloc {
    DDLogDebug(@"[TopicListVC] Dealloced");
    [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
    [self.tableView removeObserver:self forKeyPath:@"contentInset"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    DDLogInfo(@"[TopicListVC] viewWillAppear");

    [self updateArchiveIcon];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    DDLogDebug(@"[TopicListVC] viewDidAppear");
    [CrashlyticsKit setObjectValue:@"TopicListViewController" forKey:@"lastViewController"];

    [self.tableView setUserInteractionEnabled:YES];
    [self.tableView setScrollsToTop:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.tableView setUserInteractionEnabled:NO];
    [self.tableView setScrollsToTop:NO];
}

#pragma mark - Actions

- (void)settings:(id)sender {
    NSString * storyboardName = @"Settings";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle: nil];
    UIViewController * controllerToPresent = [storyboard instantiateViewControllerWithIdentifier:@"SettingsNavigation"];
    [self presentViewController:controllerToPresent animated:YES completion:nil];
}

- (void)archive:(id)sender {
    [self.naviItem setRightBarButtonItems:@[]];
    [self cancelRequest];
    self.naviItem.titleView = self.segControl;
    if (self.segControl.selectedSegmentIndex == 0) {
        [self presentInternalListForType:S1TopicListHistory];
    } else {
        [self presentInternalListForType:S1TopicListFavorite];
    }
}

- (void)refresh:(id)sender {
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

-(void)segSelected:(UISegmentedControl *)seg {
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

- (void)clearSearchBarText:(UISwipeGestureRecognizer *)gestureRecognizer {
    self.searchBar.text = @"";
    [self.searchBar.delegate searchBar:self.searchBar textDidChange:@""];
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        return [self.viewModel numberOfSections];
    }

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        return [self.viewModel numberOfItemsInSection:section];
    }
    
    return [self.topics count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    S1TopicListCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[S1TopicListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.cell.background.normal"];
    
    if ([self isPresentingDatabaseList:self.currentKey]) {
        [cell setTopic:[self.viewModel topicAtIndexPath:indexPath]];
        cell.highlight = self.searchBar.text;
        cell.pinningTop = NO;
        return cell;
    } else if ([self isPresentingSearchList:self.currentKey]) {
        [cell setTopic:self.topics[indexPath.row]];
        cell.highlight = self.searchKeyword;
        cell.pinningTop = NO;
        return cell;
    } else {
        S1Topic *topic = self.topics[indexPath.row];
        [cell setTopic:topic];
        if ([[NSDate date] timeIntervalSince1970] < [topic.lastReplyDate timeIntervalSince1970] ) {
            cell.pinningTop = YES;
        } else {
            cell.pinningTop = NO;
        }

        cell.highlight = @"";
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    S1ContentViewController *contentViewController;
    if ([self isPresentingDatabaseList:self.currentKey]) {
        S1Topic *topic = [self.viewModel topicAtIndexPath:indexPath];
        if (topic == nil) {
            DDLogError(@"[TopicList] Can not get valid topic from database.");
            return;
        }
        contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:self.dataCenter];
    } else {
        S1Topic *topic = self.topics[indexPath.row];
        S1Topic *processedTopic = [self.viewModel topicWithTracedDataForTopic:topic];
        [self.topics replaceObjectAtIndex:indexPath.row withObject:processedTopic];

        contentViewController = [[S1ContentViewController alloc] initWithTopic:processedTopic dataCenter:self.dataCenter];
    }

    [self.navigationController pushViewController:contentViewController animated:YES];

}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self isPresentingDatabaseList:self.currentKey];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if ([self.currentKey isEqualToString: @"History"]) {
            [self.viewModel deleteTopicAtIndexPath:indexPath];
        }
        if ([self.currentKey isEqualToString: @"Favorite"]) {
            [self.viewModel unfavoriteTopicAtIndexPath:indexPath];
        }
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *) cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        return;
    }
    if (_loadingFlag || _loadingMore) {
        return;
    }
    // Normal Case and Search Case
    if(indexPath.row == [self.topics count] - 15)
    {
        if ([self.currentKey isEqual: @"Search"]) {
            return;
        }
        self.tableView.tableFooterView = [self footerView];
        DDLogDebug(@"[TopicListVC] Reach (almost) last topic, load more.");
        _loadingMore = YES;
        __weak __typeof__(self) weakSelf = self;
        [self.viewModel loadNextPageForKey:self.forumKeyMap[self.currentKey] success:^(NSArray<S1Topic *> *topicList) {
            __strong __typeof__(self) strongSelf = weakSelf;
            strongSelf.topics = [topicList mutableCopy];
            strongSelf.tableView.tableFooterView = nil;
            [strongSelf.tableView reloadData];
            strongSelf->_loadingMore = NO;
        } failure:^(NSError *error) {
            __strong __typeof__(self) strongSelf = weakSelf;
            strongSelf.tableView.tableFooterView = nil;
            strongSelf->_loadingMore = NO;
            DDLogDebug(@"[TopicListVC] Fail to load more...");
        }];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        // TODO: Reuse?
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 20)];
        [view setBackgroundColor:[[ColorManager shared] colorForKey:@"topiclist.tableview.header.background"]];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, self.view.bounds.size.width, 20)];
        NSString *groupName = [self.viewModel.viewMappings groupForSection:section];
        if (groupName == nil) {
            [CrashlyticsKit recordError:[NSError errorWithDomain:@"Stage1stReaderApplicationDomain" code:12 userInfo:nil] withAdditionalUserInfo:@{
                @"requestingSection": @(section),
                @"numberOfSections": @(self.viewModel.viewMappings.numberOfSections)
            }];
            groupName = @"Unknown";
        }
        NSMutableAttributedString *labelTitle = [[NSMutableAttributedString alloc] initWithString:groupName attributes:@{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:12.0],
            NSForegroundColorAttributeName: [[ColorManager shared] colorForKey:@"topiclist.tableview.header.text"]
        }];
        [label setAttributedText:labelTitle];
        label.backgroundColor = [UIColor clearColor];
        [view addSubview:label];
        
        return view;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        return 20;
    }
    return 0;
}

#pragma mark S1TabBarDelegate

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key {
    self.naviItem.titleView = self.titleLabel;
    self.searchBar.text = @"";
    self.searchBar.placeholder = NSLocalizedString(@"TopicListView_SearchBar_Hint", @"Search");
    _loadingMore = NO;
    [self cancelRequest];
    [self.naviItem setRightBarButtonItem:self.historyItem];
    [self.archiveButton recover];
    
    if (self.refreshControl.hidden) { self.refreshControl.hidden = NO; }
    NSDate *lastRefreshDateForKey = [self.cachedLastRefreshTime valueForKey:key];
    //DDLogDebug(@"cache: %@, date: %@",self.cachedLastRefreshTime, lastRefreshDateForKey);
    //DDLogDebug(@"diff: %f", [[NSDate date] timeIntervalSinceDate:lastRefreshDateForKey]);
    if (lastRefreshDateForKey && ([[NSDate date] timeIntervalSinceDate:lastRefreshDateForKey] <= 20.0)) {
        if (![self.currentKey isEqualToString:key]) {
            DDLogDebug(@"load key: %@ current key: %@ previous key: %@", key, self.currentKey, self.previousKey);
            [self fetchTopicsForKey:key shouldRefresh:NO andScrollToTop:NO];
        } else { //press the key that selected currently
            DDLogDebug(@"refresh key: %@ current key: %@ previous key: %@", key, self.currentKey, self.previousKey);
            [self fetchTopicsForKey:key shouldRefresh:YES andScrollToTop:YES];
        }
    } else {
        //Force refresh
        [self fetchTopicsForKey:key shouldRefresh:YES andScrollToTop:YES];
    }
    
}

#pragma mark UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        [self.viewModel updateFilter:searchText key:self.currentKey];
        for (S1TopicListCell *cell in [self.tableView visibleCells]) {
            cell.highlight = searchText;
        }
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        [self.searchBar resignFirstResponder];
        NSString *text = searchBar.text;
        NSNumber *topicID = [[[NSNumberFormatter alloc] init] numberFromString:text];
        if (topicID != nil) {
            S1Topic *topic = [self.dataCenter tracedTopic:topicID];
            if (topic == nil) {
                topic = [[S1Topic alloc] initWithTopicID:topicID];
            }
            S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:self.dataCenter];
            [[self navigationController] pushViewController:contentViewController animated:YES];
            return;
        }
    } else { // search topics
        [self.searchBar resignFirstResponder];
        _loadingFlag = YES;
        self.scrollTabBar.enabled = NO;
        [self.refreshHUD showActivityIndicator];
        if (self.currentKey && [self isPresentingForumList:self.currentKey]) {
            [self cancelRequest];
            self.cachedContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
        }
        self.previousKey = self.currentKey;
        self.currentKey = @"Search";
        self.searchKeyword = self.searchBar.text;
        self.refreshControl.hidden = YES;
        
        [self.dataCenter searchTopicsForKeyword:searchBar.text success:^(NSArray *topicList) {
            self.topics = [topicList mutableCopy];
            [self.tableView reloadData];
            if (self.topics && self.topics.count > 0) {
                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
            [self.scrollTabBar deselectAll];
            self.scrollTabBar.enabled = YES;
            [self.refreshHUD hideWithDelay:0.3];
            _loadingFlag = NO;
        } failure:^(NSError *error) {
            if (error.code == NSURLErrorCancelled) {
                DDLogDebug(@"[Network] NSURLErrorCancelled");
                [self.refreshHUD hideWithDelay:0];
            } else {
                [self.refreshHUD showMessage:@"Request Failed"];
                [self.refreshHUD hideWithDelay:0.3];
            }
            self.scrollTabBar.enabled = YES;
            if (self.refreshControl.refreshing) {
                [self.refreshControl endRefreshing];
            }
            _loadingFlag = NO;
        }];
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.tableView.contentOffset.y > 0) {
        [self.searchBar resignFirstResponder];
    }
}

#pragma mark - Layout

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && [[NSUserDefaults standardUserDefaults] boolForKey:@"ForcePortraitForPhone"]) {
        return;
    }

    DDLogDebug(@"[TopicListVC] View Will Change To Size: h%f, w%f",size.height, size.width);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"S1ViewWillTransitionToSizeNotification" object:[NSValue valueWithCGSize:size]];
    CGRect frame = self.view.frame;
    frame.size = size;
    self.view.frame = frame;
}

#pragma mark Networking

- (void)fetchTopicsForKey:(NSString *)key shouldRefresh:(BOOL)refresh andScrollToTop:(BOOL)scrollToTop {
    NSString *forumID = self.forumKeyMap[key];
    if (forumID == nil) {
        return;
    }
    _loadingFlag = YES;
    self.scrollTabBar.enabled = NO;
    if (refresh || ![self.dataCenter hasCacheForKey:forumID]) {
        [self.refreshHUD showActivityIndicator];
    }
    
    __weak __typeof__(self) weakSelf = self;
    [self.viewModel topicListForKey:forumID refresh:refresh success:^(NSArray *topicList) {
        //reload data
        __strong __typeof__(self) strongSelf = weakSelf;
        if (topicList.count > 0) {
            if (strongSelf.currentKey && [self isPresentingForumList:self.currentKey]) {
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
            if (strongSelf.currentKey && [self isPresentingForumList:self.currentKey]) {
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
            [self.refreshHUD hideWithDelay:0.3];
        }
        //others
        strongSelf.scrollTabBar.enabled = YES;
        if (strongSelf.refreshControl.refreshing) {
            [strongSelf.refreshControl endRefreshing];
        }
        
        strongSelf.searchBar.hidden = ![strongSelf.dataCenter canMakeSearchRequest];
        _loadingFlag = NO;

    } failure:^(NSError *error) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if (error.code == NSURLErrorCancelled) {
            DDLogDebug(@"[Network] NSURLErrorCancelled");
            [self.refreshHUD hideWithDelay:0];
            //others
            strongSelf.scrollTabBar.enabled = YES;
            if (strongSelf.refreshControl.refreshing) {
                [strongSelf.refreshControl endRefreshing];
            }
            _loadingFlag = NO;
        } else {
            //reload data
            if (strongSelf.currentKey && [self isPresentingForumList:self.currentKey]) {
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
                if (error.code == NSURLErrorCancelled) {
                    DDLogDebug(@"[Network] NSURLErrorCancelled");
                    [self.refreshHUD hideWithDelay:0];
                } else {
                    DDLogWarn(@"[Network] error: %ld (%@)", (long)error.code, error.description);
                    [self.refreshHUD showMessage:@"Request Failed"];
                    [self.refreshHUD hideWithDelay:0.3];
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

#pragma mark Notification

- (void)updateTabbar:(NSNotification *)notification {
    [self.scrollTabBar setKeys:[self keys]];
    if ([self isPresentingDatabaseList:self.currentKey]) {
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

- (void)reloadTableData:(NSNotification *)notification {
    if (![self isPresentingDatabaseList:self.currentKey]) {
        [self.tableView reloadData];
    }
}

- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
    self.view.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.background"];
    self.tableView.separatorColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.separator"];
    self.tableView.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.background"];
    self.tableView.indicatorStyle = [[ColorManager shared] isDarkTheme] ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleDefault;
    if (self.tableView.backgroundView) {
        self.tableView.backgroundView.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.background"];
    }
    self.refreshControl.tintColor = [[ColorManager shared] colorForKey:@"topiclist.refreshcontrol.tint"];
    self.titleLabel.textColor = [[ColorManager shared] colorForKey:@"topiclist.navigationbar.titlelabel"];
    if ([[ColorManager shared] isDarkTheme]) {
        self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    } else {
        self.searchBar.searchBarStyle = UISearchBarStyleDefault;
    }
    self.searchBar.tintColor = [[ColorManager shared] colorForKey:@"topiclist.searchbar.tint"];
    self.searchBar.barTintColor = [[ColorManager shared] colorForKey:@"topiclist.searchbar.bartint"];
    self.searchBar.keyboardAppearance = [[ColorManager shared] isDarkTheme] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar reloadInputViews];
    }

    [self.tableView reloadData];
    [self.scrollTabBar updateColor];
    [self.navigationBar setBarTintColor:[[ColorManager shared]  colorForKey:@"appearance.navigationbar.bartint"]];
    [self.navigationBar setTintColor:[[ColorManager shared]  colorForKey:@"appearance.navigationbar.tint"]];
    [self.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [[ColorManager shared] colorForKey:@"appearance.navigationbar.title"],
                                                           NSFontAttributeName:[UIFont boldSystemFontOfSize:17.0],}];
    self.archiveButton.tintColor = [[ColorManager shared] colorForKey:@"topiclist.navigationbar.titlelabel"];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification {
    DDLogVerbose(@"[TopicListVC] database connection did update.");
    if (self.viewModel.viewMappings == nil) {
        [self.viewModel initializeMappings];
        
        return;
    }

    [self.viewModel updateMappings];

    // If the view isn't visible, we might decide to skip the UI animation stuff.
    if (!(self.isViewLoaded && self.view.window)) {
        return;
    }

    if ([self isPresentingDatabaseList:self.currentKey]) {
        [self.tableView reloadData];
        self.searchBar.placeholder = [self.viewModel searchBarPlaceholderStringForCurrentKey:self.currentKey];
    }
}

- (void)cloudKitStateChanged:(NSNotification *)notification {
    [self updateArchiveIcon];
}

#pragma mark Helpers

- (void)updateArchiveIcon {
    NSUInteger suspendCount = [MyDatabaseManager.cloudKitExtension suspendCount];

    NSUInteger inFlightCount = 0;
    NSUInteger queuedCount = 0;
    [MyDatabaseManager.cloudKitExtension getNumberOfInFlightChangeSets:&inFlightCount queuedChangeSets:&queuedCount];
    NSString *titleString = @"";
    switch ([MyCloudKitManager state]) {
        case CKManagerStateInit:
            [self.archiveButton stopAnimation];
            titleString = [@"Init/" stringByAppendingString:titleString];
            break;
        case CKManagerStateSetup:
            [self.archiveButton stopAnimation];
            titleString = [@"Setup/" stringByAppendingString:titleString];
            break;
        case CKManagerStateFetching:
            [self.archiveButton startAnimation];
            titleString = [@"Fetching/" stringByAppendingString:titleString];
            break;
        case CKManagerStateUploading:
            [self.archiveButton startAnimation];
            titleString = [@"Uploading/" stringByAppendingString:titleString];
            break;
        case CKManagerStateReady:
            [self.archiveButton stopAnimation];
            titleString = [@"Ready/" stringByAppendingString:titleString];
            break;
        case CKManagerStateRecovering:
            [self.archiveButton stopAnimation];
            titleString = [@"Recovering/" stringByAppendingString:titleString];
            break;
        case CKManagerStateHalt:
            [self.archiveButton stopAnimation];
            titleString = [@"Halt/" stringByAppendingString:titleString];
            break;
            
        default:
            break;
    }
    
    if (suspendCount > 0){
        titleString = [titleString stringByAppendingString:[NSString stringWithFormat:@"Suspended (suspendCount = %lu) - InFlight(%lu), Queued(%lu)", (unsigned long)suspendCount, (unsigned long)inFlightCount, (unsigned long)queuedCount]];
    } else {
        titleString = [titleString stringByAppendingString:[NSString stringWithFormat:@"Resumed - InFlight(%lu), Queued(%lu)", (unsigned long)inFlightCount, (unsigned long)queuedCount]];
    }
    DDLogDebug(@"[CloudKit] %@", titleString);
}

- (NSArray *)keys {
    return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"] objectAtIndex:0];
}

- (void)cancelRequest {
    [self.dataCenter cancelRequest];
}

- (void)presentInternalListForType:(S1InternalTopicListType)type {
    if (self.currentKey && [self isPresentingForumList:self.currentKey]) {
        [self cancelRequest];
        self.cachedContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
    }
    self.previousKey = self.currentKey;
    self.currentKey = type == S1TopicListHistory ? @"History" : @"Favorite";
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;
    }
    self.refreshControl.hidden = YES;
    
    [self.tableView reloadData];
    [self.viewModel updateFilter:self.searchBar.text key:self.currentKey];
    
    [self.tableView setContentOffset:CGPointZero animated:NO];
    
    [self.scrollTabBar deselectAll];
}

#pragma mark - Observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentInset"]) {
        return;
    }
    if ([keyPath isEqualToString:@"contentOffset"]) {
        if ([self isPresentingDatabaseList:self.currentKey]) {
            if ([[change objectForKey:@"new"] CGPointValue].y < -10) {
                [self.searchBar becomeFirstResponder];
            }
        }
        return;
    }
}

#pragma mark - Getters and Setters

- (UINavigationBar *)navigationBar {
    if (!_navigationBar) {
        _navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
        [_navigationBar pushNavigationItem:self.naviItem animated:NO];
    }
    return _navigationBar;
}

- (UINavigationItem *)naviItem {
    if (!_naviItem) {
        _naviItem = [[UINavigationItem alloc] initWithTitle:@""];
        _naviItem.titleView = self.titleLabel;
        _naviItem.leftBarButtonItem = self.settingsItem;
        _naviItem.rightBarButtonItem = self.historyItem;
    }
    return _naviItem;
}

- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.text = @"Stage1st";
        _titleLabel.font = [UIFont systemFontOfSize:17.0];
        _titleLabel.textColor = [[ColorManager shared] colorForKey:@"topiclist.navigationbar.titlelabel"];
        [_titleLabel sizeToFit];
    }
    return _titleLabel;
}

- (UIBarButtonItem *)historyItem {
    if (!_historyItem) {
        _historyItem = [[UIBarButtonItem alloc] initWithCustomView:self.archiveButton];
        _historyItem.accessibilityLabel = @"Archive";
    }
    return _historyItem;
}

- (AnimationButton *)archiveButton {
    if (!_archiveButton) {
        _archiveButton = [[AnimationButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44) image:[UIImage imageNamed:@"Archive"] images:[self archiveSyncImages]];
        _archiveButton.tintColor = [[ColorManager shared] colorForKey:@"topiclist.navigationbar.titlelabel"];
        [_archiveButton addTarget:self action:@selector(archive:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _archiveButton;
}

- (NSArray<UIImage *> *)archiveSyncImages {
    NSMutableArray<UIImage *> *array = [[NSMutableArray<UIImage *> alloc] init];
    for (NSInteger i = 1; i <= 36; i++) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"Archive-Syncing %ld", (long)i]];
        [array addObject:image];
    }
    return array;
}

- (UIBarButtonItem *)settingsItem {
    if (!_settingsItem) {
        _settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Settings"] style:UIBarButtonItemStylePlain target:self action:@selector(settings:)];
    }
    return _settingsItem;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.rowHeight = 54.0;
        if (!SYSTEM_VERSION_LESS_THAN(@"9.0")) {
            _tableView.cellLayoutMarginsFollowReadableWidth = NO;
        }

        _tableView.separatorInset = UIEdgeInsetsZero;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.separator"];
        _tableView.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.background"];
        if (_tableView.backgroundView) {
            _tableView.backgroundView.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.background"];
        }
        _tableView.hidden = YES;
        _tableView.tableHeaderView = self.searchBar;
        [_tableView.panGestureRecognizer requireGestureRecognizerToFail:MyAppDelegate.navigationDelegate.colorPanRecognizer];

        self.refreshControl = [[ODRefreshControl alloc] initInScrollView:_tableView];
        self.refreshControl.tintColor = [[ColorManager shared] colorForKey:@"topiclist.refreshcontrol.tint"];
        [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];

        [_tableView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        [_tableView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:nil];
    }
    return _tableView;
}

- (UISearchBar *)searchBar {
    if (!_searchBar) {
        _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, _SEARCH_BAR_HEIGHT)];
        _searchBar.delegate = self;
        if ([[ColorManager shared] isDarkTheme]) {
            _searchBar.searchBarStyle = UISearchBarStyleMinimal;
        }
        _searchBar.tintColor = [[ColorManager shared] colorForKey:@"topiclist.searchbar.tint"];
        _searchBar.barTintColor = [[ColorManager shared] colorForKey:@"topiclist.searchbar.bartint"];
        _searchBar.placeholder = NSLocalizedString(@"TopicListView_SearchBar_Hint", @"Search");

        UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(clearSearchBarText:)];
        gestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
        [_searchBar addGestureRecognizer:gestureRecognizer];
        _searchBar.accessibilityLabel = @"Search Bar";
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

- (S1TabBar *)scrollTabBar {
    if (!_scrollTabBar) {
        _scrollTabBar = [[S1TabBar alloc] initWithFrame:CGRectZero];
        _scrollTabBar.keys = [self keys];
        _scrollTabBar.tabbarDelegate = self;
    }
    return _scrollTabBar;
}

- (NSDictionary *)forumKeyMap {
    if (_forumKeyMap == nil) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"ForumKeyMap" ofType:@"plist"];
        _forumKeyMap = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return _forumKeyMap;
}

- (NSMutableDictionary *)cachedContentOffset {
    if(_cachedContentOffset == nil) {
        _cachedContentOffset = [NSMutableDictionary dictionary];
    }
    return _cachedContentOffset;
}

- (NSMutableDictionary *)cachedLastRefreshTime {
    if (_cachedLastRefreshTime == nil) {
        _cachedLastRefreshTime = [NSMutableDictionary dictionary];
    }
    return _cachedLastRefreshTime;
}

- (UIView *)footerView {
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, 40.0)];
    footerView.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.footer.background"];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:16.0],
        NSForegroundColorAttributeName: [[ColorManager shared] colorForKey:@"topiclist.tableview.footer.text"]
    };
    NSMutableAttributedString *labelTitle = [[NSMutableAttributedString alloc] initWithString:@"Loading..." attributes:attributes];
    label.attributedText = labelTitle;
    [footerView addSubview:label];

    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(footerView.mas_centerX);
        make.centerY.equalTo(footerView.mas_centerY);
    }];
    return footerView;
}

- (S1HUD *)refreshHUD {
    if (_refreshHUD == nil) {
        _refreshHUD = [[S1HUD alloc] initWithFrame:CGRectZero];
    }
    return _refreshHUD;
}
@end
