//
//  S1AppDelegate.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1AppDelegate.h"
#import "S1TopicListViewController.h"
#import "S1ContentViewController.h"
#import "S1URLCache.h"
#import "S1Topic.h"
#import "S1Tracer.h"
#import "S1Parser.h"
#import "S1DataCenter.h"
#import "CloudKitManager.h"
#import "DatabaseManager.h"
#import "DDTTYLogger.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

S1AppDelegate *MyAppDelegate;

@implementation S1AppDelegate

- (instancetype)init {
    if ((self = [super init])) {
        // Store global reference
        MyAppDelegate = self;
        // Configure logging
        //[DDLog addLogger:[DDTTYLogger sharedInstance]];
    }
    return self;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Flurry
    // [Flurry startSession:@"48VB6MB3WY6JV73VJZCY"];
    // Crashlytics
    [Fabric with:@[[Crashlytics class]]];

    // Setup User Defaults
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"Order"]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"InitialOrder" ofType:@"plist"];
        NSArray *order = [NSArray arrayWithContentsOfFile:path];
        [[NSUserDefaults standardUserDefaults] setValue:order forKey:@"Order"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"Display"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Display"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"]) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [[NSUserDefaults standardUserDefaults] setValue:@"18px" forKey:@"FontSize"];
        } else {
            [[NSUserDefaults standardUserDefaults] setValue:@"17px" forKey:@"FontSize"];
        }
        
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@-1 forKey:@"HistoryLimit"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"ReplyIncrement"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ReplyIncrement"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"RemoveTails"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"RemoveTails"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"UseAPI"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"UseAPI"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"PrecacheNextPage"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PrecacheNextPage"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"ForcePortraitForPhone"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ForcePortraitForPhone"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"NightMode"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NightMode"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"EnableSync"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"EnableSync"];
    }
    
    // Migrate to v3.4.0
    NSArray *array = [[NSUserDefaults standardUserDefaults] valueForKey:@"Order"];
    NSArray *array0 =[array firstObject];
    NSArray *array1 =[array lastObject];
    if([array0 indexOfObject:@"模玩专区"] == NSNotFound && [array1 indexOfObject:@"模玩专区"]== NSNotFound) {
        NSLog(@"Update Order List");
        NSString *path = [[NSBundle mainBundle] pathForResource:@"InitialOrder" ofType:@"plist"];
        NSArray *order = [NSArray arrayWithContentsOfFile:path];
        [[NSUserDefaults standardUserDefaults] setValue:order forKey:@"Order"];
        [[NSUserDefaults standardUserDefaults] setValue:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UserID"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UserPassword"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] isEqualToString:@"http://bbs.saraba1st.com/2b/"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
    }
    
    // Migrate to v3.6
    [S1Tracer upgradeDatabase];
    
    // Migrate to v3.7
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [[[NSUserDefaults standardUserDefaults] valueForKey:@"FontSize"] isEqualToString:@"17px"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"18px" forKey:@"FontSize"];
    }
    // Migrate to v3.8
    if([array0 indexOfObject:@"真碉堡山"] == NSNotFound && [array1 indexOfObject:@"真碉堡山"]== NSNotFound) {
        NSArray *order = @[array0, [array1 arrayByAddingObject:@"真碉堡山"]];
        [[NSUserDefaults standardUserDefaults] setValue:order forKey:@"Order"];
    }
    
    // Start database & cloudKit (in that order)
    
    [DatabaseManager initialize];
    if (SYSTEM_VERSION_LESS_THAN(@"8") || ![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"]) {
        // iOS 7 do not support CloudKit
        ;
    } else {
        // iOS 8 and more
        [CloudKitManager initialize];
    }

    // Migrate Database
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [S1Tracer migrateDatabase];
    });

    if (SYSTEM_VERSION_LESS_THAN(@"8") || ![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"]) {
        // iOS 7 do not support CloudKit
        // Nothing to do.
    } else {
        // iOS 8 and more
        // Register for push notifications
        UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil];
        [application registerUserNotificationSettings:notificationSettings];
    }
    
    
    // Reachability
    _reachability = [Reachability reachabilityForInternetConnection];
    [_reachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    // URL Cache
    S1URLCache *URLCache = [[S1URLCache alloc] initWithMemoryCapacity:10 * 1024 * 1024 diskCapacity:40 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];

    // Appearence
    
    /*
    if (SYSTEM_VERSION_LESS_THAN(@"8")) {
        ;
    } else {
        [[UIView appearanceWhenContainedIn:[UIAlertController class], nil] setTintColor:[[APColorManager sharedInstance]  colorForKey:@"appearance.navigationbar.tint"]];
    }
    */
    [[APColorManager sharedInstance] updateGlobalAppearance];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    //[KMCGeigerCounter sharedGeigerCounter].enabled = YES;
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    // [[NSUserDefaults standardUserDefaults] synchronize]; // This is automatically called.
    [[S1DataCenter sharedDataCenter] cleaning];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - URL Scheme
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    NSLog(@"%@ from %@", url, sourceApplication);
    
    //Open Specific Topic Case
    NSDictionary *queryDict = [S1Parser extractQuerysFromURLString:[url absoluteString]];
    if ([[url host] isEqualToString:@"open"]) {
        NSString *topicIDString = [queryDict valueForKey:@"tid"];
        
        if (topicIDString) {
            NSNumber *topicID = [NSNumber numberWithInteger:[topicIDString integerValue]];
            S1Topic *topic = [[S1DataCenter sharedDataCenter] tracedTopic:topicID];
            if (topic == nil) {
                topic = [[S1Topic alloc] init];
                topic.topicID = topicID;
            }
            [self presentContentViewControllerForTopic:topic];
            return YES;
        }
    }
    
    if ([[url host] isEqualToString:@"settings"]) {
        for (NSString *key in queryDict) {
            if ([key isEqualToString:@"ForcePortraitForPhone"]) {
                NSString *value = [queryDict valueForKey:key];
                if ([value isEqualToString:@"YES"]) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ForcePortraitForPhone"];
                }
                if ([value isEqualToString:@"NO"]) {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ForcePortraitForPhone"];
                }
            }
        }
    }
    
    return YES;
}

#pragma mark - Push Notification For Sync (iOS 8)

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    NSLog(@"application:didRegisterUserNotificationSettings: %@", notificationSettings);
    [application registerForRemoteNotifications];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"Registered for Push notifications with token: %@", deviceToken);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Push subscription failed: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    NSLog(@"Push received: %@", userInfo);
    if (SYSTEM_VERSION_LESS_THAN(@"8") || ![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"]) {
        // iOS 7
        return;
    }
    // iOS 8 and more
    __block UIBackgroundFetchResult combinedFetchResult = UIBackgroundFetchResultNoData;
    
    [[CloudKitManager sharedInstance] fetchRecordChangesWithCompletionHandler:
        ^(UIBackgroundFetchResult fetchResult, BOOL moreComing) {
        if (fetchResult == UIBackgroundFetchResultNewData) {
            combinedFetchResult = UIBackgroundFetchResultNewData;
        }
        else if (fetchResult == UIBackgroundFetchResultFailed && combinedFetchResult == UIBackgroundFetchResultNoData) {
            combinedFetchResult = UIBackgroundFetchResultFailed;
        }
        
        if (!moreComing) {
            completionHandler(combinedFetchResult);
        }
    }];
}

#pragma mark - Background Sync
/*
-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
 
}
*/

#pragma mark - Hand Off (iOS 8)

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType {
    return YES;
}
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))restorationHandler {
    NSLog(@"Receive Hand Off: %@", userActivity.userInfo);
    NSNumber *topicID = [userActivity.userInfo valueForKey:@"topicID"];
    if (topicID) {
        S1Topic *topic = [[S1DataCenter sharedDataCenter] tracedTopic:topicID];
        if (topic) {
            NSNumber *lastViewedPage = [userActivity.userInfo valueForKey:@"page"];
            if (lastViewedPage) {
                topic = [topic copy];
                topic.lastViewedPage = lastViewedPage;
            }
        } else {
            topic = [[S1Topic alloc] init];
            topic.topicID = topicID;
            NSNumber *lastViewedPage = [userActivity.userInfo valueForKey:@"page"];
            if (lastViewedPage) {
                topic.lastViewedPage = lastViewedPage;
            }
        }
        [self presentContentViewControllerForTopic:topic];
        return YES;
    } else {
        NSString *urlString = [userActivity.webpageURL absoluteString];
        S1Topic *parsedTopic = [S1Parser extractTopicInfoFromLink:urlString];
        if (parsedTopic.topicID) {
            S1Topic *tracedTopic = [[S1DataCenter sharedDataCenter] tracedTopic:parsedTopic.topicID];
            if (tracedTopic) {
                NSNumber *lastViewedPage = parsedTopic.lastViewedPage;
                if (lastViewedPage) {
                    tracedTopic = [tracedTopic copy];
                    tracedTopic.lastViewedPage = lastViewedPage;
                }
                [self presentContentViewControllerForTopic:tracedTopic];
                return YES;
            } else {
                [self presentContentViewControllerForTopic:parsedTopic];
                return YES;
            }
        }
    }
    return NO;
}
#pragma mark - Reachability

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *reachability = notification.object;
    if ([reachability isReachableViaWiFi]) {
        NSLog(@"%@",@"display picture");
    } else {
        NSLog(@"%@",@"display placeholder");
    }
}

#pragma mark - Helper
- (void)presentContentViewControllerForTopic:(S1Topic *)topic {
    id rootvc = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    if ([rootvc isKindOfClass:[UINavigationController class]]) {
        S1ContentViewController *contentViewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"Content"];
        [contentViewController setTopic:topic];
        [contentViewController setDataCenter:[S1DataCenter sharedDataCenter]];
        [(UINavigationController *)rootvc pushViewController:contentViewController animated:YES];
    }
}
@end
