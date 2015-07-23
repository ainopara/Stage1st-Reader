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

#pragma mark - Backend Protocol

- (void)hasViewed:(S1Topic *)topic
{
    NSNumber *topicID = topic.topicID;
    NSString *title = topic.title;
    NSNumber *replyCount = topic.replyCount;
    NSNumber *fID = topic.fID;
    NSNumber *lastViewedDate = [NSNumber numberWithDouble:[topic.lastViewedDate timeIntervalSince1970]];
    NSNumber *lastViewedPage = topic.lastViewedPage;
    NSNumber *lastViewedPosition = topic.lastViewedPosition;
    FMResultSet *result = [_db executeQuery:@"SELECT * FROM threads WHERE topic_id = ?;", topicID];
    if ([result next]) {
        NSNumber *visitCount = [[NSNumber alloc] initWithInt:[_db intForQuery:@"SELECT visit_count FROM threads WHERE topic_id = ?;", topicID] + 1];
        [_db executeUpdate:@"UPDATE threads SET title = ?,reply_count = ?,field_id = ?,last_visit_time = ?,last_visit_page = ?, last_viewed_position = ?,visit_count = ? WHERE topic_id = ?;",
         title, replyCount, fID, lastViewedDate, lastViewedPage, lastViewedPosition, visitCount, topicID];
    } else {
        [_db executeUpdate:@"INSERT INTO threads (topic_id, title, reply_count, field_id, last_visit_time, last_visit_page, last_viewed_position, visit_count) VALUES (?,?,?,?,?,?,?,?);",
         topicID, title, replyCount, fID, lastViewedDate, lastViewedPage, lastViewedPosition, [NSNumber numberWithInt:1]];
    }
    FMResultSet *historyResult = [_db executeQuery:@"SELECT * FROM history WHERE topic_id = ?;", topicID];
    if ([historyResult next]) {
        ;
    } else {
        [_db executeUpdate:@"INSERT INTO history (topic_id) VALUES (?);", topicID];
    }
    
    if (topic.favorite != nil) {
        [self setTopicFavoriteState:topic.topicID withState:[topic.favorite boolValue]];
    }
    NSLog(@"Tracer has traced:%@", topic);
}

- (void)removeTopicFromHistory:(NSNumber *)topicID
{
    FMResultSet *historyResult = [_db executeQuery:@"SELECT topic_id FROM history WHERE topic_id = ?;",topicID];
    if ([historyResult next]) {
        [_db executeUpdate:@"DELETE FROM history WHERE topic_id = ?;", topicID];
    }
}


- (NSMutableArray *)historyObjectsWithLeftCallback:(void (^)(NSMutableArray *))leftTopicsHandler
{
    NSMutableArray *historyTopics = [NSMutableArray array];
    FMResultSet *historyResult = [_db executeQuery:@"SELECT * FROM (history INNER JOIN threads ON history.topic_id = threads.topic_id) ORDER BY threads.last_visit_time DESC;"];
    NSInteger count = 0;
    while ([historyResult next]) {
        [historyTopics addObject:[S1Tracer topicFromQueryResult:historyResult]];
        count += 1;
        if (count == 100) {
            break;
        }
    }
    for (S1Topic *topic in historyTopics) {
        topic.favorite = [NSNumber numberWithBool:[S1Tracer topicIsFavorited:topic.topicID inDatabase:_db]];
        topic.history = [NSNumber numberWithBool:[S1Tracer topicIsInHistory:topic.topicID inDatabase:_db]];
    }
    if (count > 99) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray *historyTopicsLeft = [NSMutableArray array];
            while ([historyResult next]) {
                [historyTopicsLeft addObject:[S1Tracer topicFromQueryResult:historyResult]];
            }
            NSLog(@"History Left count: %lu",(unsigned long)[historyTopicsLeft count] + count);
            for (S1Topic *topic in historyTopicsLeft) {
                topic.favorite = [NSNumber numberWithBool:[S1Tracer topicIsFavorited:topic.topicID inDatabase:_backgroundDb]];
                topic.history = [NSNumber numberWithBool:[S1Tracer topicIsInHistory:topic.topicID inDatabase:_backgroundDb]];
            }
            leftTopicsHandler(historyTopicsLeft);
        });
    }
    
    return historyTopics;
}

- (NSMutableArray *)favoritedObjects
{
    NSMutableArray *favoriteTopics = [NSMutableArray array];
    FMResultSet *favoriteResult = [_db executeQuery:@"SELECT * FROM (favorite INNER JOIN threads ON favorite.topic_id = threads.topic_id) ORDER BY threads.last_visit_time DESC;"];
    while ([favoriteResult next]) {
        [favoriteTopics addObject:[S1Tracer topicFromQueryResult:favoriteResult inDatabase:_db]];
    }
    NSLog(@"Favorite count: %lu",(unsigned long)[favoriteTopics count]);
    return favoriteTopics;
}

- (BOOL)topicIsFavorited:(NSNumber *)topic_id
{
    return [S1Tracer topicIsFavorited:topic_id inDatabase:_db];
}

-(void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state
{
    FMResultSet *historyResult = [_db executeQuery:@"SELECT topic_id FROM favorite WHERE topic_id = ?;",topicID];
    if ([historyResult next]) {
        if (state) {
            ;
        } else {
            [_db executeUpdate:@"DELETE FROM favorite WHERE topic_id = ?;", topicID]; //topic_id in favorite table and state should be NO
        }
    } else {
        if (state) {
            [_db executeUpdate:@"INSERT INTO favorite (topic_id, favorite_time) VALUES (?,?);", topicID, [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]]]; //topic_id not in favorite table and state should be YES
        } else {
            ;
        }
    }
}

- (S1Topic *)tracedTopicByID:(NSNumber *)topicID
{
    FMResultSet *result = [_db executeQuery:@"SELECT * FROM threads WHERE topic_id = ?;",topicID];
    if ([result next]) {
        return [S1Tracer topicFromQueryResult:result inDatabase:_db];
    } else {
        return nil;
    }
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
    topic.visitCount = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"visit_count"]];
    topic.lastViewedDate = [[NSDate alloc] initWithTimeIntervalSince1970: [result doubleForColumn:@"last_visit_time"]];
    return topic;
}
+ (S1Topic *)topicFromQueryResult:(FMResultSet *)result inDatabase:(FMDatabase *)database {
    S1Topic *topic = [[S1Topic alloc] init];
    topic.topicID = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"topic_id"]];
    topic.title = [result stringForColumn:@"title"];
    topic.replyCount = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"reply_count"]];
    topic.fID = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"field_id"]];
    topic.lastViewedPage = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"last_visit_page"]];
    topic.lastViewedPosition = [NSNumber numberWithFloat:[result doubleForColumn:@"last_viewed_position"]];
    topic.visitCount = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"visit_count"]];
    topic.favorite = [NSNumber numberWithBool:[S1Tracer topicIsFavorited:topic.topicID inDatabase:database]];
    topic.history = [NSNumber numberWithBool:[S1Tracer topicIsInHistory:topic.topicID inDatabase:database]];
    topic.lastViewedDate = [[NSDate alloc] initWithTimeIntervalSince1970: [result doubleForColumn:@"last_visit_time"]];
    return topic;
}

+ (BOOL)topicIsFavorited:(NSNumber *)topicID inDatabase:(FMDatabase *)database
{
    FMResultSet *historyResult = [database executeQuery:@"SELECT topic_id FROM favorite WHERE topic_id = ?;",topicID];
    if ([historyResult next]) {
        return YES;
    } else {
        return NO;
    }
    
}

+ (BOOL)topicIsInHistory:(NSNumber *)topicID inDatabase:(FMDatabase *)database
{
    FMResultSet *historyResult = [database executeQuery:@"SELECT topic_id FROM history WHERE topic_id = ?;",topicID];
    if ([historyResult next]) {
        return YES;
    } else {
        return NO;
    }
    
}

#pragma mark - Archiver

- (void)synchronize
{
    [self purgeStaleItem];
}

- (void)purgeStaleItem
{
    NSDate *now = [NSDate date];
    NSTimeInterval duration = [[[NSUserDefaults standardUserDefaults] valueForKey:@"HistoryLimit"] doubleValue];
    if (duration < 0) {
        return;
    }
    NSTimeInterval dueDate = [now timeIntervalSince1970] - duration;
    [_db executeUpdate:@"DELETE FROM history WHERE topic_id IN (SELECT history.topic_id FROM history INNER JOIN threads ON history.topic_id = threads.topic_id WHERE threads.last_visit_time < ?);",[[NSNumber alloc] initWithDouble:dueDate]];
    [_db executeUpdate:@"DELETE FROM threads WHERE topic_id NOT IN (SELECT topic_id FROM history UNION SELECT topic_id FROM favorite);"];
    
}

#pragma mark - Sync Database File
- (BOOL)syncWithDatabasePath:(NSString *)databasePath {
    FMDatabase *syncDatabase = [FMDatabase databaseWithPath:databasePath];
    if (![syncDatabase open]) {
        NSLog(@"Could not open db.");
        return NO;
    }
    FMResultSet *historyResult = [syncDatabase executeQuery:@"SELECT * FROM threads ORDER BY last_visit_time DESC;"];
    //use transaction
    NSInteger counter = 0;
    [_db beginTransaction];
    while ([historyResult next]) {
        S1Topic *topicThere = [S1Tracer topicFromQueryResult:historyResult inDatabase:syncDatabase];
        S1Topic *topicThis = [self tracedTopicByID:topicThere.topicID];
        if (topicThis != nil) {
            if ([topicThis absorbTopic:topicThere]) {
                [self updateTopic:topicThis];
                counter += 1;
            }
        } else {
            [self updateTopic:topicThere];
            counter += 1;
        }
    }
    [_db commit];
    [syncDatabase close];
    NSLog(@"%ld Items Updated.", (long)counter);
    return YES;
    
}

- (void)updateTopic:(S1Topic *)topic
{
    NSNumber *topicID = topic.topicID;
    NSString *title = topic.title;
    NSNumber *replyCount = topic.replyCount;
    NSNumber *fID = topic.fID;
    NSNumber *lastViewedDate = [NSNumber numberWithDouble:[topic.lastViewedDate timeIntervalSince1970]];
    NSNumber *lastViewedPage = topic.lastViewedPage;
    NSNumber *lastViewedPosition = topic.lastViewedPosition;
    NSNumber *visitCount = topic.visitCount;
    //update threads table
    FMResultSet *result = [_db executeQuery:@"SELECT * FROM threads WHERE topic_id = ?;", topicID];
    if ([result next]) {
        [_db executeUpdate:@"UPDATE threads SET title = ?,reply_count = ?,field_id = ?,last_visit_time = ?,last_visit_page = ?, last_viewed_position = ?,visit_count = ? WHERE topic_id = ?;",
         title, replyCount, fID, lastViewedDate, lastViewedPage, lastViewedPosition, visitCount, topicID];
    } else {
        [_db executeUpdate:@"INSERT INTO threads (topic_id, title, reply_count, field_id, last_visit_time, last_visit_page, last_viewed_position, visit_count) VALUES (?,?,?,?,?,?,?,?);",
         topicID, title, replyCount, fID, lastViewedDate, lastViewedPage, lastViewedPosition, visitCount];
    }
    //update history table
    if ([topic.history boolValue]) {
        FMResultSet *historyResult = [_db executeQuery:@"SELECT * FROM history WHERE topic_id = ?;", topicID];
        if ([historyResult next]) {
            ;
        } else {
            [_db executeUpdate:@"INSERT INTO history (topic_id) VALUES (?);", topicID];
        }
    }
    //update favorite table
    if ([topic.favorite boolValue]) {
        [self setTopicFavoriteState:topicID withState:YES];
    }
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

@end
