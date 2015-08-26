//
//  S1SettingViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1SettingViewController.h"
#import "S1TopicListViewController.h"
#import "GSStaticTableViewBuilder.h"
#import "DatabaseManager.h"


@interface S1SettingViewController () <UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UILabel *usernameDetail;
@property (weak, nonatomic) IBOutlet UILabel *fontSizeDetail;
@property (weak, nonatomic) IBOutlet UISwitch *displayImageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *keepHistoryDetail;
@property (weak, nonatomic) IBOutlet UISwitch *removeTailsSwitch;
@property (weak, nonatomic) IBOutlet UILabel *versionDetail;
@property (weak, nonatomic) IBOutlet UISwitch *useAPISwitch;
@property (weak, nonatomic) IBOutlet UISwitch *precacheSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *nightModeSwitch;

@property (weak, nonatomic) IBOutlet UITableViewCell *forumOrderCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *fontSizeCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *keepHistoryCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *iCloudSyncCell;

@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *offsetConstraint;
@property (assign, nonatomic) CGFloat offset;
@end


@implementation S1SettingViewController
#pragma mark - Life Cycle
- (void)viewWillAppear:(BOOL)animated {
    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
    if (inLoginStateID) {
        self.usernameDetail.text = inLoginStateID;
    }
    
    self.fontSizeDetail.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    
    self.keepHistoryDetail.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //[[MTStatusBarOverlay sharedInstance] postImmediateMessage:@"test" duration:3.0 animated:YES];
    //[[MTStatusBarOverlay sharedInstance] postMessage:@"测试Overlay" animated:YES];
    if (IS_IPAD) {
        //UIDropShadowView has a fixed corner radius.
        self.navigationController.view.layer.cornerRadius  = 5.0;
        self.navigationController.view.layer.masksToBounds = YES;
        self.navigationController.view.superview.backgroundColor = [UIColor clearColor];
    }
    if (!SYSTEM_VERSION_LESS_THAN(@"8")) {
        for (NSLayoutConstraint *constraint in self.offsetConstraint) {
            constraint.active = NO;
        }
    }

    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
    if (inLoginStateID) {
        self.usernameDetail.text = inLoginStateID;
    }
    self.forumOrderCell.textLabel.text = NSLocalizedString(@"SettingView_Forum_Order_Custom", @"Forum Order");
    self.fontSizeDetail.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    
    self.displayImageSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"Display"];
    
    
    self.keepHistoryDetail.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
    
    self.removeTailsSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"RemoveTails"];
    self.useAPISwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseAPI"];
    self.precacheSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"PrecacheNextPage"];
    self.nightModeSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"NightMode"];
    
    self.versionDetail.text = [NSString stringWithFormat:@"%@ (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];

    self.navigationItem.title = NSLocalizedString(@"SettingView_NavigationBar_Title", @"Settings");
    
    //
    self.fontSizeCell.textLabel.text = NSLocalizedString(@"SettingView_Font_Size", @"Font Size");
    self.fontSizeCell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    self.fontSizeCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    self.fontSizeCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    //}
    self.keepHistoryCell.textLabel.text = NSLocalizedString(@"SettingView_HistoryLimit", @"History Limit");
    self.keepHistoryCell.detailTextLabel.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
    self.keepHistoryCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    self.keepHistoryCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    [self updateiCloudStatus];
    
    self.offset = 0;
    self.tableView.delegate = self;
    [self.tableView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePaletteChangeNotification:) name:@"S1PaletteDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitSuspendCountChanged:) name:YapDatabaseCloudKitSuspendCountChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitInFlightChangeSetChanged:) name:YapDatabaseCloudKitInFlightChangeSetChangedNotification object:nil];
}

- (void)dealloc {
    [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Pull To Close
-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (self.offset < -36) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"contentOffset"]) {
        self.offset = [[change objectForKey:@"new"] CGPointValue].y + 64;
        //NSLog(@"%f",self.offset);
    }
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
#pragma mark - Navigation
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%@", indexPath);
    
    if (indexPath.section == 0 && indexPath.row == 2) {
        NSArray *keys;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            keys = @[@"15px", @"17px", @"19px"];
        } else {
            keys = @[@"18px", @"20px", @"22px"];
        }
        GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:keys andSelectedKey:[[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"]];
        controller.title = NSLocalizedString(@"SettingView_Font_Size", @"Font Size");
        [controller setCompletionHandler:^(NSString *key) {
            [[NSUserDefaults standardUserDefaults] setValue:key forKey:@"FontSize"];
        }];
        [self.navigationController pushViewController:controller animated:YES];
    }
    if (indexPath.section == 0 && indexPath.row == 4) {
        NSString *selectedKey = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
        NSArray *keys = @[NSLocalizedString(@"SettingView_HistoryLimit_3days", @"3 days"), NSLocalizedString(@"SettingView_HistoryLimit_1week", @"1 week"),NSLocalizedString(@"SettingView_HistoryLimit_2weeks", @"2 weeks"),NSLocalizedString(@"SettingView_HistoryLimit_1month", @"1 month"), NSLocalizedString(@"SettingView_HistoryLimit_Forever", @"Forever")];
        
        GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:keys andSelectedKey:selectedKey];
        controller.title = NSLocalizedString(@"SettingView_HistoryLimit", @"HistoryLimit");
        [controller setCompletionHandler:^(NSString *key) {
            [[NSUserDefaults standardUserDefaults] setValue:[S1Global HistoryLimitString2Number:key] forKey:@"HistoryLimit"];
        }];
        [self.navigationController pushViewController:controller animated:YES];
    }
    /*
    if (indexPath.section == 0 && indexPath.row == 7) {
        S1DatabaseManageViewController *databaseManageViewController = [[S1DatabaseManageViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:databaseManageViewController animated:YES];
    }*/
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}
#pragma mark - Actions
- (IBAction)back:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)switchDisplayImage:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"Display"];
}

- (IBAction)switchRemoveTails:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"RemoveTails"];
}
- (IBAction)switchUseAPI:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"UseAPI"];
}
- (IBAction)switchPrecache:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"PrecacheNextPage"];
}
- (IBAction)switchNightMode:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"NightMode"];
    [[S1ColorManager sharedInstance] setPaletteForNightMode:sender.on];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
}

#pragma mark - Notification
- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
    [self.displayImageSwitch setOnTintColor:[[S1ColorManager sharedInstance] colorForKey:@"appearance.switch.tint"]];
    [self.removeTailsSwitch setOnTintColor:[[S1ColorManager sharedInstance] colorForKey:@"appearance.switch.tint"]];
    [self.precacheSwitch setOnTintColor:[[S1ColorManager sharedInstance] colorForKey:@"appearance.switch.tint"]];
    [self.useAPISwitch setOnTintColor:[[S1ColorManager sharedInstance] colorForKey:@"appearance.switch.tint"]];
    [self.nightModeSwitch setOnTintColor:[[S1ColorManager sharedInstance] colorForKey:@"appearance.switch.tint"]];
    [self.navigationController.navigationBar setBarTintColor:[[S1ColorManager sharedInstance]  colorForKey:@"appearance.navigationbar.battint"]];
    [self.navigationController.navigationBar setTintColor:[[S1ColorManager sharedInstance]  colorForKey:@"appearance.navigationbar.tint"]];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [[S1ColorManager sharedInstance] colorForKey:@"appearance.navigationbar.title"],
                                                 NSFontAttributeName:[UIFont boldSystemFontOfSize:17.0],}];
}

- (void)cloudKitSuspendCountChanged:(NSNotification *)notification
{
    [self updateiCloudStatus];
}

- (void)cloudKitInFlightChangeSetChanged:(NSNotification *)notification
{
    [self updateiCloudStatus];
}
#pragma mark - Helper

- (void)updateiCloudStatus {
    NSString *titleString;
    if (SYSTEM_VERSION_LESS_THAN(@"8") || ![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"]) {
        // iOS 7
        titleString = @"Off";
    } else {
        // iOS 8 and more
        NSUInteger suspendCount = [MyDatabaseManager.cloudKitExtension suspendCount];
        
        NSUInteger inFlightCount = 0;
        NSUInteger queuedCount = 0;
        [MyDatabaseManager.cloudKitExtension getNumberOfInFlightChangeSets:&inFlightCount queuedChangeSets:&queuedCount];
        
        if (suspendCount > 0){
            titleString = [NSString stringWithFormat:@"Suspended(%lu)(%lu-%lu)", (unsigned long)suspendCount, (unsigned long)inFlightCount, (unsigned long)queuedCount];
        } else {
            titleString = [NSString stringWithFormat:@"Resumed (%lu-%lu)", (unsigned long)inFlightCount, (unsigned long)queuedCount];
        }
        self.iCloudSyncCell.detailTextLabel.text = titleString;
    }
    
}

@end
