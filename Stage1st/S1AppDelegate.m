//
//  S1AppDelegate.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1AppDelegate.h"
#import "S1TopicListViewController.h"
#import "S1URLCache.h"
#import "S1Tracer.h"
#import "KMCGeigerCounter.h"

@implementation S1AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Setup User Defaults
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
        [[NSUserDefaults standardUserDefaults] setValue:@"17px" forKey:@"FontSize"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@259200 forKey:@"HistoryLimit"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"AppendSuffix"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"AppendSuffix"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"ReplyIncrement"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ReplyIncrement"];
    }
    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"UseAPI"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"UseAPI"];
    }
    
    //Migrate to v3.4.0
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
    //Migrate to v3.6
    [S1Tracer upgradeDatabase];
    
    //URL Cache
    S1URLCache *URLCache = [[S1URLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024 diskCapacity:10 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
    //Appearence
    [[UIToolbar appearance] setBarTintColor:[S1Global color1]];//color2
    [[UIToolbar appearance] setTintColor:[S1Global color3]];
    [[UINavigationBar appearance] setBarTintColor:[S1Global color1]];
    [[UINavigationBar appearance] setTintColor:[S1Global color3]];

    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    //[controller handlePasteboardString:[UIPasteboard generalPasteboard].string];
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
    [[NSUserDefaults standardUserDefaults] synchronize];
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

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    NSLog(@"%@ from %@", url, sourceApplication);
    
    //Open Specific Topic Case
    
    //Import Database Case
    if ([[url absoluteString] hasSuffix:@".s1db"]) {
        id rootvc = [(UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController] topViewController];
        if ([rootvc isKindOfClass:[S1TopicListViewController class]]) {
            S1TopicListViewController *tlvc = rootvc;
            [tlvc handleDatabaseImport:url];
        }
    }
    
    
    return YES;
}

@end
