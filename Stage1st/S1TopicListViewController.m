//
//  S1TopicListViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Crashlytics/Answers.h>
#import <YapDatabase/YapDatabase.h>
#import <YapDatabase/YapDatabaseFilteredView.h>
#import <YapDatabase/YapDatabaseSearchResultsView.h>
#import <YapDatabase/YapDatabaseView.h>
#import <YapDatabase/YapDatabaseCloudKit.h>

#import "S1TopicListViewController.h"
#import "S1AppDelegate.h"
#import "SettingsViewController.h"
#import "S1HUD.h"
#import "S1Topic.h"
#import "S1TabBar.h"
#import "ODRefreshControl.h"
#import "DatabaseManager.h"
#import "CloudKitManager.h"
#import "NavigationControllerDelegate.h"

static NSString * const cellIdentifier = @"TopicCell";

#define _SEARCH_BAR_HEIGHT 40.0f

#pragma mark -

@implementation S1TopicListViewController

#pragma mark Life Cycle

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self != nil) {
        _loadingFlag = NO;
        _loadingMore = NO;
        _currentKey = @"";
        _previousKey = @"";

        self.navigationItem = [[UINavigationItem alloc] init];
        self.navigationItem.titleView = self.titleLabel;
        self.navigationItem.leftBarButtonItem = self.settingsItem;
        self.navigationItem.rightBarButtonItem = self.historyItem;
    }
    return self;
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
    [self didReceivePaletteChangeNotification:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    DDLogDebug(@"[TopicListVC] viewDidAppear");
    [CrashlyticsKit setObjectValue:@"TopicListViewController" forKey:@"lastViewController"];
}

#pragma mark - Actions

- (void)settings:(id)sender {
    NSString * storyboardName = @"Settings";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle: nil];
    UIViewController * controllerToPresent = [storyboard instantiateViewControllerWithIdentifier:@"SettingsNavigation"];
    [self presentViewController:controllerToPresent animated:YES completion:nil];
}

- (void)archive:(id)sender {
    [self.navigationItem setRightBarButtonItems:@[]];
    [self.viewModel cancelRequests];
    self.navigationItem.titleView = self.segControl;
    if (self.segControl.selectedSegmentIndex == 0) {
        [self presentInternalListFor:S1TopicListHistory];
    } else {
        [self presentInternalListFor:S1TopicListFavorite];
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
    switch (seg.selectedSegmentIndex) {
        case 0:
            [self presentInternalListFor:S1TopicListHistory];
            break;
        case 1:
            [self presentInternalListFor:S1TopicListFavorite];
            break;
        default:
            break;
    }
}

- (void)clearSearchBarText:(UISwipeGestureRecognizer *)gestureRecognizer {
    self.searchBar.text = @"";
    [self.searchBar.delegate searchBar:self.searchBar textDidChange:@""];
}

#pragma mark S1TabBarDelegate

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key {
    self.navigationItem.titleView = self.titleLabel;
    self.searchBar.text = @"";
    [self.searchBar.delegate searchBar:self.searchBar textDidChange:@""];
    
    self.searchBar.placeholder = NSLocalizedString(@"TopicListViewController.SearchBar_Hint", @"Search");
    _loadingMore = NO;
    [self.viewModel cancelRequests];
    [self.navigationItem setRightBarButtonItem:self.historyItem];
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

- (void)objc_searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if ([self isPresentingDatabaseList:self.currentKey]) {
        [self.searchBar resignFirstResponder];
        NSString *text = searchBar.text;
        NSNumber *topicID = [[[NSNumberFormatter alloc] init] numberFromString:text];
        if (topicID != nil) {
            S1Topic *topic = [self.dataCenter tracedWithTopicID:topicID.integerValue];
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
            [self.viewModel cancelRequests];
            self.cachedContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
        }
        self.previousKey = self.currentKey;
        self.currentKey = @"Search";
        self.searchKeyword = self.searchBar.text;
        self.refreshControl.hidden = YES;

        __weak __typeof__(self) weakSelf = self;
        [self.dataCenter searchTopicsFor:searchBar.text successBlock:^(NSArray *topicList) {
            __strong __typeof__(self) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }

            strongSelf.viewModel.topics = topicList;
            [strongSelf.tableView reloadData];
            if (strongSelf.viewModel.topics.count > 0) {
                [strongSelf.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
            [strongSelf.scrollTabBar deselectAll];
            strongSelf.scrollTabBar.enabled = YES;
            [strongSelf.refreshHUD hideWithDelay:0.3];
            strongSelf->_loadingFlag = NO;
        } failureBlock:^(NSError *error) {
            __strong __typeof__(self) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }

            if (error.code == NSURLErrorCancelled) {
                DDLogDebug(@"[Network] NSURLErrorCancelled");
                [strongSelf.refreshHUD hideWithDelay:0];
            } else {
                [strongSelf.refreshHUD showMessage:@"Request Failed"];
                [strongSelf.refreshHUD hideWithDelay:0.3];
            }
            strongSelf.scrollTabBar.enabled = YES;
            if (strongSelf.refreshControl.refreshing) {
                [strongSelf.refreshControl endRefreshing];
            }
            strongSelf->_loadingFlag = NO;
        }];
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
    if (refresh || ![self.dataCenter hasCacheFor:forumID]) {
        [self.refreshHUD showActivityIndicator];
    }
    
    __weak __typeof__(self) weakSelf = self;
    [self.viewModel topicListForKey:forumID refresh:refresh success:^(NSArray *topicList) {
        //reload data
        __strong __typeof__(self) strongSelf = weakSelf;
//        if (![strongSelf.currentKey isEqualToString:key]) {
//          return;
//        }
        if (topicList.count > 0) {
            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
            }
            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
            strongSelf.currentKey = key;
            
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
            [strongSelf.cachedLastRefreshTime setValue:[NSDate date] forKey:key];
        } else {
            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
            }
            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
            strongSelf.currentKey = key;
        }
        //hud hide
        if (refresh || ![strongSelf.dataCenter hasCacheFor:key]) {
            [strongSelf.refreshHUD hideWithDelay:0.3];
        }
        //others
        strongSelf.scrollTabBar.enabled = YES;
        if (strongSelf.refreshControl.refreshing) {
            [strongSelf.refreshControl endRefreshing];
        }
        
        strongSelf.searchBar.hidden = ![strongSelf.dataCenter canMakeSearchRequest];
        strongSelf.loadingFlag = NO;

    } failure:^(NSError *error) {
        __strong __typeof__(self) strongSelf = weakSelf;
        if ([error.domain isEqualToString:@"Stage1st.DZError"] && error.code == 5) {
            //reload data
            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
            }
            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
            strongSelf.currentKey = key;
            if (![key isEqualToString:strongSelf.previousKey]) {
                strongSelf.viewModel.topics = [[NSMutableArray alloc] init];
                [strongSelf.tableView reloadData];
            }

            // show message then hide hud
            DDLogWarn(@"[Network] error: %@", error.description);
            [strongSelf.refreshHUD showMessage:error.localizedDescription];
            [strongSelf.refreshHUD hideWithDelay:5.0];
        } else if (error.code == NSURLErrorCancelled) {
            // hide hud
            DDLogDebug(@"[Network] NSURLErrorCancelled");
            [strongSelf.refreshHUD hideWithDelay:0];
        } else {
            // reload data
            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
            }
            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
            strongSelf.currentKey = key;
            if (![key isEqualToString:strongSelf.previousKey]) {
                strongSelf.viewModel.topics = [[NSMutableArray alloc] init];
                [strongSelf.tableView reloadData];
            }

            // hide hud
            if (refresh || ![strongSelf.dataCenter hasCacheFor:key]) {
                if (error.code == NSURLErrorCancelled) {
                    DDLogDebug(@"[Network] NSURLErrorCancelled");
                    [strongSelf.refreshHUD hideWithDelay:0];
                } else {
                    DDLogWarn(@"[Network] error: %ld (%@)", (long)error.code, error.description);
                    [strongSelf.refreshHUD showMessage:@"Request Failed"];
                    [strongSelf.refreshHUD hideWithDelay:0.3];
                }
            }
        }

        // clean up
        strongSelf.scrollTabBar.enabled = YES;
        if (strongSelf.refreshControl.refreshing) {
            [strongSelf.refreshControl endRefreshing];
        }
        strongSelf.loadingFlag = NO;
    }];
}

#pragma mark Notification

- (void)updateTabbar:(NSNotification *)notification {
    [self.scrollTabBar setKeys:[self keys]];
    if ([self isPresentingDatabaseList:self.currentKey]) {
        self.cachedContentOffset = nil;
    } else {
        self.tableView.hidden = YES;
        [self.viewModel reset];
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
    self.footerView.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.footer.background"];
    self.footerView.label.textColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.footer.text"];
    [self.scrollTabBar updateColor];

    [self.navigationBar setBarTintColor:[[ColorManager shared] colorForKey:@"appearance.navigationbar.bartint"]];
    [self.navigationBar setTintColor:[[ColorManager shared] colorForKey:@"appearance.navigationbar.tint"]];
    [self.navigationBar setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [[ColorManager shared] colorForKey:@"appearance.navigationbar.title"],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:17.0]
    }];
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
        _navigationBar.delegate = self;
        [_navigationBar pushNavigationItem:self.navigationItem animated:NO];
    }
    return _navigationBar;
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
        _tableView.cellLayoutMarginsFollowReadableWidth = NO;
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
        if (SYSTEM_VERSION_LESS_THAN(@"10.0")) {
            [_tableView.panGestureRecognizer requireGestureRecognizerToFail:MyAppDelegate.navigationDelegate.colorPanRecognizer];
        }

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
        _searchBar.backgroundImage = [[UIImage alloc] init];
        _searchBar.placeholder = NSLocalizedString(@"TopicListViewController.SearchBar_Hint", @"Search");

        UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(clearSearchBarText:)];
        gestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
        [_searchBar addGestureRecognizer:gestureRecognizer];
        _searchBar.accessibilityLabel = @"Search Bar";
    }
    return _searchBar;
}

- (UISegmentedControl *)segControl {
    if (!_segControl) {
        _segControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"TopicListViewController.SegmentControl_History", @"History"),NSLocalizedString(@"TopicListViewController.SegmentControl_Favorite", @"Favorite")]];
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

- (LoadingFooterView *)footerView {
    if (_footerView == nil) {
        _footerView = [[LoadingFooterView alloc] init];
        _footerView.backgroundColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.footer.background"];
        _footerView.label.textColor = [[ColorManager shared] colorForKey:@"topiclist.tableview.footer.text"];
    }

    return _footerView;
}

- (S1HUD *)refreshHUD {
    if (_refreshHUD == nil) {
        _refreshHUD = [[S1HUD alloc] initWithFrame:CGRectZero];
    }
    return _refreshHUD;
}

- (void)setCurrentKey:(NSString *)currentKey {
    _currentKey = currentKey;
    self.viewModel.currentKey = currentKey;
}

@end
