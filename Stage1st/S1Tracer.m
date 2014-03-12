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
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"Stage1stReader.db"];
    _db = [FMDatabase databaseWithPath:dbPath];
    if (![_db open]) {
        NSLog(@"Could not open db.");
        return nil;
    }
    [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS threads(topic_id INTEGER PRIMARY KEY NOT NULL,title VARCHAR,reply_count INTEGER,field_id INTEGER,last_visit_time INTEGER, last_visit_page INTEGER,visit_count INTEGER);"];
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

- (void)hasViewed:(id)object
{
    [object setValue:[NSDate date] forKey:@"lastViewedDate"];
    
    S1Topic *topic = (S1Topic *)object;
    NSNumber *topicID = topic.topicID;
    NSString *title = topic.title;
    NSNumber *replyCount = topic.replyCount;
    NSNumber *fID = topic.fID;
    NSNumber *lastViewedDate = [NSNumber numberWithDouble:[topic.lastViewedDate timeIntervalSince1970]];
    NSNumber *lastViewedPage = topic.lastViewedPage;
    FMResultSet *result = [_db executeQuery:@"SELECT * FROM threads WHERE topic_id = ?;", topicID];
    if ([result next]) {
        NSNumber *visitCount = [[NSNumber alloc] initWithInt:[_db intForQuery:@"SELECT visit_count FROM threads WHERE topic_id = ?;", topicID] + 1];
        [_db executeUpdate:@"UPDATE threads SET title = ?,reply_count = ?,field_id = ?,last_visit_time = ?,last_visit_page = ?,visit_count = ? WHERE topic_id = ?;",
         title, replyCount, fID, lastViewedDate, lastViewedPage, visitCount, topicID];
    } else {
        [_db executeUpdate:@"INSERT INTO threads (topic_id, title, reply_count, field_id, last_visit_time, last_visit_page, visit_count) VALUES (?,?,?,?,?,?,?);",
         topicID, title, replyCount, fID, lastViewedDate, lastViewedPage, [NSNumber numberWithInt:1]];
    }
    FMResultSet *historyResult = [_db executeQuery:@"SELECT * FROM history WHERE topic_id = ?;", topicID];
    if ([historyResult next]) {
        ;
    } else {
        [_db executeUpdate:@"INSERT INTO history (topic_id) VALUES (?);", topicID];
    }
    
    NSLog(@"Tracer has traced:%@", object);
}

- (void)removeTopicFromHistory:(NSNumber *)topic_id
{
    FMResultSet *historyResult = [_db executeQuery:@"SELECT topic_id FROM history WHERE topic_id = ?;",topic_id];
    if ([historyResult next]) {
        [_db executeUpdate:@"DELETE FROM history WHERE topic_id = ?;", topic_id];
    }
}

- (NSArray *)historyObjects
{
    NSMutableArray *historyTopics = [NSMutableArray array];
    FMResultSet *historyResult = [_db executeQuery:@"SELECT threads.topic_id, threads.title, threads.reply_count, threads.field_id, threads.last_visit_page, threads.visit_count FROM history INNER JOIN threads ON history.topic_id = threads.topic_id ORDER BY threads.last_visit_time DESC;"];
    while ([historyResult next]) {
        //NSLog(@"%@", [historyResult stringForColumn:@"title"]);
        S1Topic *historyTopic = [[S1Topic alloc] init];
        [historyTopic setTopicID:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"topic_id"]]];
        [historyTopic setTitle:[historyResult stringForColumn:@"title"]];
        [historyTopic setReplyCount:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"reply_count"]]];
        [historyTopic setFID:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"field_id"]]];
        [historyTopic setLastViewedPage:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"last_visit_page"]]];
        [historyTopic setVisitCount:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"visit_count"]]];
        [historyTopic setFavorite:[NSNumber numberWithBool:[self topicIsFavorited:historyTopic.topicID]]];
        [historyTopics addObject:historyTopic];
    }
    NSLog(@"History count: %lu",(unsigned long)[historyTopics count]);
    return historyTopics;
}

- (NSArray *)favoritedObjects
{
    NSMutableArray *favoriteTopics = [NSMutableArray array];
    FMResultSet *historyResult = [_db executeQuery:@"SELECT threads.topic_id, threads.title, threads.reply_count, threads.field_id, threads.last_visit_page, threads.visit_count FROM favorite INNER JOIN threads ON favorite.topic_id = threads.topic_id ORDER BY favorite.favorite_time DESC;"];
    while ([historyResult next]) {
        //NSLog(@"%@", [historyResult stringForColumn:@"title"]);
        S1Topic *favoriteTopic = [[S1Topic alloc] init];
        [favoriteTopic setTopicID:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"topic_id"]]];
        [favoriteTopic setTitle:[historyResult stringForColumn:@"title"]];
        [favoriteTopic setReplyCount:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"reply_count"]]];
        [favoriteTopic setFID:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"field_id"]]];
        [favoriteTopic setLastViewedPage:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"last_visit_page"]]];
        [favoriteTopic setVisitCount:[NSNumber numberWithLongLong:[historyResult longLongIntForColumn:@"visit_count"]]];
        [favoriteTopic setFavorite:[NSNumber numberWithBool:[self topicIsFavorited:favoriteTopic.topicID]]];
        [favoriteTopics addObject:favoriteTopic];
    }
    NSLog(@"Favorite count: %lu",(unsigned long)[favoriteTopics count]);
    return favoriteTopics;
}

- (id)tracedTopic:(NSNumber *)topicID
{
    FMResultSet *result = [_db executeQuery:@"SELECT last_visit_page,visit_count FROM threads WHERE topic_id = ?;",topicID];
    if ([result next]) {
        S1Topic *topic = [[S1Topic alloc] init];
        [topic setLastViewedPage:[NSNumber numberWithLongLong:[result longLongIntForColumn:@"last_visit_page"]]];
        [topic setVisitCount:[NSNumber numberWithLongLong:[result longLongIntForColumn:@"visit_count"]]];
        [topic setFavorite:[NSNumber numberWithBool:[self topicIsFavorited:topic.topicID]]];
        return topic;
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
            if (![topic 	respondsToSelector:@selector(topicID)]) {
                continue;
            }
            if (![topic 	respondsToSelector:@selector(title)]) {
                continue;
            }
            if (![topic 	respondsToSelector:@selector(replyCount)]) {
                continue;
            }
            if (![topic 	respondsToSelector:@selector(fID)]) {
                continue;
            }
            if (![topic 	respondsToSelector:@selector(lastViewedDate)]) {
                continue;
            }
            if (![topic 	respondsToSelector:@selector(lastViewedPage)]) {
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

@end
