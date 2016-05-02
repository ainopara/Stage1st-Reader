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
#import <YapDatabase/YapDatabase.h>


@implementation S1Tracer

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        //SQLite database
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *databaseURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        NSString *databasePath = [databaseURL.path stringByAppendingPathComponent:@"Stage1stReader.db"];

        _db = [FMDatabase databaseWithPath:databasePath];
        if (![_db open]) {
            DDLogError(@"[S1Tracer] Could not open db:%@", databasePath);
            return nil;
        }

        [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS threads(topic_id INTEGER PRIMARY KEY NOT NULL,title VARCHAR,reply_count INTEGER,field_id INTEGER,last_visit_time INTEGER, last_visit_page INTEGER, last_viewed_position FLOAT, visit_count INTEGER);"];
        [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS favorite(topic_id INTEGER PRIMARY KEY NOT NULL,favorite_time INTEGER);"];
        [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS history(topic_id INTEGER PRIMARY KEY NOT NULL);"];
    }
    return self;
}

- (void)dealloc
{
    DDLogDebug(@"[S1Tracer] Database closed.");
    [_db close];
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
    if (topic.title == nil) {
        topic.title = @"";
    }
    return topic;
}

#pragma mark - Migrate

+ (void)upgradeDatabase
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectory = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    NSURL *dbPathURL = [documentDirectory URLByAppendingPathComponent:@"Stage1stReader.db"];
    NSString *dbPath = [dbPathURL path];
    if ([fileManager fileExistsAtPath:dbPath]) {
        FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
        if (![db open]) {
            DDLogError(@"[Migrate] Could not open db.");
            return;
        }
        FMResultSet *result = [db executeQuery:@"SELECT last_viewed_position FROM threads;"];
        if (result) {
            ;
        } else {
            DDLogInfo(@"[Migrate] Add `last_viewed_position` column.");
            [db executeUpdate:@"ALTER TABLE threads ADD COLUMN last_viewed_position FLOAT;"];
        }
        [db close];
    }
}

+ (void)importTopicsInSet:(FMResultSet *)result {
    __block NSInteger newCount = 0;
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
                    newCount += 1;
                }
                if (tracedTopic) {
                    if (tracedTopic.hasChangedProperties) {
                        //DDLogDebug(@"Insert: %@ %@",tracedTopic.topicID, tracedTopic.changedProperties);
                        [transaction setObject:tracedTopic forKey:[tracedTopic.topicID stringValue] inCollection:Collection_Topics];
                        changeCount += 1;
                    }
                    succeedCount += 1;
                } else {
                    failCount += 1;
                }
                if (changeCount % 100 == 1) {
                    break;
                }
            }
            if (![result hasAnotherRow]) {
                allImported = YES;
            }
        }];
    }
    DDLogDebug(@"%ld / %ld Changed.(%ld new) %ld fails.", (long)changeCount, (long)succeedCount, (long)newCount, (long)failCount);
}

+ (void)importDatabaseAtPath:(NSURL *)dbPathURL {
    NSString *dbPath = [dbPathURL path];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectory = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
    if (![db open]) {
        DDLogError(@"Could not open db.");
        return;
    }
    DDLogDebug(@"migrateDatabase begin.");
    FMResultSet *result = [db executeQuery:@"SELECT history.topic_id AS topic_id, title, reply_count, field_id, last_visit_time, last_visit_page, last_viewed_position, favorite_time FROM ((history INNER JOIN threads ON history.topic_id = threads.topic_id) LEFT JOIN favorite ON favorite.topic_id = threads.topic_id) ORDER BY last_visit_time DESC;"];
    [S1Tracer importTopicsInSet:result];
    result = [db executeQuery:@"SELECT threads.topic_id AS topic_id, title, reply_count, field_id, last_visit_time, last_visit_page, last_viewed_position, favorite_time FROM (threads JOIN favorite ON favorite.topic_id = threads.topic_id) ORDER BY last_visit_time DESC;"];
    [S1Tracer importTopicsInSet:result];
    [db close];
    DDLogDebug(@"migrateDatabase finish.");
    NSError *error;
    [fileManager moveItemAtURL:dbPathURL toURL:[documentDirectory URLByAppendingPathComponent:@"Stage1stReader.dbbackup"] error:&error];
    if (error) {
        DDLogError(@"Fail to Rename Database: %@",error);
    }
}

+ (void)migrateToYapDatabase {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *dbPathURL1 = [[self documentDirectory] URLByAppendingPathComponent:@"Stage1stReader.db"];
        NSString *dbPath1 = [dbPathURL1 path];
        NSURL *dbPathURL2 = [[self documentDirectory] URLByAppendingPathComponent:@"Stage1stReader.databasebackup"];
        NSString *dbPath2 = [dbPathURL2 path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath1]) {
            [S1Tracer importDatabaseAtPath:dbPathURL1];
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath2]) {
            [S1Tracer importDatabaseAtPath:dbPathURL2];
        }
    });
}

+ (NSURL *)documentDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectory = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    return documentDirectory;
}
@end
