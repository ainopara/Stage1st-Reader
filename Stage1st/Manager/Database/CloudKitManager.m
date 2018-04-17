#import "CloudKitManager.h"
#import "DatabaseManager.h"
#import "S1AppDelegate.h"
#import "S1Topic.h"
#import <YapDatabase/YapDatabase.h>
#import <YapDatabase/YapDatabaseCloudKit.h>

#import <CloudKit/CloudKit.h>
#import <Reachability/Reachability.h>
#import <Crashlytics/Answers.h>

CloudKitManager *MyCloudKitManager;

static NSString *const Key_HasZone             = @"hasZone";
static NSString *const Key_HasZoneSubscription = @"hasZoneSubscription";
static NSString *const Key_ServerChangeToken   = @"serverChangeToken";
static NSString *const Key_CloudKitManagerVersion = @"CloudKitManagerVersion";

NSString *const YapDatabaseCloudKitUnhandledErrorOccurredNotification = @"S1YDBCK_UnhandledErrorOccurred";
NSString *const YapDatabaseCloudKitStateChangeNotification = @"S1YDBCK_StateChange";

@interface CloudKitManager ()

// Initial setup
@property (atomic, readwrite) BOOL needsUpgrade;
@property (atomic, readwrite) BOOL needsCreateZone;
@property (atomic, readwrite) BOOL needsCreateZoneSubscription;
@property (atomic, readwrite) BOOL needsFetchRecordChangesAfterAppLaunch;

// Error handling
@property (atomic, readwrite) BOOL needsResume;
@property (atomic, readwrite) BOOL needsFetchRecordChanges;
@property (atomic, readwrite) BOOL needsRefetchMissedRecordIDs;

@property (atomic, readwrite) BOOL lastSuccessfulFetchResultWasNoData;

@end


@implementation CloudKitManager
{
	YapDatabaseConnection *databaseConnection;
	
	dispatch_queue_t setupQueue;
	dispatch_queue_t fetchQueue;
	
	NSString *lastChangeSetUUID;
    NSUInteger currentVersion;
}

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		MyCloudKitManager = [[CloudKitManager alloc] init];
	});
}

+ (instancetype)sharedInstance
{
	return MyCloudKitManager;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Instance
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	NSAssert(MyCloudKitManager == nil, @"Must use sharedInstance singleton (global MyCloudKitManager)");
	
	if ((self = [super init]))
	{
		// We could create our own dedicated databaseConnection.
		// But our needs are pretty basic, so we're just going to use the generic background connection.
		databaseConnection = MyDatabaseManager.bgDatabaseConnection;
		
		setupQueue = dispatch_queue_create("CloudKitManager.setup", DISPATCH_QUEUE_SERIAL);
		fetchQueue = dispatch_queue_create("CloudKitManager.fetch", DISPATCH_QUEUE_SERIAL);
		
		dispatch_suspend(setupQueue);
		dispatch_suspend(fetchQueue);

        currentVersion = 1;

        self.state = CKManagerStateInit;
        self.needsUpgrade = YES;
		self.needsCreateZone = YES;
		self.needsCreateZoneSubscription = YES;
		self.needsFetchRecordChangesAfterAppLaunch = YES;

		[self configureCloudKit];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(applicationDidEnterBackground:)
		                                             name:UIApplicationDidEnterBackgroundNotification
		                                           object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(applicationWillEnterForeground:)
		                                             name:UIApplicationWillEnterForegroundNotification
		                                           object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(cloudKitInFlightChangeSetChanged:)
		                                             name:YapDatabaseCloudKitInFlightChangeSetChangedNotification
		                                           object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(reachabilityChanged:)
		                                             name:kReachabilityChangedNotification
		                                           object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cloudKitRegisterFinish)
                                                     name:@"S1YapDatabaseCloudKitRegisterFinish"
                                                   object:nil];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method should only be called once.
 * Thereafter, call contineCloudKitFlow.
**/
- (void)configureCloudKit
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	// Set initial values
	// (by checking database to see if we've flagged them as complete from previous app run)
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSUInteger databaseCloudKitManagerVersion = 0;
        if ([transaction hasObjectForKey:Key_CloudKitManagerVersion inCollection:Collection_CloudKit]) {
            databaseCloudKitManagerVersion = [[transaction objectForKey:Key_CloudKitManagerVersion inCollection:Collection_CloudKit] unsignedIntegerValue];
        }
        if (databaseCloudKitManagerVersion >= self->currentVersion) {
            self.needsUpgrade = NO;
            [MyDatabaseManager.cloudKitExtension resume];
        }
		if ([transaction hasObjectForKey:Key_HasZone inCollection:Collection_CloudKit])
		{
			self.needsCreateZone = NO;
			[MyDatabaseManager.cloudKitExtension resume];
		}
		if ([transaction hasObjectForKey:Key_HasZoneSubscription inCollection:Collection_CloudKit])
		{
			self.needsCreateZoneSubscription = NO;
			[MyDatabaseManager.cloudKitExtension resume];
		}
	}];
	
	[self continueCloudKitFlow];
}

- (void)continueCloudKitFlow
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);

    if (self.needsUpgrade)
    {
        [self upgradeManager];
    }
    else if (self.needsCreateZone)
	{
		[self createZone];
	}
	else if (self.needsCreateZoneSubscription)
	{
		[self createZoneSubscription];
	}
	else if (self.needsFetchRecordChangesAfterAppLaunch)
	{
		[self fetchRecordChangesAfterAppLaunch];
	}
	else
	{
		// Order matters here.
		// We may be in one of 3 states:
		//
		// 1. YDBCK is suspended because we need to refetch stuff we screwed up
		// 2. YDBCK is suspended because we need to fetch record changes (and merge with our local CKRecords)
		// 3. YDBCK is suspended because of a network failure
		// 4. YDBCK is not suspended
		//
		// In the case of #1, it doesn't make sense to resume YDBCK until we've refetched the records we
		// didn't properly merge last time (due to a bug in your YapDatabaseCloudKitMergeBlock).
		// So case #3 needs to be checked before #2.
		//
		// In the case of #2, it doesn't make sense to resume YDBCK until we've handled
		// fetching the latest changes from the server.
		// So case #2 needs to be checked before #3.
		
		if (self.needsRefetchMissedRecordIDs)
		{
			[self _refetchMissedRecordIDs];
		}
		else if (self.needsFetchRecordChanges)
		{
			[self _fetchRecordChanges];
		}
		else if (self.needsResume)
		{
			self.needsResume = NO;
			[MyDatabaseManager.cloudKitExtension resume];
		}
	}
}

- (void)warnAboutAccount
{
	dispatch_block_t block = ^{
	
		NSString *title = @"You're not signed into iCloud.";
		NSString *message = @"You must be signed into iCloud for syncing to work.";

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"Oops"
                                                            style:UIAlertActionStyleDefault
                                                          handler:NULL]];

        [[[MyAppDelegate window] rootViewController] presentViewController:alertController animated:YES completion:NULL];
	};
	
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)warnAboutFeatures
{
	dispatch_block_t block = ^{
		
		NSString *title = @"Stage1st Reader doesn't support switching iCloud accounts.";
		NSString *message = @"Maybe in future.";
		
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:NULL]];

        [[[MyAppDelegate window] rootViewController] presentViewController:alertController animated:YES completion:NULL];
	};
	
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)prepareForUnregister {
    [databaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeObjectForKey:Key_ServerChangeToken inCollection:Collection_CloudKit];
        [transaction removeObjectForKey:Key_HasZone inCollection:Collection_CloudKit];
        [transaction removeObjectForKey:Key_HasZoneSubscription inCollection:Collection_CloudKit];
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark App Launch
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)upgradeManager
{
    dispatch_async(setupQueue, ^{ @autoreleasepool {
        // Suspend the queue.
        // We will resume it upon completion of the operation.
        // This ensures that there is only one outstanding operation at a time.
        dispatch_suspend(self->setupQueue);

        [self _upgradeManager];
    }});
}

- (void)_upgradeManager
{
    if (self.needsUpgrade == NO) {
        DDLogError(@"[CloudKitManager] error state: no more needs upgrade database but ever need");
        dispatch_resume(setupQueue);
        return;
    }
    __block NSUInteger databaseCloudKitManagerVersion = 0;
    [databaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        if ([transaction hasObjectForKey:Key_CloudKitManagerVersion inCollection:Collection_CloudKit]) {
            databaseCloudKitManagerVersion = [[transaction objectForKey:Key_CloudKitManagerVersion inCollection:Collection_CloudKit] unsignedIntegerValue];
        }
    }];

    if (databaseCloudKitManagerVersion < 1) {
        [databaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
            [transaction removeObjectForKey:Key_HasZoneSubscription inCollection:Collection_CloudKit];
        }];
        if (self.needsCreateZoneSubscription == NO) {
            self.needsCreateZoneSubscription = YES;
            [MyDatabaseManager.cloudKitExtension suspend];
        }
    }
    // Add other upgrade code here.

    self.needsUpgrade = NO;

    // Decrement suspend count.
    [MyDatabaseManager.cloudKitExtension resume];

    // Update database version
    [databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction setObject:@(self->currentVersion) forKey:Key_CloudKitManagerVersion inCollection:Collection_CloudKit];
    }];

    // Continue setup
    [self continueCloudKitFlow];

    dispatch_resume(setupQueue);
}


- (void)createZone
{
	dispatch_async(setupQueue, ^{ @autoreleasepool {
        self.state = CKManagerStateSetup;
		// Suspend the queue.
		// We will resume it upon completion of the operation.
		// This ensures that there is only one outstanding operation at a time.
        dispatch_suspend(self->setupQueue);
		
		[self _createZone];
	}});
}

- (void)_createZone
{
	if (self.needsCreateZone == NO)
	{
        DDLogError(@"[CloudKitManager] error state: no more needs create zone but ever need");
		dispatch_resume(setupQueue);
		return;
	}
	
	CKRecordZone *recordZone = [[CKRecordZone alloc] initWithZoneName:CloudKitZoneName];
	
	CKModifyRecordZonesOperation *modifyRecordZonesOperation =
	  [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[ recordZone ]
	                                            recordZoneIDsToDelete:nil];
	
	modifyRecordZonesOperation.modifyRecordZonesCompletionBlock =
	^(NSArray *savedRecordZones, NSArray *deletedRecordZoneIDs, NSError *operationError)
	{
		if (operationError)
		{
			DDLogWarn(@"Error creating zone: %@", operationError);
			
			BOOL isNotAuthenticatedError = NO;
			
			NSInteger ckErrorCode = operationError.code;
			if (ckErrorCode == CKErrorNotAuthenticated)
			{
				isNotAuthenticatedError = YES;
			}
			else if (ckErrorCode == CKErrorPartialFailure)
			{
				NSDictionary *partialErrorsByZone = [operationError.userInfo objectForKey:CKPartialErrorsByItemIDKey];
				for (NSError *perZoneError in [partialErrorsByZone objectEnumerator])
				{
					ckErrorCode = perZoneError.code;
					if (ckErrorCode == CKErrorNotAuthenticated)
					{
						isNotAuthenticatedError = YES;
					}
				}
			}
			
			if (isNotAuthenticatedError)
			{
				[self warnAboutAccount];
			}
		}
		else
		{
			DDLogDebug(@"Successfully created zones: %@", savedRecordZones);
			
			// Create zone complete.
			self.needsCreateZone = NO;
			
			// Decrement suspend count.
			[MyDatabaseManager.cloudKitExtension resume];
			
			// Put flag in database so we know we can skip this operation next time
            [self->databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				[transaction setObject:@(YES) forKey:Key_HasZone inCollection:Collection_CloudKit];
			}];
			
			// Continue setup
			[self continueCloudKitFlow];
		}
		
        dispatch_resume(self->setupQueue);
	};
		
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modifyRecordZonesOperation];
}

- (void)createZoneSubscription
{
	dispatch_async(setupQueue, ^{ @autoreleasepool {
		self.state = CKManagerStateSetup;
		// Suspend the queue.
		// We will resume it upon completion of the operation.
		// This ensures that there is only one outstanding operation at a time.
        dispatch_suspend(self->setupQueue);
		
		[self _createZoneSubscription];
	}});
}

- (void)_createZoneSubscription
{
	if (self.needsCreateZoneSubscription == NO)
	{
        DDLogError(@"[CloudKitManager] error state: no more needs create zone subscription but ever need");
		dispatch_resume(setupQueue);
		return;
	}
	
	CKRecordZoneID *recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:CloudKitZoneName ownerName:CKCurrentUserDefaultName];
    CKRecordZoneSubscription *subscription = [[CKRecordZoneSubscription alloc] initWithZoneID:recordZoneID subscriptionID:CloudKitZoneName];
    CKNotificationInfo *notificationInfo = [[CKNotificationInfo alloc] init];
    notificationInfo.shouldSendContentAvailable = YES;
    subscription.notificationInfo = notificationInfo;
	
	CKModifySubscriptionsOperation *modifySubscriptionsOperation =
	  [[CKModifySubscriptionsOperation alloc] initWithSubscriptionsToSave:@[ subscription ]
	                                              subscriptionIDsToDelete:nil];
	
	modifySubscriptionsOperation.modifySubscriptionsCompletionBlock =
	^(NSArray *savedSubscriptions, NSArray *deletedSubscriptionIDs, NSError *operationError)
	{
		if (operationError)
		{
			DDLogWarn(@"Error creating subscription: %@", operationError);
		}
		else
		{
			DDLogDebug(@"Successfully created subscription: %@", savedSubscriptions);
			
			// Create zone subscription complete.
			self.needsCreateZoneSubscription = NO;
			
			// Decrement suspend count.
			[MyDatabaseManager.cloudKitExtension resume];
			
			// Put flag in database so we know we can skip this operation next time
            [self->databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				[transaction setObject:@(YES) forKey:Key_HasZoneSubscription inCollection:Collection_CloudKit];
                [transaction setObject:@(1) forKey:Key_CloudKitManagerVersion inCollection:Collection_CloudKit];
			}];
			
			// Continue setup
			[self continueCloudKitFlow];
		}
		
        dispatch_resume(self->setupQueue);
	};
	
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modifySubscriptionsOperation];
}

/**
 * This method is invoked after the CKRecordZone & CKSubscription are setup.
**/
- (void)fetchRecordChangesAfterAppLaunch
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	if (self.needsFetchRecordChangesAfterAppLaunch == NO) return;
	
	[self fetchRecordChangesWithCompletionHandler:^(UIBackgroundFetchResult result, BOOL moreComing) {
		// Note: This handler may be called multiple times.
		if ((result != UIBackgroundFetchResultFailed) && !moreComing)
		{
			if (self.needsFetchRecordChangesAfterAppLaunch)
			{
				// Initial fetchRecordChanges operation complete.
				self.needsFetchRecordChangesAfterAppLaunch = NO;
				
				// Decrement suspend count.
				[MyDatabaseManager.cloudKitExtension resume];
			}
		}
	}];
}


#pragma mark Fetching


/**
 * This method uses CKFetchRecordChangesOperation to fetch changes.
 * It continues fetching until its reported that we're caught up.
 *
 * This method is invoked once automatically, when the CloudKitManager is initialized.
 * After that, one should invoke it anytime a corresponding push notification is received.
**/
- (void)fetchRecordChangesWithCompletionHandler:
        (void (^)(UIBackgroundFetchResult result, BOOL moreComing))completionHandler
{
    __weak __typeof__(self) weakSelf = self;
	dispatch_async(fetchQueue, ^{ @autoreleasepool {
        __strong __typeof__(self) strongSelf = weakSelf;
        strongSelf.state = CKManagerStateFetching;
		// Suspend the queue.
		// We will resume it upon completion of the operation.
		// This ensures that there is only one outstanding fetchRecordsOperation at a time.
        dispatch_suspend(self->fetchQueue);
		
        [strongSelf _fetchRecordChangesWithCompletionHandler:^(UIBackgroundFetchResult result, BOOL moreComing){
            if (strongSelf.state == CKManagerStateFetching && result != UIBackgroundFetchResultFailed && moreComing == NO) {
                strongSelf.state = CKManagerStateReady;
            }
            completionHandler(result, moreComing);
        }];
	}});
}

- (void)_fetchRecordChangesWithCompletionHandler:(void (^)(UIBackgroundFetchResult result, BOOL moreComing))completionHandler
{
	__block CKServerChangeToken *prevServerChangeToken = nil;
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		prevServerChangeToken = [transaction objectForKey:Key_ServerChangeToken inCollection:Collection_CloudKit];
		
	} completionBlock:^{
		
		[self _fetchRecordChangesWithPrevServerChangeToken:prevServerChangeToken
		                                 completionHandler:completionHandler];
	}];
}

- (void)_fetchRecordChangesWithPrevServerChangeToken:(CKServerChangeToken *)prevServerChangeToken
                                   completionHandler:(void (^)(UIBackgroundFetchResult result, BOOL moreComing))completionHandler
{
    CKRecordZoneID *recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:CloudKitZoneName ownerName:CKCurrentUserDefaultName];
    CKFetchRecordZoneChangesOptions *fetchOptions = [[CKFetchRecordZoneChangesOptions alloc] init];
    fetchOptions.previousServerChangeToken = prevServerChangeToken;
	
    CKFetchRecordZoneChangesOperation *operation = [[CKFetchRecordZoneChangesOperation alloc] initWithRecordZoneIDs:@[ recordZoneID ]
                                                                                              optionsByRecordZoneID:@{ recordZoneID: fetchOptions }];
	
	__block NSMutableArray *deletedRecordIDs = nil;
	__block NSMutableArray *changedRecords = nil;

    operation.recordWithIDWasDeletedBlock = ^(CKRecordID * _Nonnull recordID, NSString * _Nonnull recordType) {
        if (deletedRecordIDs == nil) {
            deletedRecordIDs = [[NSMutableArray alloc] init];
        }
		
		[deletedRecordIDs addObject:recordID];
	};

    operation.recordChangedBlock = ^(CKRecord * _Nonnull record) {
        if (changedRecords == nil) {
            changedRecords = [[NSMutableArray alloc] init];
        }
		
		[changedRecords addObject:record];
	};
	
    __weak __typeof__(self) weakSelf = self;
    operation.recordZoneFetchCompletionBlock = ^(CKRecordZoneID * _Nonnull recordZoneID, CKServerChangeToken * _Nullable serverChangeToken, NSData * _Nullable clientChangeTokenData, BOOL moreComing, NSError * _Nullable recordZoneError) {
        __strong __typeof__(self) strongSelf = weakSelf;
		DDLogDebug(@"CKFetchRecordChangesOperation.fetchRecordChangesCompletionBlock");
		
		DDLogVerbose(@"CKFetchRecordChangesOperation: serverChangeToken: %@", serverChangeToken);
		DDLogVerbose(@"CKFetchRecordChangesOperation: clientChangeTokenData: %@", clientChangeTokenData);

        if (recordZoneError) {
            // I've seen:
            //
            // - CKErrorNotAuthenticated - "CloudKit access was denied by user settings"; Retry after 3.0 seconds

            DDLogInfo(@"CKFetchRecordChangesOperation: operationError: %@", recordZoneError);
            if (recordZoneError.domain != CKErrorDomain) {
                if (completionHandler) {
                    completionHandler(UIBackgroundFetchResultFailed, NO);
                }
                dispatch_resume(strongSelf->fetchQueue);
                return;
            }

            NSInteger ckErrorCode = recordZoneError.code;

            if (ckErrorCode == CKErrorChangeTokenExpired)
            {
                // CKErrorChangeTokenExpired:
                //   The previousServerChangeToken value is too old and the client must re-sync from scratch.
                [self->databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                    [transaction removeObjectForKey:Key_ServerChangeToken inCollection:Collection_CloudKit];
                } completionBlock:^{
                    if (completionHandler) {
                        completionHandler(UIBackgroundFetchResultFailed, NO);
                    }
                    dispatch_resume(strongSelf->fetchQueue);
                }];
                return;
            } else if (ckErrorCode == CKErrorZoneNotFound) {
                [strongSelf handleZoneNotFound];
            } else if (ckErrorCode == CKErrorUserDeletedZone) {
                [strongSelf handleUserDeletedZone];
            } else if (ckErrorCode == CKErrorRequestRateLimited) {

            } else {
                [strongSelf reportError:recordZoneError];
            }
            if (completionHandler) {
                completionHandler(UIBackgroundFetchResultFailed, NO);
            }
            dispatch_resume(strongSelf->fetchQueue);
            return;
        }
		
		// Edge Case:
		//
		// I've witnessed the following on a fresh app launch on the device (first run after install):
		// The first fetchRecordChanges returns:
		// - no deletedRecordIDs
		// - no changedRecords
		// - a serverChangeToken
		// - and moreComing == YES
		//
		// So, oddly enough, this results in (UIBackgroundFetchResultNoData, moreComing==YES).
		//
		// Which seems non-intuitive to me, but that's what we're getting from the server.
		// And, in fact, if we don't follow that up with another fetch,
		// then we fail to properly fetch what's on the server.
		
		BOOL hasChanges = NO;
        if (deletedRecordIDs.count > 0 || changedRecords.count > 0) {
            hasChanges = YES;
        }

        strongSelf.lastSuccessfulFetchResultWasNoData = (!hasChanges && !moreComing);

		if (!hasChanges && !moreComing)
		{
			DDLogDebug(@"CKFetchRecordChangesOperation: !hasChanges && !moreComing");
			
			// Just to be safe, we're going to go ahead and save the newServerChangeToken.
			//
			// By the way:
			// - The CKServerChangeToken class has no API
			// - Comparing two serverChangeToken's via isEqual doesn't work
			// - Archiving two serverChangeToken's into NSData, and comparing that doesn't work either
			
			[strongSelf->databaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				[transaction setObject:serverChangeToken
				                forKey:Key_ServerChangeToken
				          inCollection:Collection_CloudKit];
			}];
			
			if (completionHandler) {
				completionHandler(UIBackgroundFetchResultNoData, NO);
			}
			dispatch_resume(strongSelf->fetchQueue);
		}
		else // if (hasChanges || moreComing)
		{
			DDLogVerbose(@"CKFetchRecordChangesOperation: deletedRecordIDs: %@", deletedRecordIDs);
			DDLogVerbose(@"CKFetchRecordChangesOperation: changedRecords: %@", changedRecords);
			
			[strongSelf->databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				// Remove the items that were deleted (by another device)
				for (CKRecordID *recordID in deletedRecordIDs)
				{
					NSArray *collectionKeys =
					  [[transaction ext:Ext_CloudKit] collectionKeysForRecordID:recordID
					                                         databaseIdentifier:nil];
					
					for (YapCollectionKey *ck in collectionKeys)
					{
						// This MUST go FIRST
						[[transaction ext:Ext_CloudKit] detachRecordForKey:ck.key
						                                      inCollection:ck.collection
						                                 wasRemoteDeletion:YES
						                              shouldUploadDeletion:NO];
						
						// This MUST go SECOND
						[transaction removeObjectForKey:ck.key inCollection:ck.collection];
					}
				}
				
				// Update the items that were modified (by another device)
				for (CKRecord *record in changedRecords)
				{
					if (![record.recordType isEqualToString:@"topic"])
					{
						// Ignore unknown record types.
						// These are probably from a future version that this version doesn't support.
						continue;
					}
					
					NSString *recordChangeTag = nil;
					BOOL hasPendingModifications = NO;
					BOOL hasPendingDelete = NO;
					
					[[transaction ext:Ext_CloudKit] getRecordChangeTag:&recordChangeTag
					                           hasPendingModifications:&hasPendingModifications
					                                  hasPendingDelete:&hasPendingDelete
					                                       forRecordID:record.recordID
					                                databaseIdentifier:nil];
					
					if (recordChangeTag)
					{
						if ([recordChangeTag isEqualToString:record.recordChangeTag])
						{
							// We're the one who changed this record.
							// So we can quietly ignore it.
						}
						else
						{
							[[transaction ext:Ext_CloudKit] mergeRecord:record databaseIdentifier:nil];
						}
					}
					else if (hasPendingModifications)
					{
						// We're not actively managing this record anymore (we deleted/detached it).
						// But there are still previous modifications that are pending upload to server.
						// So this merge is required in order to keep everything running properly (no infinite loops).
						
						[[transaction ext:Ext_CloudKit] mergeRecord:record databaseIdentifier:nil];
					}
					else if (!hasPendingDelete)
					{
						S1Topic *newTopic = [[S1Topic alloc] initWithRecord:record];
						
						NSString *key = [newTopic.topicID stringValue];
						NSString *collection = Collection_Topics;
						
						// This MUST go FIRST
						[[transaction ext:Ext_CloudKit] attachRecord:record
						                          databaseIdentifier:nil
						                                      forKey:key
						                                inCollection:collection
						                          shouldUploadRecord:NO];
						
						// This MUST go SECOND
						[transaction setObject:newTopic forKey:key inCollection:Collection_Topics];
					}
				}
				
				// And save the serverChangeToken (in the same atomic transaction)
				[transaction setObject:serverChangeToken
				                forKey:Key_ServerChangeToken
				          inCollection:Collection_CloudKit];
				
			} completionBlock:^{
                __strong __typeof__(self) strongSelf = weakSelf;

				if (completionHandler)
				{
					if (hasChanges)
						completionHandler(UIBackgroundFetchResultNewData, moreComing);
					else
						completionHandler(UIBackgroundFetchResultNoData, moreComing);
				}
				
				if (moreComing) {
					[strongSelf _fetchRecordChangesWithCompletionHandler:completionHandler];
				}
				else {
                    dispatch_resume(self->fetchQueue);
				}
			}];
		
		} // end if (hasChanges)
	};
	
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:operation];
}

/**
 * This method forces a re-fetch & merge operation.
 * This can be handly for records that have already been fetched via CKFetchRecordChangesOperation,
 * however we somehow managed to screw up merging the information into our local object(s).
 * 
 * This is usually due to bugs in the data model implementation, or perhaps your YapDatabaseCloudKitMergeBlock.
 * But bugs are a normal and expected part of development.
 * 
 * For example:
 *   A few new propertie were added to our local object.
 *   We remembered to add these to the CKRecord(s) upon saving (so the new proerties got uploaded fine).
 *   But we forgot to update init method that sets the localObject.property from the new CKRecord.propertly. Oops!
 *   So now we have a few devices that have synced objects that are missing these properties.
 *
 * So rather than deleting & re-installing the app,
 * we provide this method as a way to force another fetch & merge operation.
**/
- (void)refetchMissedRecordIDs:(NSArray *)recordIDs withCompletionHandler:(void (^)(NSError *error))completionHandler
{
	CKFetchRecordsOperation *operation = [[CKFetchRecordsOperation alloc] initWithRecordIDs:recordIDs];
	
	operation.perRecordCompletionBlock = ^(CKRecord *record, CKRecordID *recordID, NSError *error) {
		
		if (error) {
			DDLogDebug(@"CKFetchRecordsOperation.perRecordCompletionBlock: %@ -> %@", recordID, error);
		}
	};
	
	operation.fetchRecordsCompletionBlock = ^(NSDictionary *recordsByRecordID, NSError *operationError) {
		
		if (operationError && operationError.code != 2)
		{
			if (completionHandler) {
				completionHandler(operationError);
			}
		}
		else
		{
			DDLogDebug(@"CKFetchRecordsOperation: recordsByRecordID: %@", recordsByRecordID);
			
            [self->databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				for (CKRecord *record in [recordsByRecordID objectEnumerator])
				{
					[[transaction ext:Ext_CloudKit] mergeRecord:record databaseIdentifier:nil];
				}
				
			} completionBlock:^{
				
				if (completionHandler) {
					completionHandler(nil);
				}
			}];
		}
	};
	
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:operation];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Error Handling
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Invoke me if you get one of the following errors via YapDatabaseCloudKitOperationErrorBlock:
 *
 * - CKErrorNetworkUnavailable
 * - CKErrorNetworkFailure
**/
- (void)handleNetworkError
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	// When the YapDatabaseCloudKitOperationErrorBlock is invoked,
	// the extension has already automatically suspended itself.
	// It is our job to properly handle the error, and resume the extension when ready.
	self.needsResume = YES;
	
	if (MyAppDelegate.reachability.isReachable)
	{
		self.needsResume = NO;
		[MyDatabaseManager.cloudKitExtension resume];
	}
	else
	{
		// Wait for reachability notification
	}
}

/**
 * Invoke me if you get one of the following errors via YapDatabaseCloudKitOperationErrorBlock:
 *
 * - CKErrorPartialFailure
**/
- (void)handlePartialFailure
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	// When the YapDatabaseCloudKitOperationErrorBlock is invoked,
	// the extension has already automatically suspended itself.
	// It is our job to properly handle the error, and resume the extension when ready.
	self.needsResume = YES;
	
	// In the case of a partial failure, we have out-of-date CKRecords.
	// To fix the problem, we need to:
	// - fetch the latest changes from the server
	// - merge these changes with our local/pending CKRecord(s)
	// - retry uploading the CKRecord(s)
	self.needsFetchRecordChanges = YES;
	
	
	YDBCKChangeSet *failedChangeSet = [MyDatabaseManager.cloudKitExtension currentChangeSet];
	
	if ([failedChangeSet.uuid isEqualToString:lastChangeSetUUID] && self.lastSuccessfulFetchResultWasNoData)
	{
		// We screwed up a merge somehow.
		//
		// Here's what happend:
		// - We fetched all the record changes (via CKFetchRecordChangesOperation).
		// - But we failed to merge the fetched changes into our local CKRecord(s).
		//   This could be a bug in YapDatabaseCloudKit.
		//   Or maybe a bug in your CKFetchRecordChangesOperation.fetchRecordChangesCompletionBlock implementation.
		// - So at this point we'd normally fall into an infinite loop:
		//     - We do a CKFetchRecordChangesOperation
		//     - Find there's no new data (since prevServerChangeToken)
		//     - Attempt to upload our modified CKRecord(s)
		//     - Get a partial failure
		//     - We do a CKFetchRecordChangesOperation
		//     - ... infinte loop
		//
		// This is a common problem you might run into during the normal development cycle.
		// So we print out a warning here to let you know about the problem.
		//
		// And then we refetch the missed records.
		// Hopefully refetching & re-merging should solve the infinite loop problem.
		
		self.needsRefetchMissedRecordIDs = YES;
		[self _refetchMissedRecordIDs];
	}
	else
	{
		[self _fetchRecordChanges];
	}
}

- (void)handleNotAuthenticated {
	self.needsResume = YES;
	
	[self warnAboutAccount];
    self.state = CKManagerStateHalt;
}

- (void)handleChangeTokenExpired {
    self.needsResume = YES;
    
    [databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeObjectForKey:Key_ServerChangeToken inCollection:Collection_CloudKit];
	}];
    [self continueCloudKitFlow];
}

- (void)handleZoneNotFound {
    [self prepareForUnregister];
    
    self.needsCreateZone = YES;
    [MyDatabaseManager.cloudKitExtension suspend];
    
    self.needsCreateZoneSubscription = YES;
    [MyDatabaseManager.cloudKitExtension suspend];
    
    self.needsResume = YES;
    
    [self continueCloudKitFlow];
}

- (void)handleUserDeletedZone {
    [self handleZoneNotFound];
}

- (void)handleOtherErrors {
    self.state = CKManagerStateHalt;
}

- (void)handleRequestRateLimitedAndServiceUnavailableWithError:(NSError *)error {
    NSNumber *retryDelay = error.userInfo[CKErrorRetryAfterKey];
    DDLogInfo(@"Cloudkit Operation Should Retry after %@ seconds", retryDelay);
    if (retryDelay != nil) {
        self.state = CKManagerStateRecovering;
        NSInteger delaySeconds = MAX(retryDelay.integerValue, 100);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delaySeconds * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.needsResume = YES;
        });
        [Answers logCustomEventWithName:@"CloudKit Rerty Interval" customAttributes:@{
            @"interval": retryDelay
        }];
    } else {
        self.state = CKManagerStateHalt;
    }
}

- (void)reportError:(NSError *)error {
    if ([error.domain isEqualToString:CKErrorDomain]) {
        self.lastCloudkitError = error;
        [[NSNotificationCenter defaultCenter] postNotificationName:YapDatabaseCloudKitUnhandledErrorOccurredNotification object:error];
        self.state = CKManagerStateRecovering;

        NSString *code = [NSString stringWithFormat:@"%ld", (long)[error code]];
        NSString *errorDescription = [[error userInfo] valueForKey:@"CKErrorDescription"];
        if (errorDescription == nil) {
            errorDescription = @"Unknown";
        }
        NSString *subErrorDescription = nil;
        NSArray *allErrors = [(NSDictionary *)[[error userInfo] valueForKey:@"CKPartialErrors"] allValues];
        for (NSError *subError in allErrors) {
            if (subError.code != CKErrorBatchRequestFailed) {
                subErrorDescription = [[subError userInfo] valueForKey:@"ServerErrorDescription"];
                code = [code stringByAppendingString:[NSString stringWithFormat:@"/%ld", (long)[subError code]]];
                break;
            }
        }
        if (subErrorDescription != nil) {
            errorDescription = subErrorDescription;
        }
        code = [code stringByAppendingString:[NSString stringWithFormat:@"(%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];
        [Answers logCustomEventWithName:@"CloudKit Error" customAttributes:@{
            @"code": code,
            @"description": errorDescription
        }];
        DDLogWarn(@"[CloudKit] ckErrorCode:%ld description:%@", (long)code, errorDescription);
        [[Crashlytics sharedInstance] recordError:error];
    }
}

- (void)_refetchMissedRecordIDs
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	YDBCKChangeSet *failedChangeSet = [MyDatabaseManager.cloudKitExtension currentChangeSet];
	NSArray *recordIDs = failedChangeSet.recordIDsToSave;
	
	if (recordIDs.count == 0)
	{
		// Oops, we don't have anything to refetch.
		// Fallback to checking other scenarios.
		
		self.needsRefetchMissedRecordIDs = NO;
		[self continueCloudKitFlow];
		return;
	}
	
	[self refetchMissedRecordIDs:recordIDs withCompletionHandler:^(NSError *error) {
		
		if (error)
		{
			if (MyAppDelegate.reachability.isReachable)
			{
				[self _refetchMissedRecordIDs]; // try again
			}
			else
			{
				// Wait for reachability notification
			}
		}
		else
		{
			self.needsRefetchMissedRecordIDs = NO;
			self.needsFetchRecordChanges = NO;
			
			[self continueCloudKitFlow];
		}
	}];
}

- (void)_fetchRecordChanges
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	[self fetchRecordChangesWithCompletionHandler:^(UIBackgroundFetchResult result, BOOL moreComing) {
		
		if (result == UIBackgroundFetchResultFailed)
		{
			if (MyAppDelegate.reachability.isReachable)
			{
				[self _fetchRecordChanges]; // try again
			}
			else
			{
				// Wait for reachability notification
			}
		}
		else
		{
			if (!moreComing)
			{
				self.needsFetchRecordChanges = NO;
				[self continueCloudKitFlow];
			}
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	if (self.needsCreateZone || self.needsCreateZoneSubscription || self.needsFetchRecordChangesAfterAppLaunch)
	{
		// CloudKit isn't fully setup yet
	}
	else
	{
		// CloudKit is setup.
		// Perform normal suspend & flag operations.
		
		if (self.needsResume == NO)
		{
			self.needsResume = YES;
			[MyDatabaseManager.cloudKitExtension suspend];
		}
		
		self.needsFetchRecordChanges = YES;
	}
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	[self continueCloudKitFlow];
}

- (void)cloudKitInFlightChangeSetChanged:(NSNotification *)notification
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	NSString *changeSetUUID = [notification.userInfo objectForKey:@"uuid"];
	
	lastChangeSetUUID = changeSetUUID;
    
    NSUInteger suspendCount = [MyDatabaseManager.cloudKitExtension suspendCount];
    
    NSUInteger inFlightCount = 0;
    NSUInteger queuedCount = 0;
    [MyDatabaseManager.cloudKitExtension getNumberOfInFlightChangeSets:&inFlightCount queuedChangeSets:&queuedCount];
    if (suspendCount == 0 && inFlightCount + queuedCount > 0) {
        self.state = CKManagerStateUploading;
    } else if(suspendCount == 0 && inFlightCount + queuedCount == 0) {
        self.state = CKManagerStateReady;
    }
    
}

- (void)reachabilityChanged:(NSNotification *)notification
{
	DDLogDebug(@"%@ - %@", THIS_FILE, THIS_METHOD);
	
	Reachability *reachability = notification.object;
	
	DDLogDebug(@"%@ - reachability.isReachable = %@", THIS_FILE, (reachability.isReachable ? @"YES" : @"NO"));
	if (reachability.isReachable)
	{
        //self.state = CKManagerStateReady;
		[self continueCloudKitFlow];
	}
}

- (void)cloudKitRegisterFinish {
    dispatch_resume(fetchQueue);
    dispatch_resume(setupQueue);
}

#pragma mark State Change

- (void)setState:(CKManagerState)state {
    if (_state != state) {
        _state = state;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:YapDatabaseCloudKitStateChangeNotification object:nil];
        });
    }
}

@end
