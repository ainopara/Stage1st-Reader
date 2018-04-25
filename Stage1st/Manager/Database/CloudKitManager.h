#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const YapDatabaseCloudKitUnhandledErrorOccurredNotification;

typedef enum : NSUInteger {
    CKManagerStateInit, // extension registering
    CKManagerStateSetup, // create zone and create zone subscription
    CKManagerStateFetching, // fetch server changes
    CKManagerStateUploading, // upload local changes
    CKManagerStateReady, // nothing to do, ready for fetch or upload
    CKManagerStateRecovering, // trying to recover from an error
    CKManagerStateHalt, // failed to recover from an error, will halt until next boot
} CKManagerState;
