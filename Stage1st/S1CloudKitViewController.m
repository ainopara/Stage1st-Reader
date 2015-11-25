//
//  S1CloudKitViewController.m
//  Stage1st
//
//  Created by Zheng Li on 8/22/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1CloudKitViewController.h"
#import "DatabaseManager.h"
#import "CloudKitManager.h"

@interface S1CloudKitViewController ()
@property (weak, nonatomic) IBOutlet UISwitch *iCloudSwitch;
@property (weak, nonatomic) IBOutlet UILabel *currentStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *uploadQueueLabel;
@property (weak, nonatomic) IBOutlet UILabel *clearCloudDataLabel;
@property (weak, nonatomic) IBOutlet UILabel *lastErrorMessageLabel;

@end

@implementation S1CloudKitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        // iOS 7
        self.iCloudSwitch.on = NO;
        self.iCloudSwitch.enabled = NO;
        self.currentStatusLabel.text = @"-";
        self.uploadQueueLabel.text = @"-";
        self.clearCloudDataLabel.enabled = NO;
        self.lastErrorMessageLabel.text = @"-";
    } else {
        // iOS 8 and more
        self.iCloudSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"];
        NSError *error = [MyCloudKitManager lastCloudkitError];
        if (error) {
            [self updateErrorMessageWithError:error];
        } else {
            self.lastErrorMessageLabel.text = @"-";
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceivePaletteChangeNotification:) name:@"S1PaletteDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitSuspendCountChanged:) name:YapDatabaseCloudKitSuspendCountChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitInFlightChangeSetChanged:) name:YapDatabaseCloudKitInFlightChangeSetChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudKitUnhandledErrorOccurred:) name:YapDatabaseCloudKitUnhandledErrorOccurredNotification object:nil];
    
    [self cloudKitSuspendCountChanged:nil];
    [self cloudKitInFlightChangeSetChanged:nil];
    if (MyCloudKitManager.lastCloudkitError != nil) {
        self.lastErrorMessageLabel.text = [NSString stringWithFormat:@"%ld", (long)MyCloudKitManager.lastCloudkitError.code];
    }
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Action

- (IBAction)switchiCloud:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:self.iCloudSwitch.on forKey:@"EnableSync"];
    NSString *title = NSLocalizedString(@"SettingView_CloudKit_Enable_Message", @"");
    NSString *message = @"";
    
    UIAlertView *alertView =
		  [[UIAlertView alloc] initWithTitle:title
                                     message:message
                                    delegate:nil
                           cancelButtonTitle:nil
                           otherButtonTitles:NSLocalizedString(@"Message_OK", @""), nil];
    
    [alertView show];
    if (self.iCloudSwitch.on == NO) {
        [MyCloudKitManager prepareForUnregister];
        [MyDatabaseManager unregisterCloudKitExtension];
    }
}

#pragma mark - Table view data source

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"%@",indexPath);
    if (indexPath.section == 1 && indexPath.row == 2) {
        if (MyCloudKitManager.lastCloudkitError == nil) {
            return;
        }
        NSString *title = @"Error Detail";
        NSString *message = [MyCloudKitManager.lastCloudkitError localizedDescription];
        if (message == nil) {
            message = @"No description information.";
        }
        
        UIAlertView *alertView =
        [[UIAlertView alloc] initWithTitle:title
                                   message:message
                                  delegate:nil
                         cancelButtonTitle:nil
                         otherButtonTitles:NSLocalizedString(@"Message_OK", @""), nil];
        
        [alertView show];
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        NSLog(@"Suspend");
        [MyDatabaseManager.cloudKitExtension suspend];
        
    } else if (indexPath.section == 2 && indexPath.row == 1) {
        NSLog(@"Resume");
        [MyDatabaseManager.cloudKitExtension resume];
    }
}

#pragma mark - Notification

- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
        [self.iCloudSwitch setOnTintColor:[[APColorManager sharedInstance] colorForKey:@"appearance.switch.tint"]];
    [self.navigationController.navigationBar setBarTintColor:[[APColorManager sharedInstance]  colorForKey:@"appearance.navigationbar.battint"]];
    [self.navigationController.navigationBar setTintColor:[[APColorManager sharedInstance]  colorForKey:@"appearance.navigationbar.tint"]];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [[APColorManager sharedInstance] colorForKey:@"appearance.navigationbar.title"],NSFontAttributeName:[UIFont boldSystemFontOfSize:17.0],}];
}

- (void)cloudKitSuspendCountChanged:(NSNotification *)notification {
    NSUInteger suspendCount = [MyDatabaseManager.cloudKitExtension suspendCount];
    if (suspendCount > 0) {
        self.currentStatusLabel.text = [NSString stringWithFormat:@"Suspended(%lu)", (unsigned long)suspendCount];
    } else {
        self.currentStatusLabel.text = @"Resumed";
    }
}

- (void)cloudKitInFlightChangeSetChanged:(NSNotification *)notification {
    NSUInteger inFlightCount = 0;
    NSUInteger queuedCount = 0;
    [MyDatabaseManager.cloudKitExtension getNumberOfInFlightChangeSets:&inFlightCount queuedChangeSets:&queuedCount];
    self.uploadQueueLabel.text = [NSString stringWithFormat:@"%lu-%lu", (unsigned long)inFlightCount, (unsigned long)queuedCount];
}

- (void)cloudKitUnhandledErrorOccurred:(NSNotification *)notification {
    NSError *error = notification.object;
    self.lastErrorMessageLabel.text = [NSString stringWithFormat:@"%ld", (long)error.code];
}

#pragma mark - Helper

- (void)updateErrorMessageWithError:(NSError *)error {
    NSString *code = [NSString stringWithFormat:@"%ld", (long)[error code]];
    NSString *errorDescription = [[error userInfo] valueForKey:@"CKErrorDescription"];
    NSString *subErrorDescription = nil;
    if (errorDescription == nil) {
        errorDescription = @"Unknown";
    }
    NSArray *allErrors = [(NSDictionary *)[[error userInfo] valueForKey:@"CKPartialErrors"] allValues];
    for (NSError *subError in allErrors) {
        if (subError.code != 22) {
            subErrorDescription = [subError localizedDescription];
            code = [code stringByAppendingString:[NSString stringWithFormat:@"/%ld", (long)[subError code]]];
            break;
        }
    }
    if (subErrorDescription != nil) {
        errorDescription = subErrorDescription;
    }
    self.lastErrorMessageLabel.text = code;
}
@end
