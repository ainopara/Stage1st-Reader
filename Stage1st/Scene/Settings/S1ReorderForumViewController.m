//
//  S1ReorderForumViewController.m
//  Stage1st
//
//  Created by Zheng Li on 11/7/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1ReorderForumViewController.h"

@interface S1ReorderForumViewController ()

@property (nonatomic, strong) NSMutableArray *keys;

@end

@implementation S1ReorderForumViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.keys = [[NSMutableArray alloc] init];
    NSArray *lists = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Order"];
    for (NSArray *list in lists) {
        [self.keys addObject:[list mutableCopy]];
    }
    self.tableView.editing = YES;
}

-(void)viewWillDisappear:(BOOL)animated {
    [[NSUserDefaults standardUserDefaults] setValue:self.keys forKey:@"Order"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSNotification *notification = [NSNotification notificationWithName:@"S1UserMayReorderedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    [super viewWillDisappear:animated];
}

#pragma mark - Data Source & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.keys count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.keys[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = [NSString stringWithFormat:@"StaticCell-%ld, %ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    // Configure the cell...
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = self.keys[indexPath.section][indexPath.row];
    cell.showsReorderControl = YES;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableview shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    [self moveObjectAtIndexPath:sourceIndexPath inArray:self.keys[sourceIndexPath.section] toIndexPath:destinationIndexPath inArray:self.keys[destinationIndexPath.section]];
    [self.tableView reloadData];
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
