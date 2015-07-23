#import "mantle.h"
#import "S1PersistentStack.h"
#import "S1Topic.h"

@interface S1PersistentStack ()

@property (nonatomic,strong,readwrite) NSManagedObjectContext* managedObjectContext;
@property (nonatomic,strong) NSURL* modelURL;
@property (nonatomic,strong) NSURL* storeURL;

@end

@implementation S1PersistentStack

- (id)initWithStoreURL:(NSURL*)storeURL modelURL:(NSURL*)modelURL 
{
    self = [super init];
    if (self) {
        self.storeURL = storeURL;
        self.modelURL = modelURL;
        [self setupManagedObjectContext];
    }
    return self;
}

- (void)setupManagedObjectContext
{
    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    self.managedObjectContext.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    
    
    __weak NSPersistentStoreCoordinator *psc = self.managedObjectContext.persistentStoreCoordinator;
    
    // iCloud notification subscriptions
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storesWillChange:) name:NSPersistentStoreCoordinatorStoresWillChangeNotification object:psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storesDidChange:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(persistentStoreDidImportUbiquitousContentChanges:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    NSError* error;
    // the only difference in this call that makes the store an iCloud enabled store
    // is the NSPersistentStoreUbiquitousContentNameKey in options. I use "iCloudStore"
    // but you can use what you like. For a non-iCloud enabled store, I pass "nil" for options.

    // Note that the store URL is the same regardless of whether you're using iCloud or not.
    // If you create a non-iCloud enabled store, it will be created in the App's Documents directory.
    // An iCloud enabled store will be created below a directory called CoreDataUbiquitySupport
    // in your App's Documents directory
    [self.managedObjectContext.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                       configuration:nil
                                                                                 URL:self.storeURL
                                                                             options:@{ NSPersistentStoreUbiquitousContentNameKey : @"iCloudStore" }
                                                                               error:&error];
    NSURL *containerURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:@"iCloud.com.ain.Stage1st"];
    if (containerURL != nil) {
        NSLog(@"success:%@",containerURL);
    } else {
        NSLog(@"URL=nil");
    }
    
    if (error) {
        NSLog(@"error: %@", error);
    }
}

- (NSManagedObjectModel*)managedObjectModel
{
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];
}

#pragma mark - Notifications
// Subscribe to NSPersistentStoreDidImportUbiquitousContentChangesNotification
- (void)persistentStoreDidImportUbiquitousContentChanges:(NSNotification*)note
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"%@", note.userInfo.description);
    
    NSManagedObjectContext *moc = self.managedObjectContext;
    [moc performBlock:^{
        [moc mergeChangesFromContextDidSaveNotification:note];
        
        // you may want to post a notification here so that which ever part of your app
        // needs to can react appropriately to what was merged. 
        // An exmaple of how to iterate over what was merged follows, although I wouldn't
        // recommend doing it here. Better handle it in a delegate or use notifications.
        // Note that the notification contains NSManagedObjectIDs
        // and not NSManagedObjects.
        NSDictionary *changes = note.userInfo;
        NSMutableSet *allChanges = [NSMutableSet new];
        [allChanges unionSet:changes[NSInsertedObjectsKey]];
        [allChanges unionSet:changes[NSUpdatedObjectsKey]];
        [allChanges unionSet:changes[NSDeletedObjectsKey]];
        
        for (NSManagedObjectID *objID in allChanges) {
            NSLog(@"%@", objID);
            // do whatever you need to with the NSManagedObjectID
            // you can retrieve the object from with [moc objectWithID:objID]
        }

    }];
}

// Subscribe to NSPersistentStoreCoordinatorStoresWillChangeNotification
// most likely to be called if the user enables / disables iCloud 
// (either globally, or just for your app) or if the user changes
// iCloud accounts.
- (void)storesWillChange:(NSNotification *)note {
    NSLog(@"store will change called");
    NSManagedObjectContext *moc = self.managedObjectContext;
    [moc performBlockAndWait:^{
        NSError *error = nil;
        if ([moc hasChanges]) {
            [moc save:&error];
        }
        
        [moc reset];
    }];
    
    // now reset your UI to be prepared for a totally different
    // set of data (eg, popToRootViewControllerAnimated:)
    // but don't load any new data yet.
}

// Subscribe to NSPersistentStoreCoordinatorStoresDidChangeNotification
- (void)storesDidChange:(NSNotification *)note {
    NSLog(@"store did change called");
    // here is when you can refresh your UI and
    // load new data from the new store
}

- (void)synchronize {
    NSLog(@"Synchronize");
    [self.managedObjectContext save:NULL];
}

#pragma mark - Backend Protocol
- (void)hasViewed:(S1Topic *)topic {
    NSError *error;
    [MTLManagedObjectAdapter managedObjectFromModel:topic insertingIntoContext:self.managedObjectContext error:&error];
    if (error) {
        NSLog(@"Mantle Error: %@", error);
    }
    NSLog(@"Topic Traced: %@", topic);
    
}

- (void)removeTopicFromHistory:(NSNumber *)topicID {
    
}

- (NSManagedObject *)presistentedManagedObjectForID:(NSNumber *)topicID {
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Topic"];
    request.predicate = [NSPredicate predicateWithFormat:@"topicID = %@", topicID];
    NSArray *results = [self.managedObjectContext executeFetchRequest:request error:nil];
    return [results lastObject];
}

- (S1Topic *)presistentedTopicByID:(NSNumber *)topicID {
    NSManagedObject * managedTopicObject = [self presistentedManagedObjectForID:topicID];
    if (managedTopicObject) {
        S1Topic *topic = [MTLManagedObjectAdapter modelOfClass:[S1Topic class] fromManagedObject:managedTopicObject error:nil];
        NSLog(@"Get Presistented Topic:%@", topic.topicID);
        return topic;
    } else {
        return nil;
    }
    
}

- (NSMutableArray *)historyObjectsWithLeftCallback:(void (^)(NSMutableArray *))leftTopicsHandler
{
    NSError *error;
    NSMutableArray *historyTopics = [[NSMutableArray alloc] init];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Topic"];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastViewedDate" ascending:NO];
    request.sortDescriptors = @[sortDescriptor];
    NSArray *results = [self.managedObjectContext executeFetchRequest:request error:nil];
    for (NSManagedObject *managedTopicObject in results) {
        S1Topic *topic = [MTLManagedObjectAdapter modelOfClass:[S1Topic class] fromManagedObject:managedTopicObject error:&error];
        if (topic) {
            [historyTopics addObject:topic];
        } else {
            NSLog(@"Error: %@", error);
        }
    }
    return historyTopics;
}

- (NSMutableArray *)favoritedObjects
{
    NSMutableArray *favoriteTopics = [[NSMutableArray alloc] init];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Topic"];
    request.predicate = [NSPredicate predicateWithFormat:@"favorite = TRUE"];
    NSArray *results = [self.managedObjectContext executeFetchRequest:request error:nil];
    for (NSManagedObject *managedTopicObject in results) {
        S1Topic *topic = [MTLManagedObjectAdapter modelOfClass:[S1Topic class] fromManagedObject:managedTopicObject error:nil];
        [favoriteTopics addObject:topic];
    }
    NSLog(@"Favorite count: %lu",(unsigned long)[favoriteTopics count]);
    return favoriteTopics;
}

- (BOOL)topicIsFavorited:(NSNumber *)topicID {
    return NO;
}

- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state {
    NSManagedObject * managedTopicObject = [self presistentedManagedObjectForID:topicID];
    if (managedTopicObject) {
        [managedTopicObject setValue:[NSNumber numberWithBool:state] forKey:@"favorite"];
    } else {
        NSLog(@"Error: setTopicFavoriteState can not find target topic:%@", topicID);
    }
    
}

#pragma mark - Sync

- (void)mergeObjects:(NSArray *)managedObjectArray {
    NSManagedObjectContext *mergeObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    mergeObjectContext.persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
    mergeObjectContext.mergePolicy = [[NSMergePolicy alloc] init];
    
}

@end