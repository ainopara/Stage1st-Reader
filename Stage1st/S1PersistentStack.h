@import Foundation;
@import CoreData;
#import "S1DataCenter.h"

@class S1Topic;

@interface S1PersistentStack : NSObject<S1Backend>

- (id)initWithStoreURL:(NSURL *)storeURL modelURL:(NSURL *)modelURL;

@property (nonatomic,strong,readonly) NSManagedObjectContext *managedObjectContext;

- (void)mergeObjects:(NSArray *)managedObjectArray;

@end