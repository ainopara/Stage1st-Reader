#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class CloudKitManager;

/**
 * You can use this as an alternative to the sharedInstance:
 * [[CloudKitManager sharedInstance] foobar] -> MyCloudKitManager.foobar
**/
extern CloudKitManager *MyCloudKitManager;
extern NSString *const YapDatabaseCloudKitUnhandledErrorOccurredNotification;
extern NSString *const YapDatabaseCloudKitStateChangeNotification;

typedef enum : NSUInteger {
    CKManagerStateInit, // extension registering
    CKManagerStateSetup, // create zone and create zone subscription
    CKManagerStateFetching, // fetch server changes
    CKManagerStateUploading, // upload local changes
    CKManagerStateReady, // nothing to do, ready for fetch or upload
    CKManagerStateRecovering, // trying to recover from an error
    CKManagerStateHalt, // failed to recover from an error, will halt until next boot
} CKManagerState;


@interface CloudKitManager : NSObject

@property (nonatomic, assign) CKManagerState state;

@property (strong, atomic) NSError *lastCloudkitError;

/**
 * Standard singleton pattern.
 * As a shortcut, you can use the global MyCloudKitManager ivar instead.
**/
+ (instancetype)sharedInstance; // Or MyCloudKitManager global ivar


- (void)prepareForUnregister;
/**
 * Invoke me if you get one of the following errors via YapDatabaseCloudKitOperationErrorBlock:
 * - CKErrorNetworkUnavailable
 * - CKErrorNetworkFailure
**/
- (void)handleNetworkError;

/**
 * Invoke me if you get one of the following errors via YapDatabaseCloudKitOperationErrorBlock:
 * - CKErrorPartialFailure
**/
- (void)handlePartialFailure;

/**
 * Invoke me if you get one of the following errors via YapDatabaseCloudKitOperationErrorBlock:
 * - CKErrorNotAuthenticated
**/
- (void)handleNotAuthenticated;

- (void)handleChangeTokenExpired;

- (void)handleZoneNotFound;

- (void)handleUserDeletedZone;

- (void)handleRequestRateLimitedAndServiceUnavailableWithError:(NSError *)error;

- (void)handleOtherErrors;

- (void)reportError:(NSError *)error;

/**
 * This method uses CKFetchRecordChangesOperation to fetch changes.
 * It continues fetching until it's reported that we're caught up.
 * 
 * This method is invoked once automatically, when the CloudKitManager is initialized.
 * After that, one should invoke it anytime a corresponding push notification is received.
**/
- (void)fetchRecordChangesWithCompletionHandler:
                            (void (^)(UIBackgroundFetchResult result, BOOL moreComing))completionHandler;

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
- (void)refetchMissedRecordIDs:(NSArray *)recordIDs withCompletionHandler:(void (^)(NSError *error))completionHandler;



@end
