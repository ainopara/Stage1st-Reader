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
//#import "S1BaseURLViewController.h"
#import "GSStaticTableViewBuilder.h"

@interface S1SettingViewController ()
@end


@implementation S1SettingViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    //[self.view setTintColor:[S1GlobalVariables color3]];
    self.navigationItem.title = NSLocalizedString(@"SettingView_NavigationBar_Title", @"Settings");
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"SettingView_NavigationBar_Back", @"Back") style:UIBarButtonItemStyleDone target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelItem;
    
    __weak typeof(self) myself = self;
    
    [self addSection:^(GSSection *section) {
        /* //This section no more needed.
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
        */
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"SettingView_Login", @"Login");
                NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
                if (inLoginStateID) {
                    cell.detailTextLabel.text = inLoginStateID;
                } else {
                    cell.detailTextLabel.text = NSLocalizedString(@"SettingView_Not_Login_State_Mark", @"Not Login");
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
                cell.textLabel.text = NSLocalizedString(@"SettingView_Forum_Order_Custom", @"Forum Order");
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell) {
                GSReorderableTableViewController *controller = [[GSReorderableTableViewController alloc] initWithKeys:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"]];
                controller.title = NSLocalizedString(@"SettingView_Forum_Order_Custom", @"Order");
                [controller setCompletionHandler:^(NSArray *keys) {
                    [[NSUserDefaults standardUserDefaults] setValue:keys forKey:@"Order"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    NSNotification *notification = [NSNotification notificationWithName:@"S1UserMayReorderedNotification" object:nil];
                    [[NSNotificationCenter defaultCenter] postNotification:notification];
                }];
                [myself.navigationController pushViewController:controller animated:YES];
            }];
        }];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            [section addRow:^(GSRow *row) {
                [row setConfigurationBlock:^(UITableViewCell *cell) {
                    cell.textLabel.text = NSLocalizedString(@"SettingView_Font_Size", @"Font Size");
                    cell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
                    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }];
                [row setEventHandlerBlock:^(UITableViewCell *cell) {
                    GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:@[@"15px", @"17px", @"19px"] andSelectedKey:[[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"]];
                    controller.title = NSLocalizedString(@"SettingView_Font_Size", @"Font Size");
                    [controller setCompletionHandler:^(NSString *key) {
                        [[NSUserDefaults standardUserDefaults] setValue:key forKey:@"FontSize"];
                    }];
                    [myself.navigationController pushViewController:controller animated:YES];
                }];
            }];
        }
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"SettingView_Display_Image", @"Display Image");
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
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = NSLocalizedString(@"SettingView_HistoryLimit", @"History Limit");
                cell.detailTextLabel.text = [S1GlobalVariables HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell) {
                NSString *selectedKey = [S1GlobalVariables HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
                GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:@[NSLocalizedString(@"SettingView_HistoryLimit_3days", @"3 days"), NSLocalizedString(@"SettingView_HistoryLimit_1week", @"1 week"),NSLocalizedString(@"SettingView_HistoryLimit_2weeks", @"2 weeks"),NSLocalizedString(@"SettingView_HistoryLimit_1month", @"1 month"), NSLocalizedString(@"SettingView_HistoryLimit_Forever", @"Forever")] andSelectedKey:selectedKey];
                controller.title = NSLocalizedString(@"SettingView_HistoryLimit", @"HistoryLimit");
                [controller setCompletionHandler:^(NSString *key) {
                    [[NSUserDefaults standardUserDefaults] setValue:[S1GlobalVariables HistoryLimitString2Number:key] forKey:@"HistoryLimit"];
                }];
                [myself.navigationController pushViewController:controller animated:YES];
            }];
        }];
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"SettingView_Append_Suffix", @"Append Suffix");
                if (!cell.accessoryView) {
                    UISwitch *switcher = [[UISwitch alloc] initWithFrame:CGRectZero];
                    switcher.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"AppendSuffix"];
                    [switcher addEventHandler:^(id sender, UIEvent *event) {
                        UISwitch *s = sender;
                        [[NSUserDefaults standardUserDefaults] setBool:s.on forKey:@"AppendSuffix"];
                    } forControlEvent:UIControlEventValueChanged];
                    cell.accessoryView = switcher;
                }
            }];
        }];

    }];
    
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"SettingView_Version", @"Version");
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]]
;
            }];
        }];
        
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"SettingView_Developer", @"Developer");
                cell.detailTextLabel.text = @"Gabriel & ainopara";
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell){
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Gabriel & ainopara" message:nil delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
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
#pragma mark - convert



@end
