//
//  S1MahjongFaceViewController.m
//  Stage1st
//
//  Created by Zheng Li on 3/16/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1MahjongFaceViewController.h"
#import "S1MahjongFacePageView.h"
#import "S1MahjongFaceButton.h"
#import "UIButton+AFNetworking.h"
#import "Masonry.h"

@interface S1MahjongFaceViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) NSDictionary *mahjongMap;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *pageViews;
@end

#pragma mark -

@implementation S1MahjongFaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[S1Global color5]];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MahjongMap" ofType:@"plist"];
    self.mahjongMap = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *keys = [[self.mahjongMap valueForKey:@"face"] allKeys];
    self.currentCategory = @"face";
    // init page control
    self.pageControl = [[UIPageControl alloc] init];
    self.pageControl.hidesForSinglePage = YES;
    self.pageControl.currentPage = 0;
    self.pageControl.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.pageControl];
    [self.pageControl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX);
        make.bottom.equalTo(self.view.mas_bottom);
        make.left.equalTo(self.view.mas_left);
        make.height.equalTo(@35.0);
    }];
    // init scroll view
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX);
        make.left.equalTo(self.view.mas_left);
        make.top.equalTo(self.view.mas_top);
        make.bottom.equalTo(self.pageControl.mas_top);
    }];
    // init mahjong face page view
    S1MahjongFacePageView *pageView = [[S1MahjongFacePageView alloc] initWithFrame:self.scrollView.frame];
    
    NSUInteger index = 0;
    NSUInteger row = 0;
    for (NSString *key in keys) {
        S1MahjongFaceButton *button = [self mahjongFaceButtonForKey:key];
        [button setFrame:CGRectMake(index * 50 + 10,row * 50 , 50, 50)];
        [button addTarget:self action:@selector(mahjongFacePressed:) forControlEvents:UIControlEventTouchUpInside];
        button.mahjongFaceKey = key;
        [pageView.buttons addObject:button];
        [pageView addSubview:button];
        
        index += 1;
        if (index == 6) {
            index = 0;
            row += 1;
        }
        if (row == 3) {
            break;
        }
    }
    //NSLog(@"%ld", (long)[self faceCountPerPage]);
    [self.scrollView addSubview:pageView];
}

#pragma mark Event

- (void)mahjongFacePressed:(S1MahjongFaceButton *)button
{
    NSLog(@"%@", button.mahjongFaceKey);
    if (self.delegate) {
        S1MahjongFaceTextAttachment *mahjongFaceTextAttachment = [S1MahjongFaceTextAttachment new];
        
        //Set tag and image
        
        NSString *localPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/Mahjong/"];
        NSString *suffix = [[self.mahjongMap valueForKey:self.currentCategory] valueForKey:button.mahjongFaceKey];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", localPath, suffix];
        NSData *imageData = [NSData dataWithContentsOfFile:fullPath];
        
        mahjongFaceTextAttachment.mahjongFaceTag = button.mahjongFaceKey;
        mahjongFaceTextAttachment.image = [UIImage imageWithData:imageData];
        [self.delegate mahjongFaceViewController:self didFinishWithResult:mahjongFaceTextAttachment];
    }
}

#pragma mark Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"Scroll View Did Scroll");
}


#pragma mark Helper

- (NSURL *)URLForKey:(NSString *)key {
    NSString *prefix = [[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] stringByAppendingString:@"static/image/smiley/"];
    NSString *mahjongURLString = [prefix stringByAppendingString:[[self.mahjongMap valueForKey:self.currentCategory] valueForKey:key]];
    return [NSURL URLWithString:mahjongURLString];
}

- (NSMutableURLRequest *)requestForKey:(NSString *)key {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLForKey:key]];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    return  request;
}

- (S1MahjongFaceButton *)mahjongFaceButtonForKey:(NSString *)key {
    S1MahjongFaceButton *button = [[S1MahjongFaceButton alloc] init];
    button.contentMode = UIViewContentModeCenter;
    
    __weak S1MahjongFaceButton *weakButton = button;
    [button setImageForState:UIControlStateNormal withURLRequest:[self requestForKey:key] placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        __strong S1MahjongFaceButton *strongButton = weakButton;
        UIImage * theImage = [UIImage imageWithCGImage:image.CGImage scale:1.0 orientation:UIImageOrientationUp];
        [strongButton setImage:theImage forState:UIControlStateNormal];
    } failure:^(NSError *error) {
        NSLog(@"Unexpected failure when request mahjong face image");
    }];

    return button;
}

- (NSUInteger)numberOfColumnsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.width / 50.0);
}

- (NSUInteger)numberOfRowsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.height / 50.0);
}

- (void)viewDidLayoutSubviews {
    NSLog(@"viewdd");
    //NSLog(@"%ld", (long)[self faceCountPerPage]);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
