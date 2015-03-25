//
//  S1SettingViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1SettingViewController.h"
#import "S1TopicListViewController.h"
#import "S1DatabaseManageViewController.h"
#import "GSStaticTableViewBuilder.h"
//#import "MTStatusBarOverlay.h"

@interface S1SettingViewController ()
@property (weak, nonatomic) IBOutlet UILabel *usernameDetail;
@property (weak, nonatomic) IBOutlet UILabel *fontSizeDetail;
@property (weak, nonatomic) IBOutlet UISwitch *displayImageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *keepHistoryDetail;
@property (weak, nonatomic) IBOutlet UISwitch *removeTailsSwitch;
@property (weak, nonatomic) IBOutlet UILabel *versionDetail;
@property (weak, nonatomic) IBOutlet UISwitch *useAPISwitch;
@property (weak, nonatomic) IBOutlet UISwitch *precacheSwitch;

@property (weak, nonatomic) IBOutlet UITableViewCell *forumOrderCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *fontSizeCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *keepHistoryCell;
@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *leftSpaceConstraint;


@end


@implementation S1SettingViewController

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
    if (IS_WIDE_DEVICE) {
        for (NSLayoutConstraint *constraint in self.leftSpaceConstraint) {
            constraint.constant = 12;
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
}
#pragma mark - Orientation

- (NSUInteger)supportedInterfaceOrientations
{
    //if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    //    return UIInterfaceOrientationMaskPortrait;
    //}
    return [super supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    //if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    //    return UIInterfaceOrientationPortrait;
    //}
    return [super preferredInterfaceOrientationForPresentation];
}
#pragma mark -
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
#pragma mark -
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
}
@end
