//
//  GSReorderableTableViewController.m
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 2/10/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import "GSReorderableTableViewController.h"


@interface GSReorderableTableViewController ()

@property (nonatomic, strong) NSMutableArray *keys;

@end

@implementation GSReorderableTableViewController

- (id)initWithKeys:(NSArray *)keys
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (!self) return nil;
    _keys = [NSMutableArray arrayWithCapacity:[keys count]];
    [keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSAssert([obj isKindOfClass:[NSArray class]], @"Expected array item");
        [self->_keys addObject:[NSMutableArray arrayWithArray:(NSArray *)obj]];
    }];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self.keys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self addSection:^(GSSection *section) {
            [(NSArray *)obj enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [section addRow:^(GSRow *row) {
                    [row setConfigurationBlock:^(UITableViewCell *cell) {
                        cell.textLabel.text = [obj description];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.showsReorderControl = YES;
                    }];
                }];
            }];
        }];
    }];
    
    self.tableView.editing = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.completionHandler)
        self.completionHandler(self.keys);
    [super viewWillDisappear:animated];
}


#pragma mark - UITableView Delegate and Datasource

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)tableView:(UITableView *)tableview shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}


- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    [self moveObjectAtIndexPath:sourceIndexPath inArray:[self.sections[sourceIndexPath.section] rows] toIndexPath:destinationIndexPath inArray:[self.sections[destinationIndexPath.section] rows]];
    [self moveObjectAtIndexPath:sourceIndexPath inArray:self.keys[sourceIndexPath.section] toIndexPath:destinationIndexPath inArray:self.keys[destinationIndexPath.section]];
    
}

#pragma mark - Helpers

- (void)moveObjectAtIndexPath:(NSIndexPath *)sourceIndexPath inArray:(NSMutableArray *)fromArray
                  toIndexPath:(NSIndexPath *)destinationIndexPath inArray:(NSMutableArray *)toArray
{
    id objToMove = fromArray[sourceIndexPath.row];
    [fromArray removeObjectAtIndex:sourceIndexPath.row];
    [toArray insertObject:objToMove atIndex:destinationIndexPath.row];
}


@end
