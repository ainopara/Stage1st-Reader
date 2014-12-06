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
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS threads(topic_id INTEGER PRIMARY KEY NOT NULL,title VARCHAR,reply_count INTEGER,field_id INTEGER,last_visit_time INTEGER, last_visit_page INTEGER, last_viewed_position FLOAT, visit_count INTEGER);"];
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS favorite(topic_id INTEGER PRIMARY KEY NOT NULL,favorite_time INTEGER);"];
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS history(topic_id INTEGER PRIMARY KEY NOT NULL);"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    return self;
}

- (void)dealloc
{
    NSLog(@"Database closed.");//TODO:WHY NOT CALLED?
    [_db close];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillTerminateNotification object:nil];
}

- (void)hasViewed:(S1Topic *)topic
{
    [topic setValue:[NSDate date] forKey:@"lastViewedDate"];
    
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
    
    NSLog(@"Tracer has traced:%@", topic);
}

- (void)removeTopicFromHistory:(NSNumber *)topic_id
{
    FMResultSet *historyResult = [_db executeQuery:@"SELECT topic_id FROM history WHERE topic_id = ?;",topic_id];
    if ([historyResult next]) {
        [_db executeUpdate:@"DELETE FROM history WHERE topic_id = ?;", topic_id];
    }
}

- (S1Topic *)topicFromQueryResult:(FMResultSet *)result {
    S1Topic *topic = [[S1Topic alloc] init];
    topic.topicID = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"topic_id"]];
    topic.title = [result stringForColumn:@"title"];
    topic.replyCount = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"reply_count"]];
    topic.fID = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"field_id"]];
    topic.lastViewedPage = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"last_visit_page"]];
    topic.lastViewedPosition = [NSNumber numberWithFloat:[result doubleForColumn:@"last_viewed_position"]];
    topic.visitCount = [NSNumber numberWithLongLong:[result longLongIntForColumn:@"visit_count"]];
    topic.favorite = [NSNumber numberWithBool:[self topicIsFavorited:topic.topicID]];
    topic.lastViewedDate = [[NSDate alloc] initWithTimeIntervalSince1970: [result doubleForColumn:@"last_visit_time"]];
    return topic;
}

- (NSMutableArray *)historyObjectsWithSearchWord:(NSString *)searchWord
{
    NSString *sqlSearchWord;
    if (searchWord == nil || [searchWord isEqualToString:@""]) {
        sqlSearchWord = @"%%";
    } else {
        sqlSearchWord = [NSString stringWithFormat:@"%%%@%%", searchWord];
    }
    
    NSMutableArray *historyTopics = [NSMutableArray array];
    FMResultSet *historyResult = [_db executeQuery:@"SELECT * FROM (history INNER JOIN threads ON history.topic_id = threads.topic_id) WHERE title like ? ORDER BY threads.last_visit_time DESC LIMIT 1500;", sqlSearchWord];
    while ([historyResult next]) {
        [historyTopics addObject:[self topicFromQueryResult:historyResult]];
    }
    NSLog(@"History count: %lu",(unsigned long)[historyTopics count]);
    return historyTopics;
}

- (NSMutableArray *)favoritedObjectsWithSearchWord:(NSString *)searchWord
{
    NSString *sqlSearchWord;
    if (searchWord == nil || [searchWord isEqualToString:@""]) {
        sqlSearchWord = @"%%";
    } else {
        sqlSearchWord = [NSString stringWithFormat:@"%%%@%%", searchWord];
    }
    
    NSMutableArray *favoriteTopics = [NSMutableArray array];
    NSString *queryString = @"SELECT * FROM favorite INNER JOIN threads ON favorite.topic_id = threads.topic_id WHERE title like ? ORDER BY ";
    if (NO) {
        queryString = [queryString stringByAppendingString:@"favorite.favorite_time DESC;"];
    } else {
        queryString = [queryString stringByAppendingString:@"threads.last_visit_time DESC;"];
    }
    FMResultSet *favoriteResult = [_db executeQuery:queryString, sqlSearchWord];
    while ([favoriteResult next]) {
        [favoriteTopics addObject:[self topicFromQueryResult:favoriteResult]];
    }
    NSLog(@"Favorite count: %lu",(unsigned long)[favoriteTopics count]);
    return favoriteTopics;
}

- (S1Topic *)tracedTopic:(NSNumber *)topicID
{
    FMResultSet *result = [_db executeQuery:@"SELECT * FROM threads WHERE topic_id = ?;",topicID];
    if ([result next]) {
        return [self topicFromQueryResult:result];
    } else {
        return nil;
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

-(BOOL)topicIsFavorited:(NSNumber *)topic_id
{
    FMResultSet *historyResult = [_db executeQuery:@"SELECT topic_id FROM favorite WHERE topic_id = ?;",topic_id];
    if ([historyResult next]) {
        return YES;
    } else {
        return NO;
    }

}

-(void)setTopicFavoriteState:(NSNumber *)topic_id withState:(BOOL)state
{
    FMResultSet *historyResult = [_db executeQuery:@"SELECT topic_id FROM favorite WHERE topic_id = ?;",topic_id];
    if ([historyResult next]) {
        if (state) {
            ;
        } else {
            [_db executeUpdate:@"DELETE FROM favorite WHERE topic_id = ?;", topic_id]; //topic_id in favorite table and state should be NO
        }
    } else {
        if (state) {
            [_db executeUpdate:@"INSERT INTO favorite (topic_id, favorite_time) VALUES (?,?);", topic_id, [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]]]; //topic_id not in favorite table and state should be YES
        } else {
            ;
        }
    }
}
#pragma mark - Upgrade
+ (void)migrateTracerToDatabase
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *tracerPath = [documentDirectory stringByAppendingPathComponent:@"RecentViewed_3_1.tracer"];
    NSFileManager *fm=[NSFileManager defaultManager];
    if ([fm fileExistsAtPath:tracerPath]) {
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"Stage1stReader.db"];
        FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
        if (![db open]) {
            NSLog(@"Could not open db.");
            return;
        }
        [db executeUpdate:@"CREATE TABLE IF NOT EXISTS threads(topic_id INTEGER PRIMARY KEY NOT NULL,title VARCHAR,reply_count INTEGER,field_id INTEGER,last_visit_time INTEGER, last_visit_page INTEGER,visit_count INTEGER);"];
        [db executeUpdate:@"CREATE TABLE IF NOT EXISTS favorite(topic_id INTEGER PRIMARY KEY NOT NULL,favorite_time INTEGER);"];
        [db executeUpdate:@"CREATE TABLE IF NOT EXISTS history(topic_id INTEGER PRIMARY KEY NOT NULL);"];
        
        
        NSData *data = [NSData dataWithContentsOfFile:tracerPath];
        NSMutableDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (!dict) {
            dict = [NSMutableDictionary dictionary];
        }
        for (id topic in [dict allValues]) {
            if (![topic respondsToSelector:@selector(topicID)]) {
                continue;
            }
            if (![topic respondsToSelector:@selector(title)]) {
                continue;
            }
            if (![topic respondsToSelector:@selector(replyCount)]) {
                continue;
            }
            if (![topic respondsToSelector:@selector(fID)]) {
                continue;
            }
            if (![topic respondsToSelector:@selector(lastViewedDate)]) {
                continue;
            }
            if (![topic respondsToSelector:@selector(lastViewedPage)]) {
                continue;
            }
            NSLog(@"%@",[topic topicID]);
            NSNumber *topicID = [topic topicID];
            NSString *title = [topic title];
            NSNumber *replyCount = [topic replyCount];
            NSNumber *fID = [topic fID];
            NSNumber *lastViewedDate = [NSNumber numberWithDouble:[[topic lastViewedDate] timeIntervalSince1970]];
            NSNumber *lastViewedPage = [topic lastViewedPage];
            FMResultSet *result = [db executeQuery:@"SELECT * FROM threads WHERE topic_id = ?;", topicID];
            if ([result next]) {
                ;
            } else {
                [db executeUpdate:@"INSERT INTO threads (topic_id, title, reply_count, field_id, last_visit_time, last_visit_page, visit_count) VALUES (?,?,?,?,?,?,?);",
                 topicID, title, replyCount, fID, lastViewedDate, lastViewedPage, [NSNumber numberWithInt:1]];
                NSLog(@"One Topic add to Database");
            }
            FMResultSet *historyResult = [db executeQuery:@"SELECT * FROM history WHERE topic_id = ?;", topicID];
            if ([historyResult next]) {
                ;
            } else {
                [db executeUpdate:@"INSERT INTO history (topic_id) VALUES (?);", topicID];
                NSLog(@"One Topic add to History");
            }
            
        }
        [db close];
        [fm removeItemAtPath:tracerPath error:nil];
    }
}

+ (void)upgradeDatabase
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"Stage1stReader.db"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
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
