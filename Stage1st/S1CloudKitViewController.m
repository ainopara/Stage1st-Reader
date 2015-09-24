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
            self.lastErrorMessageLabel.text = [NSString stringWithFormat:@"%ld", (long)error.code];
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
    if (self.iCloudSwitch.on) {
        MyCloudKitManager.enabled = YES;
        [MyCloudKitManager continueCloudKitFlow];
    } else {
        MyCloudKitManager.enabled = NO;
    }
}

#pragma mark - Table view data source

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Notification

- (void)didReceivePaletteChangeNotification:(NSNotification *)notification {
        [self.iCloudSwitch setOnTintColor:[[S1ColorManager sharedInstance] colorForKey:@"appearance.switch.tint"]];
    [self.navigationController.navigationBar setBarTintColor:[[S1ColorManager sharedInstance]  colorForKey:@"appearance.navigationbar.battint"]];
    [self.navigationController.navigationBar setTintColor:[[S1ColorManager sharedInstance]  colorForKey:@"appearance.navigationbar.tint"]];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [[S1ColorManager sharedInstance] colorForKey:@"appearance.navigationbar.title"],NSFontAttributeName:[UIFont boldSystemFontOfSize:17.0],}];
}

- (void)cloudKitSuspendCountChanged:(NSNotification *)notification
{
    NSUInteger suspendCount = [MyDatabaseManager.cloudKitExtension suspendCount];
    if (suspendCount > 0) {
        self.currentStatusLabel.text = [NSString stringWithFormat:@"Suspended(%lu)", (unsigned long)suspendCount];
    } else {
        self.currentStatusLabel.text = @"Resumed";
    }
}

- (void)cloudKitInFlightChangeSetChanged:(NSNotification *)notification
{
    NSUInteger inFlightCount = 0;
    NSUInteger queuedCount = 0;
    [MyDatabaseManager.cloudKitExtension getNumberOfInFlightChangeSets:&inFlightCount queuedChangeSets:&queuedCount];
    self.uploadQueueLabel.text = [NSString stringWithFormat:@"%lu-%lu", (unsigned long)inFlightCount, (unsigned long)queuedCount];
}

- (void)cloudKitUnhandledErrorOccurred:(NSNotification *)notification
{
    NSError *error = notification.object;
    self.lastErrorMessageLabel.text = [NSString stringWithFormat:@"%ld", (long)error.code];
}
@end
