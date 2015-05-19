@import Foundation;
@import CoreData;

@class S1Topic;

@interface PersistentStack : NSObject

- (id)initWithStoreURL:(NSURL *)storeURL modelURL:(NSURL *)modelURL;

- (void)hasViewed:(S1Topic *)topic;
- (void)removeTopicByID:(NSNumber *)topicID;

- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state;

- (S1Topic *)presistentedTopicByID:(NSNumber *)topicID;

- (NSMutableArray *)historyObjectsWithLeftCallback:(void (^)(NSMutableArray *))leftTopicsHandler;
- (NSMutableArray *)favoritedObjects;

@property (nonatomic,strong,readonly) NSManagedObjectContext *managedObjectContext;

- (void)mergeObjects:(NSArray *)managedObjectArray;

@end