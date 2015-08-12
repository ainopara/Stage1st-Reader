//
//  S1CacheDatabaseManager.m
//  Stage1st
//
//  Created by Zheng Li on 8/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

#import "S1CacheDatabaseManager.h"
#import "YapDatabase.h"


NSString *const Collection_TopicFloors = @"topicFloors";
NSString *const Collection_Headers = @"headers";


@interface S1CacheDatabaseManager ()

@property (strong, nonatomic) YapDatabase *cacheDatabase;
@property (strong, nonatomic) YapDatabaseConnection *cacheConnection;
@property (strong, nonatomic) YapDatabaseConnection *backgroundCacheConnection;

@end

@implementation S1CacheDatabaseManager

-(instancetype)init {
    self = [super init];
    _cacheDatabase = [[YapDatabase alloc] initWithPath:self.cacheURL.absoluteString];
    _cacheConnection = [_cacheDatabase newConnection];
    _backgroundCacheConnection = [_cacheDatabase newConnection];
    return self;
}

+ (S1CacheDatabaseManager *)sharedInstance
{
    static S1CacheDatabaseManager *cacheDatabaseManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheDatabaseManager = [[S1CacheDatabaseManager alloc] init];
    });
    return cacheDatabaseManager;
}

#pragma mark - Floor Cache

- (NSURL*)cacheURL
{
    NSURL* documentsDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    return [documentsDirectory URLByAppendingPathComponent:@"Cache.sqlite"];
}

- (void)setCacheValue:(id)value forKey:(NSString *)key inCollection:(NSString *)collection {
    [self.backgroundCacheConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
        [transaction setObject:value forKey:key inCollection:collection];
    }];
}

- (id)cacheValueForKey:(NSString *)key inCollection:(NSString *)collection {
    __block NSArray *result = nil;
    [self.cacheConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        result = [transaction objectForKey:key inCollection:collection];
    }];
    return result;
}

- (BOOL)hasCacheForKey:(NSString *)key inCollection:(NSString *)collection {
    __block BOOL hasCache = NO;
    [self.cacheConnection readWithBlock:^(YapDatabaseReadTransaction * __nonnull transaction) {
        hasCache = [transaction hasObjectForKey:key inCollection:collection];
    }];
    //NSLog(@"%@, %d",key, hasCache);
    return hasCache;
}

- (void)removeCacheForKey:(NSString *)key inCollection:(NSString *)collection {
    [self.backgroundCacheConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * __nonnull transaction) {
        [transaction removeObjectForKey:key inCollection:collection];
    }];
}
@end
