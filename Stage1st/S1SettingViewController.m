//
//  S1SettingViewController.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1SettingViewController.h"
#import "GSStaticTableViewBuilder.h"

@interface S1SettingViewController ()

@end

@implementation S1SettingViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Setting", @"Setting");
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelItem;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
	// Do any additional setup after loading the view.
    [self addSection:^(GSSection *section) {
        [section addRow:^(GSRow *row) {
            [row setConfigurationBlock:^(UITableViewCell *cell) {
                cell.textLabel.text = @"Stage1st";
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
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
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
