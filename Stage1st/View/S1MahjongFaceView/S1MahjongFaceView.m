//
//  S1MahjongFaceView.m
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1MahjongFaceView.h"
#import "S1MahjongFacePageView.h"
#import "S1TabBar.h"
#import "UIButton+AFNetworking.h"
#import "Masonry.h"

@interface S1MahjongFaceView () <UIScrollViewDelegate, S1TabBarDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray<S1MahjongFacePageView *> *pageViews;
@property (nonatomic, strong) UIPageControl *pageControl;

@property (nonatomic, assign) BOOL shouldIngnoreScrollEvent;

@end

#pragma mark -

@implementation S1MahjongFaceView

- (instancetype)init {
    self = [super init];

    self.shouldIngnoreScrollEvent = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundColor = [[ColorManager shared] colorForKey:@"mahjongface.background"];

    self.pageViews = [[NSMutableArray alloc] init];
    
    
    self.historyArray = [NSArray array];
    self.currentCategory = @"history";
    self.mahjongCategories = [self categoriesWithHistory];
    
    // init tab bar
    self.tabBar = [[S1TabBar alloc] init];
    self.tabBar.minButtonWidth = @60.0;
    self.tabBar.expectPresentingButtonCount = @11;
    self.tabBar.expectedButtonHeight = 35.0;
    self.tabBar.tabbarDelegate = self;
    self.tabBar.keys = self.categoryNames;
    [self.tabBar setSelectedIndex:[self.categoryIDs indexOfObject:self.currentCategory]];
    [self addSubview:self.tabBar];

    // init page control
    self.pageControl = [[UIPageControl alloc] init];
    self.pageControl.currentPage = 0;
    self.pageControl.pageIndicatorTintColor = [[ColorManager shared] colorForKey:@"mahjongface.pagecontrol.indicatortint"];
    self.pageControl.currentPageIndicatorTintColor = [[ColorManager shared] colorForKey:@"mahjongface.pagecontrol.currentpage"];
    [self.pageControl addTarget:self action:@selector(pageChanged:) forControlEvents:UIControlEventValueChanged];
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
        make.leading.equalTo(self.mas_leading);
        make.trailing.equalTo(self.mas_trailing);
        make.top.equalTo(self.mas_top);
        make.bottom.equalTo(self.pageControl.mas_top);
    }];

    [self setNeedsLayout];

    return self;
}

#pragma mark - Actions

- (void)mahjongFacePressed:(S1MahjongFaceButton *)button
{
    DDLogDebug(@"%@", button.mahjongFaceItem.key);
    
    if (self.delegate != nil) {
        S1MahjongFaceTextAttachment *mahjongFaceTextAttachment = [S1MahjongFaceTextAttachment new];
        
        // Set tag and image
        NSString *localPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/Mahjong/"];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", localPath, button.mahjongFaceItem.path];
        
        mahjongFaceTextAttachment.mahjongFaceTag = button.mahjongFaceItem.key;
        mahjongFaceTextAttachment.image = [UIImage imageWithContentsOfFile:fullPath];

        [self.delegate mahjongFaceViewController:self didFinishWithResult:mahjongFaceTextAttachment];
    }

    [self _updateHistoryWithItem:button.mahjongFaceItem];
}

- (void)_updateHistoryWithItem:(MahjongFaceItem *)newItem {
    // Update history
    NSMutableArray<MahjongFaceItem *> *mutableHistoryArray = [self.historyArray mutableCopy];

    // Step 1: Remove the history if it already in history list
    for (MahjongFaceItem *item in mutableHistoryArray) {
        if ([item.key isEqualToString:newItem.key]) {
            [mutableHistoryArray removeObject:item];
            break;
        }
    }

    // Step 2: Insert the item to history array
    [mutableHistoryArray insertObject:newItem atIndex:0];

    // Step 3: Remove overflow if history count exceed limit
    while (self.historyCountLimit != 0 && [mutableHistoryArray count] > self.historyCountLimit) {
        [mutableHistoryArray removeLastObject];
    }

    self.historyArray = [mutableHistoryArray copy];

    [self setNeedsLayout];
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
    for (NSString *key in self.categoryIDs) {
        if (newPageNumber >= [self pageCountForCategory:key]) {
            newPageNumber -= [self pageCountForCategory:key];
        } else {
            self.currentCategory = key;
            NSUInteger indexInTabBar = [self.categoryIDs indexOfObject:self.currentCategory];
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
    DDLogVerbose(@"category selected: %@", key);
    self.currentCategory = [self categoryWithName:key].id;
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
    for (NSString *categoryID in self.categoryIDs) {
        totalPageCountForAllCategory += [self pageCountForCategory:categoryID];
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

    // Calculate current local index and category from global index
    NSUInteger localIndex = globalIndex;
    NSString *categoryForThisPage;
    for (NSString *key in self.categoryIDs) {
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

    DDLogVerbose(@"Category:%@, Local Index:%lu", categoryForThisPage, (unsigned long)localIndex);
    
    S1MahjongFacePageView *pageView = [self usableMahjongFacePageViewForIndex:globalIndex];
    
    NSUInteger rows = [self numberOfRowsForFrameSize:scrollView.bounds.size];
    NSUInteger columns = [self numberOfColumnsForFrameSize:scrollView.bounds.size];
    NSUInteger startingIndex = localIndex * (rows * columns - 1);
    NSUInteger endingIndex = (localIndex + 1) * (rows * columns - 1);
    NSMutableArray<MahjongFaceItem *> *mahjongFacePackages = [[NSMutableArray<MahjongFaceItem *> alloc] initWithCapacity:rows * columns];

    if ([categoryForThisPage isEqualToString:@"history"]) {
        for (NSUInteger index = startingIndex; index < endingIndex; index++) {
            if (index >= [self.historyArray count]) {
                break;
            }
            [mahjongFacePackages addObject:[self.historyArray objectAtIndex:index]];
        }
    } else {
        NSArray<MahjongFaceItem *> *allItems = [[self categoryWithID:categoryForThisPage] content];
        for (NSUInteger index = startingIndex; index < endingIndex; index++) {
            if (index == [allItems count]) {
                break;
            }

            [mahjongFacePackages addObject:allItems[index]];
        }
    }

    pageView.frame = CGRectMake(globalIndex * CGRectGetWidth(scrollView.bounds),
                                0.0,
                                CGRectGetWidth(scrollView.bounds),
                                CGRectGetHeight(scrollView.bounds));

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

//- (NSURL *)URLForKey:(NSString *)key inCategory:(NSString *)category {
//    NSURL *base = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"Mahjong"];
//    return [base URLByAppendingPathComponent:[[self.mahjongMap valueForKey:category] valueForKey:key]];
//}

- (NSUInteger)numberOfColumnsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.width / 50.0);
}

- (NSUInteger)numberOfRowsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.height / 50.0);
}

- (NSUInteger)pageCountForCategory:(NSString *)categoryID {
    NSInteger rows = [self numberOfRowsForFrameSize:self.scrollView.bounds.size];
    NSInteger columns = [self numberOfColumnsForFrameSize:self.scrollView.bounds.size];
    NSInteger countPerPage = rows * columns - 1;
    NSInteger countInCategory;
    if ([categoryID isEqualToString:@"history"]) {
        countInCategory = [self.historyArray count];
        if (countInCategory == 0) {
            countInCategory = 1;
        }
    } else {
        countInCategory = [[[self categoryWithID:categoryID] content] count];
    }
    NSInteger totalPageCount = (NSUInteger)ceil((float)countInCategory / countPerPage);
    return totalPageCount;
}

- (NSUInteger)globalIndexForCategory:(NSString *)categoryKey andPage:(NSUInteger)currentPage {
    NSUInteger indexOffset = 0;
    for (NSString *key in self.categoryIDs) {
        if (![key isEqualToString:categoryKey]) {
            indexOffset += [self pageCountForCategory:key];
        } else {
            break;
        }
    }
    return indexOffset + currentPage;
}

@end
