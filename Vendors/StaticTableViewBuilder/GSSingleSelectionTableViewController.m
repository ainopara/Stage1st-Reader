//
//  GSSingleSelectionTableViewController.m
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 2/11/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import "GSSingleSelectionTableViewController.h"

@interface GSSingleSelectionTableViewController ()

@property (nonatomic, copy) NSString *selectedKey;
@property (nonatomic, strong) NSArray *keys;

@property (nonatomic, strong) UITableViewCell *selectedCell;

@end

@implementation GSSingleSelectionTableViewController

- (id)initWithKeys:(NSArray *)keys andSelectedKey:(NSString *)selectedKey
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (!self) return nil;
    _keys = keys;
    _selectedKey = selectedKey;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    __weak typeof(self) myself = self;
    [self addSection:^(GSSection *section) {
        [myself.keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [section addRow:^(GSRow *row) {
                [row setConfigurationBlock:^(UITableViewCell *cell) {
                    cell.textLabel.text = (NSString *)obj;
                    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    if ([myself.selectedKey isEqualToString:(NSString *)obj]) {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                        myself.selectedCell = cell;
                    }
                }];
                
                [row setEventHandlerBlock:^(UITableViewCell *cell) {
                    myself.selectedCell.accessoryType = UITableViewCellAccessoryNone;
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    myself.selectedCell = cell;
                    myself.selectedKey = cell.textLabel.text;
                }];
            }];
        }];
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.completionHandler) {
        self.completionHandler(self.selectedKey);
    }
    [super viewWillDisappear:animated];
}


@end
