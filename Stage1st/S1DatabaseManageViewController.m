//
//  S1DatabaseManageViewController.m
//  Stage1st
//
//  Created by Zheng Li on 12/20/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1DatabaseManageViewController.h"
#import "S1TopicListViewController.h"
#import "S1DatabaseListCell.h"

@interface S1DatabaseManageViewController () <UIPopoverControllerDelegate>
@property (nonatomic, strong) NSMutableArray *importedDatabaseURLs;
@property (strong, nonatomic) UIPopoverController *activityPopoverController;
@end

@implementation S1DatabaseManageViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.importedDatabaseURLs = [NSMutableArray new];
    [self.tableView registerClass:[S1DatabaseListCell class] forCellReuseIdentifier:@"databaseInfoCell"];
    
    id rootvc = [(UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController] topViewController];
    if ([rootvc isKindOfClass:[S1TopicListViewController class]]) {
        NSFileManager * fileManager = [NSFileManager defaultManager];
        NSURL *databaseURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        NSDirectoryEnumerator *dirEnumerator = [fileManager enumeratorAtURL:databaseURL includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey,NSURLIsDirectoryKey,nil] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
        
        for (NSURL *theURL in dirEnumerator) {
            
            NSString *fileName;
            [theURL getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
            
            
            NSNumber *isDirectory;
            [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
            
            if ([isDirectory boolValue]==NO && [[fileName pathExtension] isEqualToString:@"s1db"]) {
                /*
                id rootvc = [(UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController] topViewController];
                if ([rootvc isKindOfClass:[S1TopicListViewController class]]) {
                    S1TopicListViewController *tlvc = rootvc;
                    [tlvc handleDatabaseImport:theURL];
                }*/
                [self.importedDatabaseURLs addObject:theURL];
                
            }
        }
    }
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return [self.importedDatabaseURLs count];
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    S1DatabaseListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"databaseInfoCell" forIndexPath:indexPath];
    if (!cell) {
        cell = [[S1DatabaseListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"databaseInfoCell"];
    }
    if (indexPath.section == 0) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *databaseURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        NSURL *finalURL = [databaseURL URLByAppendingPathComponent:@"Stage1stReader.db"];
        
        cell.databaseName = @"Stage1stReader";
        cell.textLabel.text = @"Stage1stReader";
        cell.databasePath = finalURL;
    }
    if (indexPath.section == 1) {
        NSURL *databasePath = [self.importedDatabaseURLs objectAtIndex:indexPath.row];
        NSString *databaseName = [[databasePath lastPathComponent] stringByDeletingPathExtension];
        cell.databaseName = databaseName;
        cell.textLabel.text = databaseName;
        cell.databasePath = databasePath;
    }
    
    if (indexPath.section == 0) {
        if (cell.longPressGestureRecognizer == nil)
        {
            UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(shareDatabaseGesture:)];
            [cell addGestureRecognizer:longPressGestureRecognizer];
        }
    } else {
        if (cell.longPressGestureRecognizer == nil)
        {
            UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(mergeDatabaseGesture:)];
            [cell addGestureRecognizer:longPressGestureRecognizer];
        }
    }
    
    // Configure the cell...
    
    return cell;
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    if (indexPath.section == 1) {
        return YES;
    }
    return NO;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)shareDatabaseGesture:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        NSLog(@"begin share event");
        S1DatabaseListCell *cell = (S1DatabaseListCell *)[gestureRecognizer view];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *documentURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        NSURL *finalURL = [documentURL URLByAppendingPathComponent:@"ainophone-2014-12-28.s1db"];
        [fileManager copyItemAtURL:cell.databasePath toURL:finalURL error:nil];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
        [self shareDatabaseAtPath:finalURL inRect:rect];
    }
}
- (void)mergeDatabaseGesture:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        NSLog(@"begin merge event");
        //TODO: finish it!
    }
}
- (void)shareDatabaseAtPath:(NSURL *)databasePath inRect:(CGRect)rect
{
    
    UIActivityViewController *activityViewController = nil;
    
    if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_0)
    {
        activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[databasePath] applicationActivities:@[]];
        activityViewController.excludedActivityTypes = @[UIActivityTypeMessage]; // Can't install from Messages app, and we use our own Mail activity that supports custom file types
    }
    else
    {
        activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[databasePath] applicationActivities:nil];
        activityViewController.excludedActivityTypes = @[UIActivityTypeMessage];
    }
    
    
    if ([UIAlertController class])
    {
        activityViewController.modalPresentationStyle = UIModalPresentationPopover;
        
        UIPopoverPresentationController *presentationController = [activityViewController popoverPresentationController];
        presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
        presentationController.sourceView = self.view;
        presentationController.sourceRect = rect;
        
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
    else
    {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [self presentViewController:activityViewController animated:YES completion:NULL];
        }
        else
        {
            self.activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
            self.activityPopoverController.delegate = self;
            [self.activityPopoverController presentPopoverFromRect:rect inView:self.splitViewController.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
        }
    }
}

@end
