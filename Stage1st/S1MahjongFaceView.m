//
//  S1MahjongFaceView.m
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1MahjongFaceView.h"
#import "S1MahjongFacePageView.h"
#import "S1MahjongFaceButton.h"
#import "S1TabBar.h"
#import "UIButton+AFNetworking.h"
#import "Masonry.h"

@interface S1MahjongFaceView () <UIScrollViewDelegate, S1TabBarDelegate>

@property (nonatomic, strong) NSDictionary *mahjongMap;
@property (nonatomic, strong) NSDictionary *keyTranslation;
@property (nonatomic, strong) NSArray *mahjongCategoryOrder;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *pageViews;
@property (nonatomic, strong) S1TabBar *tabBar;

@property (nonatomic, assign) BOOL shouldIngnoreScrollEvent;

@end

#pragma mark -

@implementation S1MahjongFaceView

- (instancetype)init {
    self = [super init];
    self.shouldIngnoreScrollEvent = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundColor = [[APColorManager sharedInstance] colorForKey:@"mahjongface.background"];
    self.keyTranslation = @{
        @"history":@"历史",
        @"face":@"麻将脸",
        @"dym":@"大姨妈",
        @"goose":@"鹅",
        @"zdl":@"战斗力",
        @"nq":@"扭曲",
        @"normal":@"正常向",
        @"flash":@"闪光弹",
        @"animal":@"动物",
        @"carton":@"动漫",
        @"bundam":@"雀高达"
    };
    self.pageViews = [[NSMutableArray alloc] init];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MahjongMap" ofType:@"plist"];
    self.mahjongMap = [NSDictionary dictionaryWithContentsOfFile:path];
    path = [[NSBundle mainBundle] pathForResource:@"MahjongCategoryOrder" ofType:@"plist"];
    self.mahjongCategoryOrder = [NSArray arrayWithContentsOfFile:path];
    NSMutableArray *mutableOrder = [self.mahjongCategoryOrder mutableCopy];
    [mutableOrder insertObject:@"history" atIndex:0];
    self.mahjongCategoryOrder = [mutableOrder copy];
    self.historyArray = [NSMutableArray array];
    self.currentCategory = @"history";
    
    // init tab bar
    self.tabBar = [[S1TabBar alloc] init];
    self.tabBar.minButtonWidth = @60.0;
    self.tabBar.expectPresentingButtonCount = @11;
    self.tabBar.tabbarDelegate = self;
    self.tabBar.keys = [self translateKey:self.mahjongCategoryOrder];
    [self.tabBar setSelectedIndex:[self.mahjongCategoryOrder indexOfObject:self.currentCategory]];
    [self addSubview:self.tabBar];
    [self.tabBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.mas_centerX);
        make.bottom.equalTo(self.mas_bottom);
        make.left.equalTo(self.mas_left);
        make.height.equalTo(@35.0);
    }];
    // init page control
    self.pageControl = [[UIPageControl alloc] init];
    self.pageControl.currentPage = 0;
    self.pageControl.pageIndicatorTintColor = [[APColorManager sharedInstance] colorForKey:@"mahjongface.pagecontrol.indicatortint"];
    self.pageControl.currentPageIndicatorTintColor = [[APColorManager sharedInstance] colorForKey:@"mahjongface.pagecontrol.currentpage"];
    [self.pageControl addTarget:self action:@selector(pageChanged:) forControlEvents:UIControlEventValueChanged];
    //self.pageControl.backgroundColor = [UIColor clearColor];
    [self addSubview:self.pageControl];
    [self.pageControl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.mas_centerX);
        make.bottom.equalTo(self.tabBar.mas_top);
        make.left.equalTo(self.mas_left);
        make.height.equalTo(@20.0);
    }];
    // init scroll view
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delaysContentTouches = YES;
    self.scrollView.delegate = self;
    [self addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.mas_centerX);
        make.left.equalTo(self.mas_left);
        make.top.equalTo(self.mas_top);
        make.bottom.equalTo(self.pageControl.mas_top);
    }];
    [self setNeedsLayout];
    return self;
}

#pragma mark - Actions

- (void)mahjongFacePressed:(S1MahjongFaceButton *)button
{
    DDLogDebug(@"%@", button.mahjongFaceKey);
    
    if (self.delegate != nil) {
        S1MahjongFaceTextAttachment *mahjongFaceTextAttachment = [S1MahjongFaceTextAttachment new];
        
        //Set tag and image
        
        NSString *localPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/Mahjong/"];
        NSString *suffix = [[self.mahjongMap valueForKey:button.category] valueForKey:button.mahjongFaceKey];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", localPath, suffix];
        NSData *imageData = [NSData dataWithContentsOfFile:fullPath];
        
        mahjongFaceTextAttachment.mahjongFaceTag = button.mahjongFaceKey;
        mahjongFaceTextAttachment.image = [UIImage imageWithData:imageData];
        [self.delegate mahjongFaceViewController:self didFinishWithResult:mahjongFaceTextAttachment];
    }

    //Update history

    // Step 1: Remove the history if it already in history list
    NSArray *thePackage = nil;
    for (NSArray *package in self.historyArray) {
        if ([[package firstObject] isEqualToString:button.mahjongFaceKey]) {
            thePackage = package;
            [self.historyArray removeObject:package];
            break;
        }
    }

    // Step 2: Insert the package to history array
    if ([self.currentCategory isEqualToString:@"history"]) {
        if (thePackage != nil) {
            [self.historyArray insertObject:thePackage atIndex:0];
        }
    } else {
        [self.historyArray insertObject:@[button.mahjongFaceKey, button.category, [self URLForKey:button.mahjongFaceKey inCategory:button.category]] atIndex:0];
    }

    // Step 3: Remove overflow if history count exceed limit
    if (self.historyCountLimit != 0 && [self.historyArray count] > self.historyCountLimit) {
        NSMutableArray *newHistoryArray = [NSMutableArray arrayWithCapacity:self.historyCountLimit];
        for (NSUInteger i = 0; i < self.historyCountLimit; i++) {
            [newHistoryArray addObject:[self.historyArray objectAtIndex:i]];
        }
        self.historyArray = newHistoryArray;
    }
}

- (void)backspacePressed:(UIButton *)button {
    DDLogDebug(@"backspace");
    if (self.delegate) {
        [self.delegate mahjongFaceViewControllerDidPressBackSpace:self];
    }
}

- (void)pageChanged:(UIPageControl *)pageControl {
    DDLogDebug(@"pageChanged: %ld", (long)self.pageControl.currentPage);
    [self setPage:[self globalIndexForCategory:self.currentCategory andPage:self.pageControl.currentPage]];
    [self setContentOffsetForGlobalIndex:[self globalIndexForCategory:self.currentCategory andPage:self.pageControl.currentPage]];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.shouldIngnoreScrollEvent) {
        return;
    }
    CGFloat pageWidth = CGRectGetWidth(scrollView.frame);
    NSInteger newPageNumber = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    NSString *lastCategory = self.currentCategory;
    for (NSString *key in self.mahjongCategoryOrder) {
        if (newPageNumber >= [self pageCountForCategory:key]) {
            newPageNumber -= [self pageCountForCategory:key];
        } else {
            self.currentCategory = key;
            NSUInteger indexInTabBar = [self.mahjongCategoryOrder indexOfObject:self.currentCategory];
            [self.tabBar setSelectedIndex:indexInTabBar];
            
            break;
        }
    }
    if ([lastCategory isEqualToString:self.currentCategory] && self.pageControl.currentPage == newPageNumber) {
        return;
    }

    self.pageControl.currentPage = newPageNumber;
    self.pageControl.numberOfPages = [self pageCountForCategory:self.currentCategory];
    [self setPage:[self globalIndexForCategory:self.currentCategory andPage:newPageNumber]];
}

#pragma mark - S1TabBarDelegate

- (void)tabbar:(S1TabBar *)tabbar didSelectedKey:(NSString *)key {
    DDLogDebug(@"%@",key);
    self.currentCategory = [[self.keyTranslation allKeysForObject:key] objectAtIndex:0];
    self.pageControl.currentPage = 0;
    [self setNeedsLayout];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    DDLogDebug(@"layout subviews");
    NSInteger totalPageCount = [self pageCountForCategory:self.currentCategory];
    NSInteger currentPage = (self.pageControl.currentPage > totalPageCount) ? totalPageCount : self.pageControl.currentPage;
    self.pageControl.currentPage = currentPage;
    self.pageControl.numberOfPages = totalPageCount;
    
    NSInteger totalPageCountForAllCategory = 0;
    for (NSString *key in self.mahjongCategoryOrder) {
        totalPageCountForAllCategory += [self pageCountForCategory:key];
    }
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.scrollView.bounds) * totalPageCountForAllCategory, CGRectGetHeight(self.scrollView.bounds));
    DDLogDebug(@"Total page count: %ld", (long)totalPageCount);
    self.shouldIngnoreScrollEvent = YES;
    [self setContentOffsetForGlobalIndex:[self globalIndexForCategory:self.currentCategory andPage:currentPage]];
    self.shouldIngnoreScrollEvent = NO;
    [self setPage:[self globalIndexForCategory:self.currentCategory andPage:currentPage]];
}

#pragma mark - Helper

- (S1MahjongFacePageView *)usableMahjongFacePageViewForIndex:(NSUInteger)index {
    for (S1MahjongFacePageView *page in self.pageViews) {
        if (page.index == index) {
            return page;
        }
    }
    for (S1MahjongFacePageView *page in self.pageViews) {
        if (abs((int)(page.index - index)) > 2) {
            page.index = index;
            return page;
        }
    }
    
    S1MahjongFacePageView *pageView = [[S1MahjongFacePageView alloc] initWithFrame:self.scrollView.frame];
    pageView.index = index;
    pageView.containerView = self;
    [self.scrollView addSubview:pageView];
    [self.pageViews addObject:pageView];
    return pageView;
}

- (void)setMahjongFacePageViewInScrollView:(UIScrollView *)scrollView atIndex:(NSUInteger)globalIndex {
    NSUInteger localIndex = globalIndex;
    NSString *categoryForThisPage;
    for (NSString *key in self.mahjongCategoryOrder) {
        if (localIndex >= [self pageCountForCategory:key]) {
            localIndex -= [self pageCountForCategory:key];
        } else {
            categoryForThisPage = key;
            break;
        }
    }
    if (categoryForThisPage == nil || localIndex >= [self pageCountForCategory:categoryForThisPage]) {
        return;
    }
    DDLogDebug(@"Category:%@, Local Index:%lu", categoryForThisPage, (unsigned long)localIndex);
    
    S1MahjongFacePageView *pageView = [self usableMahjongFacePageViewForIndex:globalIndex];
    
    NSUInteger rows = [self numberOfRowsForFrameSize:scrollView.bounds.size];
    NSUInteger columns = [self numberOfColumnsForFrameSize:scrollView.bounds.size];
    NSUInteger startingIndex = localIndex * (rows * columns - 1);
    NSUInteger endingIndex = (localIndex + 1) * (rows * columns - 1);
    NSMutableArray *mahjongFacePackages = [[NSMutableArray alloc] initWithCapacity:rows * columns];

    if ([categoryForThisPage isEqualToString:@"history"]) {
        for (NSUInteger index = startingIndex; index < endingIndex; index++) {
            if (index >= [self.historyArray count]) {
                break;
            }
            [mahjongFacePackages addObject:[self.historyArray objectAtIndex:index]];
        }
    } else {
        NSArray *allKeys = [[self.mahjongMap valueForKey:categoryForThisPage] allKeys];
        for (NSUInteger index = startingIndex; index < endingIndex; index++) {
            if (index == [allKeys count]) {
                break;
            }
            NSString *key = [allKeys objectAtIndex:index];
            NSArray *package = @[key, categoryForThisPage, [self URLForKey:key inCategory:categoryForThisPage]];
            [mahjongFacePackages addObject:package];
        }
    }

    pageView.frame = CGRectMake(globalIndex * CGRectGetWidth(scrollView.bounds), 0, CGRectGetWidth(scrollView.bounds), CGRectGetHeight(scrollView.bounds));
    [pageView setMahjongFaceList:mahjongFacePackages withRows:rows andColumns:columns];
}

- (void)setPage:(NSInteger)page {
    DDLogDebug(@"Global Index:%ld", (long)page);
    [self setMahjongFacePageViewInScrollView:self.scrollView atIndex:page - 1];
    [self setMahjongFacePageViewInScrollView:self.scrollView atIndex:page];
    [self setMahjongFacePageViewInScrollView:self.scrollView atIndex:page + 1];
}

- (void)setContentOffsetForGlobalIndex:(NSUInteger)index {
    [self.scrollView setContentOffset:CGPointMake(index * CGRectGetWidth(self.scrollView.bounds), 0)];
}

- (NSURL *)URLForKey:(NSString *)key inCategory:(NSString *)category {
    NSString *prefix = [[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] stringByAppendingString:@"static/image/smiley/"];
    NSString *mahjongURLString = [prefix stringByAppendingString:[[self.mahjongMap valueForKey:category] valueForKey:key]];
    return [NSURL URLWithString:mahjongURLString];
}

- (NSUInteger)numberOfColumnsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.width / 50.0);
}

- (NSUInteger)numberOfRowsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.height / 50.0);
}

- (NSUInteger)pageCountForCategory:(NSString *)key {
    NSInteger rows = [self numberOfRowsForFrameSize:self.scrollView.bounds.size];
    NSInteger columns = [self numberOfColumnsForFrameSize:self.scrollView.bounds.size];
    NSInteger countPerPage = rows * columns - 1;
    NSInteger countInCategory;
    if ([key isEqualToString:@"history"]) {
        countInCategory = [self.historyArray count];
        if (countInCategory == 0) {
            countInCategory = 1;
        }
    } else {
        countInCategory = [[self.mahjongMap valueForKey:key] count];
    }
    NSInteger totalPageCount = (NSUInteger)ceil((float)countInCategory / countPerPage);
    return totalPageCount;
}

- (NSUInteger)globalIndexForCategory:(NSString *)categoryKey andPage:(NSUInteger)currentPage {
    NSUInteger indexOffset = 0;
    for (NSString *key in self.mahjongCategoryOrder) {
        if (![key isEqualToString:categoryKey]) {
            indexOffset += [self pageCountForCategory:key];
        } else {
            break;
        }
    }
    return indexOffset + currentPage;
}

- (NSArray *)translateKey:(NSArray *)keyArray {
    NSMutableArray *translationResult = [[NSMutableArray alloc] initWithCapacity:[keyArray count]];
    for (NSString *key in keyArray) {
        NSString *value = [self.keyTranslation valueForKey:key];
        if (value) {
            [translationResult addObject:value];
        }
    }
    return translationResult;
}

@end
