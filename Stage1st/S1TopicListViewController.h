//
//  S1TopicListViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "S1TabBar.h"

@class DataCenter;
@class AnimationButton;
@class ODRefreshControl;
@class S1TabBar;
@class S1TopicListViewModel;
@class LoadingFooterView;


typedef enum {
    S1TopicListHistory,
    S1TopicListFavorite
} S1InternalTopicListType;

NS_ASSUME_NONNULL_BEGIN

@interface S1TopicListViewController : UIViewController<S1TabBarDelegate>
// UI

@property (nonatomic, strong) UINavigationItem *navigationItem;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIBarButtonItem *historyItem;
@property (nonatomic, strong) UINavigationBar *navigationBar;
@property (nonatomic, strong) AnimationButton *archiveButton;
@property (nonatomic, strong) UIBarButtonItem *settingsItem;
@property (nonatomic, strong) UISegmentedControl *segControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) ODRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) S1TabBar *scrollTabBar;
@property (nonatomic, strong) LoadingFooterView *footerView;

@property (nonatomic, strong) S1HUD *refreshHUD;
// Model
@property (nonatomic, strong) DataCenter *dataCenter;
@property (nonatomic, strong) S1TopicListViewModel *viewModel;

@property (nonatomic, strong) NSString *currentKey;
@property (nonatomic, strong) NSString *previousKey;
@property (nonatomic, strong) NSString *searchKeyword;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *_Nullable cachedContentOffset;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *cachedLastRefreshTime;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *forumKeyMap;

@property (nonatomic, assign) BOOL loadingFlag;
@property (nonatomic, assign) BOOL loadingMore;


- (void)updateTabbar:(NSNotification *)notification;
- (void)reloadTableData:(NSNotification *)notification;
- (void)databaseConnectionDidUpdate:(NSNotification *)notification;
- (void)cloudKitStateChanged:(NSNotification *)notification;

- (void)objc_searchBarSearchButtonClicked:(UISearchBar *)searchBar;

@end

NS_ASSUME_NONNULL_END
