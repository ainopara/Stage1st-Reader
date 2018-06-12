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
#import "SettingsViewController.h"
#import "S1HUD.h"
#import "S1Topic.h"
#import "S1TabBar.h"
#import "ODRefreshControl.h"
#import "DatabaseManager.h"
#import "CloudKitManager.h"
#import "NavigationControllerDelegate.h"

//@implementation S1TopicListViewController
//
//#pragma mark Life Cycle

//- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
//    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//    if (self != nil) {
//        _loadingFlag = NO;
//        _loadingMore = NO;
//        _currentKey = @"";
//        _previousKey = @"";
//
//        self.navigationItem = [[UINavigationItem alloc] init];
//        self.navigationItem.titleView = self.titleLabel;
//        self.navigationItem.leftBarButtonItem = self.settingsItem;
//        self.navigationItem.rightBarButtonItem = self.historyItem;
//    }
//    return self;
//}

//#pragma mark S1TabBarDelegate
//
//- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key {
//    self.navigationItem.titleView = self.titleLabel;
//    self.searchBar.text = @"";
//    [self.searchBar.delegate searchBar:self.searchBar textDidChange:@""];
//
//    _loadingMore = NO;
//    [self.viewModel cancelRequests];
//    [self.navigationItem setRightBarButtonItem:self.historyItem];
//    [self.archiveButton recoverAnimation];
//
//    NSDate *lastRefreshDateForKey = [self.cachedLastRefreshTime valueForKey:key];
//    //DDLogDebug(@"cache: %@, date: %@",self.cachedLastRefreshTime, lastRefreshDateForKey);
//    //DDLogDebug(@"diff: %f", [[NSDate date] timeIntervalSinceDate:lastRefreshDateForKey]);
//    if (lastRefreshDateForKey && ([[NSDate date] timeIntervalSinceDate:lastRefreshDateForKey] <= 20.0)) {
//        if (![self.currentKey isEqualToString:key]) {
//            DDLogDebug(@"load key: %@ current key: %@ previous key: %@", key, self.currentKey, self.previousKey);
//            [self fetchTopicsForKey:key skipCache:NO scrollToTop:NO];
//        } else { //press the key that selected currently
//            DDLogDebug(@"refresh key: %@ current key: %@ previous key: %@", key, self.currentKey, self.previousKey);
//            [self fetchTopicsForKey:key skipCache:YES scrollToTop:YES];
//        }
//    } else {
//        //Force refresh
//        [self fetchTopicsForKey:key skipCache:YES scrollToTop:YES];
//    }
//
//}

#pragma mark UISearchBarDelegate

//- (void)objc_searchBarSearchButtonClicked:(UISearchBar *)searchBar {
//    if ([self isPresentingDatabaseList:self.currentKey]) {
//        [self.searchBar resignFirstResponder];
//        NSString *text = searchBar.text;
//        NSNumber *topicID = [[[NSNumberFormatter alloc] init] numberFromString:text];
//        if (topicID != nil) {
//            S1Topic *topic = [self.dataCenter tracedWithTopicID:topicID.integerValue];
//            if (topic == nil) {
//                topic = [[S1Topic alloc] initWithTopicID:topicID];
//            }
//            S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithTopic:topic dataCenter:self.dataCenter];
//            [[self navigationController] pushViewController:contentViewController animated:YES];
//            return;
//        }
//    } else { // search topics
//        [self.searchBar resignFirstResponder];
//        _loadingFlag = YES;
//        self.scrollTabBar.enabled = NO;
//        [self.refreshHUD showActivityIndicator];
//        if (self.currentKey && [self isPresentingForumList:self.currentKey]) {
//            [self.viewModel cancelRequests];
//            self.cachedContentOffset[self.currentKey] = [NSValue valueWithCGPoint:self.tableView.contentOffset];
//        }
//        self.previousKey = self.currentKey;
//        self.currentKey = @"Search";
//        self.searchKeyword = self.searchBar.text;
//
//        __weak __typeof__(self) weakSelf = self;
//        [self.dataCenter searchTopicsFor:searchBar.text successBlock:^(NSArray *topicList) {
//            __strong __typeof__(self) strongSelf = weakSelf;
//            if (strongSelf == nil) {
//                return;
//            }
//
//            strongSelf.viewModel.topics = topicList;
//            [strongSelf.tableView reloadData];
//            if (strongSelf.viewModel.topics.count > 0) {
//                [strongSelf.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:NO];
//            }
//            [strongSelf.scrollTabBar deselectAll];
//            strongSelf.scrollTabBar.enabled = YES;
//            [strongSelf.refreshHUD hideWithDelay:0.3];
//            strongSelf->_loadingFlag = NO;
//        } failureBlock:^(NSError *error) {
//            __strong __typeof__(self) strongSelf = weakSelf;
//            if (strongSelf == nil) {
//                return;
//            }
//
//            if (error.code == NSURLErrorCancelled) {
//                DDLogDebug(@"[Network] NSURLErrorCancelled");
//                [strongSelf.refreshHUD hideWithDelay:0];
//            } else {
//                [strongSelf.refreshHUD showMessage:@"Request Failed"];
//                [strongSelf.refreshHUD hideWithDelay:0.3];
//            }
//            strongSelf.scrollTabBar.enabled = YES;
//            if (strongSelf.refreshControl.refreshing) {
//                [strongSelf.refreshControl endRefreshing];
//            }
//            strongSelf->_loadingFlag = NO;
//        }];
//    }
//}

#pragma mark Networking

//- (void)fetchTopicsForKey:(NSString *)key skipCache:(BOOL)shouldSkipCache scrollToTop:(BOOL)scrollToTop {
//    NSString *forumID = self.forumKeyMap[key];
//    if (forumID == nil) {
//        return;
//    }
//    self.loadingFlag = YES;
//    self.scrollTabBar.enabled = NO;
//    BOOL hasNoCache = ![self.dataCenter hasCacheFor:forumID];
//    BOOL shouldShowRefreshHUD = shouldSkipCache || hasNoCache;
//    if (shouldShowRefreshHUD) {
//        [self.refreshHUD showActivityIndicator];
//    }
//
//    __weak __typeof__(self) weakSelf = self;
//    [self.viewModel topicListForKey:forumID refresh:shouldSkipCache success:^(NSArray *topicList) {
//        //reload data
//        __strong __typeof__(self) strongSelf = weakSelf;
////        if (![strongSelf.currentKey isEqualToString:key]) {
////          return;
////        }
//
//        if (topicList.count > 0) {
//            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
//                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
//            }
//            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
//            strongSelf.currentKey = key;
//
//            [strongSelf.tableView reloadData];
//
//            if (strongSelf.cachedContentOffset[key] && !scrollToTop) {
//                [strongSelf.tableView setContentOffset:[strongSelf.cachedContentOffset[key] CGPointValue] animated:NO];
//            } else {
//                [strongSelf.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:NO];
//            }
//            //Force scroll to first cell when finish loading. in case cocoa didn't do that for you.
//            if (strongSelf.tableView.contentOffset.y < 0) {
//                DDLogDebug(@"tracking: %d", strongSelf.tableView.tracking);
//                if (!strongSelf.tableView.tracking) {
//                    [strongSelf.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
//                } else {
//                    [strongSelf.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:YES];
//                }
//            }
//            [strongSelf.cachedLastRefreshTime setValue:[NSDate date] forKey:key];
//        } else {
//            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
//                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
//            }
//            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
//            strongSelf.currentKey = key;
//            [strongSelf.tableView reloadData];
//        }
//
//        // hide HUD
//        if (shouldShowRefreshHUD) {
//            [strongSelf.refreshHUD hideWithDelay:0.3];
//        }
//
//        if (strongSelf.refreshControl.refreshing) {
//            [strongSelf.refreshControl endRefreshing];
//        }
//
//        // others
//        strongSelf.scrollTabBar.enabled = YES;
//        strongSelf.searchBar.hidden = ![strongSelf.dataCenter canMakeSearchRequest];
//        strongSelf.loadingFlag = NO;
//
//    } failure:^(NSError *error) {
//        __strong __typeof__(self) strongSelf = weakSelf;
//        if ([error.domain isEqualToString:@"Stage1st.DZError"] && error.code == 5) {
//            //reload data
//            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
//                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
//            }
//            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
//            strongSelf.currentKey = key;
//            if (![key isEqualToString:strongSelf.previousKey]) {
//                strongSelf.viewModel.topics = [[NSMutableArray alloc] init];
//                [strongSelf.tableView reloadData];
//            }
//
//            // show message then hide HUD
//            DDLogWarn(@"[Network] error: %@", error.description);
//            [strongSelf.refreshHUD showMessage:error.localizedDescription];
//            [strongSelf.refreshHUD hideWithDelay:5.0];
//        } else if (error.code == NSURLErrorCancelled) {
//            // hide HUD
//            DDLogDebug(@"[Network] NSURLErrorCancelled");
//            [strongSelf.refreshHUD hideWithDelay:0];
//        } else {
//            // reload data
//            if (strongSelf.currentKey && [strongSelf isPresentingForumList:strongSelf.currentKey]) {
//                strongSelf.cachedContentOffset[strongSelf.currentKey] = [NSValue valueWithCGPoint:strongSelf.tableView.contentOffset];
//            }
//            strongSelf.previousKey = strongSelf.currentKey == nil ? @"" : strongSelf.currentKey;
//            strongSelf.currentKey = key;
//            if (![key isEqualToString:strongSelf.previousKey]) {
//                strongSelf.viewModel.topics = [[NSMutableArray alloc] init];
//                [strongSelf.tableView reloadData];
//            }
//
//            // hide hud
//            if (shouldShowRefreshHUD) {
//                if (error.code == NSURLErrorCancelled) {
//                    DDLogDebug(@"[Network] NSURLErrorCancelled");
//                    [strongSelf.refreshHUD hideWithDelay:0];
//                } else {
//                    DDLogWarn(@"[Network] error: %ld (%@)", (long)error.code, error.description);
//                    [strongSelf.refreshHUD showMessage:@"Request Failed"];
//                    [strongSelf.refreshHUD hideWithDelay:0.3];
//                }
//            }
//        }
//
//        // clean up
//        if (strongSelf.refreshControl.refreshing) {
//            [strongSelf.refreshControl endRefreshing];
//        }
//
//        strongSelf.searchBar.hidden = ![strongSelf.dataCenter canMakeSearchRequest];
//        strongSelf.scrollTabBar.enabled = YES;
//        strongSelf.loadingFlag = NO;
//    }];
//}

#pragma mark Notification

//- (void)updateTabbar:(NSNotification *)notification {
//    [self.scrollTabBar setKeys:[self keys]];
//    if ([self isPresentingDatabaseList:self.currentKey]) {
//        [self.cachedContentOffset removeAllObjects];
//    } else {
//        [self.viewModel reset];
//        self.previousKey = @"";
//        self.currentKey = @"";
//        [self.cachedContentOffset removeAllObjects];
//        [self.tableView reloadData];
//    }
//}

#pragma mark Helpers

//- (void)updateArchiveIcon {
//    NSUInteger suspendCount = [MyDatabaseManager.cloudKitExtension suspendCount];
//
//    NSUInteger inFlightCount = 0;
//    NSUInteger queuedCount = 0;
//    [MyDatabaseManager.cloudKitExtension getNumberOfInFlightChangeSets:&inFlightCount queuedChangeSets:&queuedCount];
//    NSString *titleString = @"";
//    switch ([MyCloudKitManager state]) {
//        case CKManagerStateInit:
//            [self.archiveButton stopAnimation];
//            titleString = [@"Init/" stringByAppendingString:titleString];
//            break;
//        case CKManagerStateSetup:
//            [self.archiveButton stopAnimation];
//            titleString = [@"Setup/" stringByAppendingString:titleString];
//            break;
//        case CKManagerStateFetching:
//            [self.archiveButton startAnimation];
//            titleString = [@"Fetching/" stringByAppendingString:titleString];
//            break;
//        case CKManagerStateUploading:
//            [self.archiveButton startAnimation];
//            titleString = [@"Uploading/" stringByAppendingString:titleString];
//            break;
//        case CKManagerStateReady:
//            [self.archiveButton stopAnimation];
//            titleString = [@"Ready/" stringByAppendingString:titleString];
//            break;
//        case CKManagerStateRecovering:
//            [self.archiveButton stopAnimation];
//            titleString = [@"Recovering/" stringByAppendingString:titleString];
//            break;
//        case CKManagerStateHalt:
//            [self.archiveButton stopAnimation];
//            titleString = [@"Halt/" stringByAppendingString:titleString];
//            break;
//
//        default:
//            break;
//    }

//    if (suspendCount > 0){
//        titleString = [titleString stringByAppendingString:[NSString stringWithFormat:@"Suspended (suspendCount = %lu) - InFlight(%lu), Queued(%lu)", (unsigned long)suspendCount, (unsigned long)inFlightCount, (unsigned long)queuedCount]];
//    } else {
//        titleString = [titleString stringByAppendingString:[NSString stringWithFormat:@"Resumed - InFlight(%lu), Queued(%lu)", (unsigned long)inFlightCount, (unsigned long)queuedCount]];
//    }
//    DDLogDebug(@"[CloudKit] %@", titleString);
//}

//#pragma mark - Getters and Setters
//
//- (NSArray<UIImage *> *)archiveSyncImages {
//    NSMutableArray<UIImage *> *array = [[NSMutableArray<UIImage *> alloc] init];
//    for (NSInteger i = 1; i <= 36; i++) {
//        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"Archive-Syncing %ld", (long)i]];
//        [array addObject:image];
//    }
//    return array;
//}
//
//@end
