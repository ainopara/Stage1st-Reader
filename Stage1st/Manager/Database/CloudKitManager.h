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
