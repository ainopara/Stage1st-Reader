//
//  S1SettingViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1SettingViewController.h"
#import "S1TopicListViewController.h"
#import "S1LoginViewController.h"
#import "S1BaseURLViewController.h"
#import "GSStaticTableViewBuilder.h"
#import "S1GlobalVariables.h"

@interface S1SettingViewController ()

@end

@implementation S1SettingViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    //[self.view setTintColor:[S1GlobalVariables color3]];
    self.navigationItem.title = NSLocalizedString(@"设置", @"Setting");
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"返回", @"Back") style:UIBarButtonItemStyleDone target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelItem;
    
    __weak typeof(self) myself = self;
    
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"请求地址", @"URL");
                cell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell) {
                S1BaseURLViewController *controller = [[S1BaseURLViewController alloc] initWithStyle:UITableViewStyleGrouped];
                [myself.navigationController pushViewController:controller animated:YES];
            }];
        }];
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"登录", @"Login");
                NSString *userID = [[NSUserDefaults standardUserDefaults] valueForKey:@"UserID"];
                if (userID) {
                    cell.detailTextLabel.text = userID;
                } else {
                    cell.detailTextLabel.text = NSLocalizedString(@"未登录", @"Not Login");
                }
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell){
                S1LoginViewController *controller = [[S1LoginViewController alloc] initWithStyle:UITableViewStyleGrouped];
                [myself.navigationController pushViewController:controller animated:YES];
            }];
        }];
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = @"板块自定义";
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell) {
                GSReorderableTableViewController *controller = [[GSReorderableTableViewController alloc] initWithKeys:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"]];
                controller.title = NSLocalizedString(@"板块自定义", @"Order");
                [controller setCompletionHandler:^(NSArray *keys) {
                    [[NSUserDefaults standardUserDefaults] setValue:keys forKey:@"Order"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    NSNotification *notification = [NSNotification notificationWithName:@"S1UserMayReorderedNotification" object:nil];
                    [[NSNotificationCenter defaultCenter] postNotification:notification];
                }];
                [myself.navigationController pushViewController:controller animated:YES];
            }];
        }];
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = @"字体大小";
                cell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell) {
                GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:@[@"15px", @"17px"] andSelectedKey:[[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"]];
                controller.title = NSLocalizedString(@"字体大小", @"Order");
                [controller setCompletionHandler:^(NSString *key) {
                    [[NSUserDefaults standardUserDefaults] setValue:key forKey:@"FontSize"];                    
                }];
                [myself.navigationController pushViewController:controller animated:YES];
            }];
        }];
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"显示图片", @"Display Image");
                if (!cell.accessoryView) {
                    UISwitch *switcher = [[UISwitch alloc] initWithFrame:CGRectZero];
                    switcher.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"Display"];
                    [switcher addEventHandler:^(id sender, UIEvent *event) {
                        UISwitch *s = sender;
                        [[NSUserDefaults standardUserDefaults] setBool:s.on forKey:@"Display"];
                    } forControlEvent:UIControlEventValueChanged];
                    cell.accessoryView = switcher;
                }
            }];
        }];

    }];
    
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"版本", @"Version");
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]
;
            }];
        }];
        
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"开发者", @"Developer");
                cell.detailTextLabel.text = @"Gabriel";
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell){
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Gabriel" message:nil delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
                [alertView show];
            }];
        }];
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 

- (void)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

@end
