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

@interface S1SettingViewController ()
@property (weak, nonatomic) IBOutlet UILabel *usernameDetail;
@property (weak, nonatomic) IBOutlet UILabel *fontSizeDetail;
@property (weak, nonatomic) IBOutlet UISwitch *displayImageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *keepHistoryDetail;
@property (weak, nonatomic) IBOutlet UISwitch *replyIncrementSwitch;
@property (weak, nonatomic) IBOutlet UILabel *versionDetail;
@property (weak, nonatomic) IBOutlet UISwitch *useAPISwitch;


@end


@implementation S1SettingViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *inLoginStateID = [[NSUserDefaults standardUserDefaults] valueForKey:@"InLoginStateID"];
    if (inLoginStateID) {
        self.usernameDetail.text = inLoginStateID;
    }
    
    self.fontSizeDetail.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"];
    
    self.displayImageSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"Display"];
    
    self.keepHistoryDetail.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
    
    self.replyIncrementSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"ReplyIncrement"];
    self.useAPISwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseAPI"];
    
    self.versionDetail.text = [NSString stringWithFormat:@"%@ (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];

    
    
    //[self.view setTintColor:[S1Global color3]];
    /*
    self.navigationItem.title = NSLocalizedString(@"SettingView_NavigationBar_Title", @"Settings");
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"SettingView_NavigationBar_Back", @"Back") style:UIBarButtonItemStyleDone target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelItem;
    */
    //__weak typeof(self) myself = self;
    /*
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
                cell.detailTextLabel.text = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell) {
                NSString *selectedKey = [S1Global HistoryLimitNumber2String:[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]];
                GSSingleSelectionTableViewController *controller = [[GSSingleSelectionTableViewController alloc] initWithKeys:@[NSLocalizedString(@"SettingView_HistoryLimit_3days", @"3 days"), NSLocalizedString(@"SettingView_HistoryLimit_1week", @"1 week"),NSLocalizedString(@"SettingView_HistoryLimit_2weeks", @"2 weeks"),NSLocalizedString(@"SettingView_HistoryLimit_1month", @"1 month"), NSLocalizedString(@"SettingView_HistoryLimit_Forever", @"Forever")] andSelectedKey:selectedKey];
                controller.title = NSLocalizedString(@"SettingView_HistoryLimit", @"HistoryLimit");
                [controller setCompletionHandler:^(NSString *key) {
                    [[NSUserDefaults standardUserDefaults] setValue:[S1Global HistoryLimitString2Number:key] forKey:@"HistoryLimit"];
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
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"SettingView_ReplyIncrement", @"Show Reply Increment");
                if (!cell.accessoryView) {
                    UISwitch *switcher = [[UISwitch alloc] initWithFrame:CGRectZero];
                    switcher.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"ReplyIncrement"];
                    [switcher addEventHandler:^(id sender, UIEvent *event) {
                        UISwitch *s = sender;
                        [[NSUserDefaults standardUserDefaults] setBool:s.on forKey:@"ReplyIncrement"];
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
*/
}
#pragma mark - Orientation 
//TODO: Not work at all answer: set it to navigation controller

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    }
    return [super supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationPortrait;
    }
    return [super preferredInterfaceOrientationForPresentation];
}
#pragma mark -
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%@", indexPath);
    if (indexPath.section == 0 && indexPath.row == 8) {
        S1DatabaseManageViewController *databaseManageViewController = [[S1DatabaseManageViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:databaseManageViewController animated:YES];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}
#pragma mark -
- (IBAction)back:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (IBAction)switchDisplayImage:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"Display"];
}

- (IBAction)switchReplyIncrement:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"ReplyIncrement"];
}
- (IBAction)switchUseAPI:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"UseAPI"];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
}
@end
