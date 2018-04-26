//
//  SettingsViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/13/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//


@interface SettingsViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UITableViewCell *iCloudSyncCell;

@end

@interface SettingsViewController ()<UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *usernameDetail;
@property (weak, nonatomic) IBOutlet UILabel *fontSizeDetail;
@property (weak, nonatomic) IBOutlet UISwitch *displayImageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *keepHistoryDetail;
@property (weak, nonatomic) IBOutlet UISwitch *removeTailsSwitch;
@property (weak, nonatomic) IBOutlet UILabel *versionDetail;
@property (weak, nonatomic) IBOutlet UISwitch *precacheSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *nightModeSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *forcePortraitSwitch;

@property (weak, nonatomic) IBOutlet UITableViewCell *forumOrderCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *fontSizeCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *keepHistoryCell;

@property (weak, nonatomic) IBOutlet UITableViewCell *forcePortraitCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *imageCacheCell;

@property (assign, nonatomic) CGFloat offset;

@end
