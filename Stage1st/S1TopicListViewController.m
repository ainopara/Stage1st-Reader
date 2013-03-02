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
#import "UIControl+BlockWrapper.h"
#import "S1HTTPClient.h"
#import "S1Parser.h"
#import "S1TopicCell.h"
#import "S1TopicListCell.h"
#import "S1HUD.h"

static NSString * const cellIdentifier = @"TopicCell";

@interface S1TopicListViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UINavigationBar *navigationBar;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSArray *topics;

@end

@implementation S1TopicListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
#define _BAR_HEIGHT 44.0f
    
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, _BAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height-2*_BAR_HEIGHT) style:UITableViewStylePlain];
    self.tableView.autoresizesSubviews = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.tableView registerClass:[S1TopicListCell class] forCellReuseIdentifier:cellIdentifier];
    self.tableView.rowHeight = 54.0f;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorColor = [UIColor colorWithRed:0.82 green:0.85 blue:0.76 alpha:1.0];
    self.tableView.backgroundColor = [UIColor colorWithRed: 0.96 green: 0.97 blue: 0.92 alpha: 1];
    [self.view addSubview:self.tableView];
    
    self.navigationBar = [[UINavigationBar alloc] init];
    self.navigationBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, _BAR_HEIGHT);
    self.navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Stage1st"];
    UIBarButtonItem *settingItem = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStyleBordered target:self action:@selector(settings:)];
    UIBarButtonItem *recentItem = [[UIBarButtonItem alloc] initWithTitle:@"Recent" style:UIBarButtonItemStyleBordered target:self action:@selector(recent:)];
    item.leftBarButtonItem = settingItem;
    item.rightBarButtonItem = recentItem;
    [self.navigationBar pushNavigationItem:item animated:NO];
    [self.view addSubview:self.navigationBar];    
    [self fetchTopics];
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-_BAR_HEIGHT, self.view.bounds.size.width, _BAR_HEIGHT)];
    [self.view addSubview:toolbar];
    
#undef _BAR_HEIGHT
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.tableView setUserInteractionEnabled:YES];
    [self.tableView setScrollsToTop:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.tableView setUserInteractionEnabled:YES];
    [self.tableView setScrollsToTop:NO];
    
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Bar Item Actions

- (void)settings:(id)sender
{
    S1SettingViewController *controller = [[S1SettingViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:controller] animated:YES completion:^{}];
}

- (void)recent:(id)sender
{
    
}

#pragma mark - Networking

- (void)fetchTopics
{
    S1HUD *HUD = [S1HUD showHUDInView:self.view];
    [[S1HTTPClient sharedClient] getPath:@"?f75.html"
                              parameters:nil
                                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                     NSString *HTMLString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                     if (HTMLString) {
                                         self.topics = [S1Parser topicsFromHTMLString:HTMLString];
                                         [self.tableView reloadData];
                                     }
                                     [HUD hideWithDelay:0.5];
                                 }
                                 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                     NSLog(@"%@", error);
                                     [HUD hideWithDelay:0.5];
                                 }];
}

#pragma mark - UITableView


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.topics count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    S1TopicCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier
                                                        forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell setTopic:self.topics[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    S1ContentViewController *controller = [[S1ContentViewController alloc] init];
    [controller setTopic:self.topics[indexPath.row]];
    [[self rootViewController] presentDetailViewController:controller];
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

@end
