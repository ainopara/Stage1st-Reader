//
//  S1Tracer.m
//  Stage1st
//
//  Created by Suen Gabriel on 3/3/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Tracer.h"
#import "S1Topic.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "DatabaseManager.h"


@implementation S1Tracer {

}

- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    //SQLite database
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *databaseURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSString *databasePath = [databaseURL.path stringByAppendingPathComponent:@"Stage1stReader.db"];
    
    _db = [FMDatabase databaseWithPath:databasePath];
    if (![_db open]) {
        NSLog(@"Could not open db.");
        return nil;
    }
    _backgroundDb = [FMDatabase databaseWithPath:databasePath];
    if (![_backgroundDb open]) {
        NSLog(@"Could not open background db.");
        return nil;
    }
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS threads(topic_id INTEGER PRIMARY KEY NOT NULL,title VARCHAR,reply_count INTEGER,field_id INTEGER,last_visit_time INTEGER, last_visit_page INTEGER, last_viewed_position FLOAT, visit_count INTEGER);"];
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS favorite(topic_id INTEGER PRIMARY KEY NOT NULL,favorite_time INTEGER);"];
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS history(topic_id INTEGER PRIMARY KEY NOT NULL);"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize) name:UIApplicationWillTerminateNotification object:nil];
    return self;
}

- (void)dealloc
{
    NSLog(@"Database closed.");
    [_db close];
    [_backgroundDb close];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Static

+ (S1Topic *)topicFromQueryResult:(FMResultSet *)result {
    S1Topic *topic = [[S1Topic alloc] init];
    topic.topicID = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"topic_id"]];
    topic.title = [result stringForColumn:@"title"];
    topic.replyCount = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"reply_count"]];
    topic.fID = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"field_id"]];
    topic.lastViewedPage = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"last_visit_page"]];
    topic.lastViewedPosition = [NSNumber numberWithFloat:[result doubleForColumn:@"last_viewed_position"]];
    topic.lastViewedDate = [[NSDate alloc] initWithTimeIntervalSince1970: [result doubleForColumn:@"last_visit_time"]];
    topic.favoriteDate = [[NSDate alloc] initWithTimeIntervalSince1970: [result doubleForColumn:@"favorite_time"]];
    if (![topic.favoriteDate isEqual:[[NSDate alloc] initWithTimeIntervalSince1970:0]]) {
        topic.favorite = [NSNumber numberWithBool:YES];
    } else {
        topic.favorite = [NSNumber numberWithBool:NO];
    }
    return topic;
}

#pragma mark - Archiver

- (void)synchronize
{
    //[self purgeStaleItem];
}

#pragma mark - Upgrade

+ (void)upgradeDatabase
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectory = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    NSURL *dbPathURL = [documentDirectory URLByAppendingPathComponent:@"Stage1stReader.db"];
    NSString *dbPath = [dbPathURL path];
    if ([fileManager fileExistsAtPath:dbPath]) {
        FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
        if (![db open]) {
            NSLog(@"Could not open db.");
            return;
        }
        FMResultSet *result = [db executeQuery:@"SELECT last_viewed_position FROM threads;"];
        if (result) {
            ;
        } else {
            NSLog(@"Database does not have last_viewed_position column.");
            [db executeUpdate:@"ALTER TABLE threads ADD COLUMN last_viewed_position FLOAT;"];
        }
        [db close];
    }
    
}

#pragma mark - Migrate

+ (void)migrateDatabase {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"migrateDatabase begin.");
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *documentDirectory = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
        NSURL *dbPathURL = [documentDirectory URLByAppendingPathComponent:@"Stage1stReader.db"];
        NSString *dbPath = [dbPathURL path];
        if ([fileManager fileExistsAtPath:dbPath]) {
            FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
            if (![db open]) {
                NSLog(@"Could not open db.");
                return;
            }
            // TODO: Should change query to make sure topic that in favorite list but not in history list to be imported.
            FMResultSet *result = [db executeQuery:@"SELECT history.topic_id AS topic_id, title, reply_count, field_id, last_visit_time, last_visit_page, last_viewed_position, favorite_time FROM ((history INNER JOIN threads ON history.topic_id = threads.topic_id) LEFT JOIN favorite ON favorite.topic_id = threads.topic_id) ORDER BY last_visit_time DESC;"];
            __block NSInteger succeedCount = 0;
            __block NSInteger changeCount = 0;
            __block NSInteger failCount = 0;
            __block BOOL allImported = NO;
            while (!allImported) {
                [MyDatabaseManager.bgDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
                    while ([result next]) {
                        S1Topic *topic = [S1Tracer topicFromQueryResult:result];
                        S1Topic *tracedTopic = [transaction objectForKey:[topic.topicID stringValue] inCollection:Collection_Topics];
                        if (tracedTopic) {
                            tracedTopic = [tracedTopic copy];
                            [tracedTopic absorbTopic:topic];
                        } else {
                            tracedTopic = topic;
                        }
                        if (tracedTopic) {
                            if (tracedTopic.hasChangedProperties) {
                                NSLog(@"Insert: %@ %@",tracedTopic.topicID, tracedTopic.changedProperties);
                                [transaction setObject:tracedTopic forKey:[tracedTopic.topicID stringValue] inCollection:Collection_Topics];
                                changeCount += 1;
                            }
                            succeedCount += 1;
                        } else {
                            failCount += 1;
                        }
                        if (changeCount % 50 == 1) {
                            break;
                        }
                    }
                    if (![result hasAnotherRow]) {
                        allImported = YES;
                    }
                }];
            }
            NSLog(@"%ld Topics Counted.%ld Topics Changed.(%ld fails)", (long)succeedCount, (long)changeCount, (long)failCount);
            
            [db close];
            NSError *error;
            [fileManager moveItemAtURL:dbPathURL toURL:[documentDirectory URLByAppendingPathComponent:@"Stage1stReader.databasebackup"] error:&error];
            if (error) {
                NSLog(@"Fail to Rename Database: %@",error);
            }
        }
    });
}
@end
