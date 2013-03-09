//
//  S1Tracer.m
//  Stage1st
//
//  Created by Suen Gabriel on 3/3/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Tracer.h"

NSTimeInterval const kDefaultDuration = 259200; // 3 days

@implementation S1Tracer {
    NSString *_tracerName;
    NSMutableDictionary *_tracerDictionary;
}

- (id)initWithTracerName:(NSString *)name
{
    self = [super init];
    if (!self) return nil;
    
    _tracerName = [name copy];
    _tracerDictionary = [self tracerDictionaryFromPersistence];
    
    if (!_tracerDictionary) {
        _tracerDictionary = [NSMutableDictionary dictionary];
    }
    
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
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillTerminateNotification object:nil];
}

- (void)hasViewed:(id)object
{
    [object setValue:[NSDate date] forKey:self.timeStampKey];
    [_tracerDictionary setObject:object forKey:[object valueForKey:self.identifyKey]];
    NSLog(@"Tracer has traced:%@", object);
}

- (NSArray *)recentViewedObjects
{
    NSArray *all = [_tracerDictionary allValues];
    NSLog(@"%@", all);
    return [[[all sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDate *date1 = [obj1 valueForKey:self.timeStampKey];
        NSDate *date2 = [obj2 valueForKey:self.timeStampKey];
        return [date1 compare:date2];
    }] reverseObjectEnumerator] allObjects];
}

- (id)objectInRecentForKey:(NSString *)key
{
    return _tracerDictionary[key];
}

#pragma mark - Archiver

- (void)synchronize
{
    [self purgeStaleItem];
    NSLog(@"Write to Disk: %@", [self tracerPath]);
    [NSKeyedArchiver archiveRootObject:_tracerDictionary toFile:[self tracerPath]];
}


- (NSMutableDictionary *)tracerDictionaryFromPersistence
{
    NSString *path = [self tracerPath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSMutableDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return dict;    
}


- (NSString *)tracerPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *tracerDirectory = [paths objectAtIndex:0];
    return [tracerDirectory stringByAppendingPathComponent:_tracerName];
}

- (void)purgeStaleItem
{
    __block NSMutableArray *keysToRemove = [NSMutableArray array];
    [_tracerDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSDate *expireDate = [(NSDate *)[obj valueForKey:_timeStampKey] dateByAddingTimeInterval:kDefaultDuration];
        NSDate *now = [NSDate date];
        if ([[now earlierDate:expireDate] isEqualToDate:expireDate]) {
            NSLog(@"Purge Item:%@", obj);
            [keysToRemove addObject:key];
        }
    }];
    [_tracerDictionary removeObjectsForKeys:keysToRemove];
}



@end
