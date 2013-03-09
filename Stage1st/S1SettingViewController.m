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
#import "GSStaticTableViewBuilder.h"

@interface S1SettingViewController ()

@property (nonatomic, assign) BOOL modified;

@end

@implementation S1SettingViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"设置", @"Setting");
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"返回", @"Back") style:UIBarButtonItemStyleDone target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelItem;
    
    self.modified = NO;
    __weak typeof(self) myself = self;
    
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"登录", @"Login");
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
                cell.textLabel.text = @"板块顺序";
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell) {
                GSReorderableTableViewController *controller = [[GSReorderableTableViewController alloc] initWithKeys:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"]];
                controller.title = NSLocalizedString(@"板块顺序", @"Order");
                [controller setCompletionHandler:^(NSArray *keys) {
                    [[NSUserDefaults standardUserDefaults] setValue:keys forKey:@"Order"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }];
                myself.modified = YES;
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
                cell.detailTextLabel.text = @"3.0";
            }];
        }];
        
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell){
                cell.textLabel.text = NSLocalizedString(@"开发者", @"Developer");
                cell.detailTextLabel.text = @"Gabriel";
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            }];
            [row setEventHandlerBlock:^(UITableViewCell *cell){
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Gabriel" message:@"" delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
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
        if (self.completionHandler) {
            self.completionHandler(self.modified);
        }
    }];
}

@end
