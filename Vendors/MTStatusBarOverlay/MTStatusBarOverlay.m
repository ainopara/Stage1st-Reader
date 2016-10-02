//
//  MTStatusBarOverlay.m
//
//  Created by Matthias Tretter on 27.09.10.
//  Copyright (c) 2009-2011  Matthias Tretter, @myell0w. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Credits go to:
// -------------------------------
// http://stackoverflow.com/questions/2833724/adding-view-on-statusbar-in-iphone
// http://www.cocoabyss.com/uikit/custom-status-bar-ios/
// @reederapp for inspiration
// -------------------------------

#import "MTStatusBarOverlay.h"
#import <QuartzCore/QuartzCore.h>


////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Functions
////////////////////////////////////////////////////////////////////////

void mt_dispatch_sync_on_main_thread(dispatch_block_t block);

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Defines
////////////////////////////////////////////////////////////////////////
#define DEVICE_SIZE [[UIApplication sharedApplication] keyWindow].frame.size
// the height of the status bar
#define kStatusBarHeight 20.f
// width of the screen in portrait-orientation
#define kScreenWidth DEVICE_SIZE.width
// height of the screen in portrait-orientation
#define kScreenHeight DEVICE_SIZE.height
// macro for checking if we are on the iPad
#define IsIPad (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
// macro for checking if we are on the iPad in iPhone-Emulation mode
#define IsIPhoneEmulationMode (!IsIPad && \
MAX([UIApplication sharedApplication].statusBarFrame.size.width, [UIApplication sharedApplication].statusBarFrame.size.height) > 480.f)



////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Customization
////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////
// iOS7 Theme (for UIStatusBarStyleDefault)
///////////////////////////////////////////////////////

#define kTextColor						        [[APColorManager shared] colorForKey:@"overlay.text"]
#define kErrorMessageTextColor       	        [[APColorManager shared] colorForKey:@"overlay.text"]
#define kFinishedMessageTextColor    	        [[APColorManager shared] colorForKey:@"overlay.text"]
#define kBackgroundColor                        [[APColorManager shared] colorForKey:@"overlay.background"]
#define kActivityIndicatorViewStyle		    	([[APColorManager shared] isDarkTheme] ? UIActivityIndicatorViewStyleWhite:UIActivityIndicatorViewStyleGray)

///////////////////////////////////////////////////////
// Progress
///////////////////////////////////////////////////////

#define kProgressViewAlpha                          0.4f
#define kProgressViewBackgroundColor                [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f]


///////////////////////////////////////////////////////
// Animations
///////////////////////////////////////////////////////

// minimum time that a message is shown, when messages are queued
#define kMinimumMessageVisibleTime				0.4f

// duration of the animation to show next status message in seconds
#define kNextStatusAnimationDuration			0.6f

// duration the statusBarOverlay takes to appear when it was hidden
#define kAppearAnimationDuration				0.5f

// animation duration of animation mode shrink
#define kAnimationDurationShrink				0.3f

// animation duration of animation mode fallDown
#define kAnimationDurationFallDown				0.4f

// animation duration of change of progressView-size
#define kUpdateProgressViewDuration             0.2f

// delay after that the status bar gets visible again after rotation
#define kRotationAppearDelay					[UIApplication sharedApplication].statusBarOrientationAnimationDuration


///////////////////////////////////////////////////////
// Text
///////////////////////////////////////////////////////

// Text that is displayed in the finished-Label when the finish was successful
#define kFinishedText		@"✓"
#define kFinishedFontSize	22.f

// Text that is displayed when an error occured
#define kErrorText			@"✗"
#define kErrorFontSize		19.f



///////////////////////////////////////////////////////
// Size
///////////////////////////////////////////////////////

// Size of the text in the status labels
#define kStatusLabelSize				12.f

// default-width of the small-mode
#define kWidthSmall						26.f


////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Class Extension
////////////////////////////////////////////////////////////////////////

@interface MTStatusBarOverlay ()

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UIImageView *statusBarBackgroundImageView;
@property (nonatomic, strong) UILabel *statusLabel1;
@property (nonatomic, strong) UILabel *statusLabel2;
@property (nonatomic, unsafe_unretained) UILabel *hiddenStatusLabel;
@property (unsafe_unretained, nonatomic, readonly) UILabel *visibleStatusLabel;
@property (nonatomic, strong) UIImageView *progressView;
@property (nonatomic, assign) CGRect oldBackgroundViewFrame;
// overwrite property for read-write-access
@property (assign, getter=isHideInProgress) BOOL hideInProgress;
@property (assign, getter=isActive) BOOL active;
// read out hidden-state using alpha-value and hidden-property
@property (nonatomic, readonly, getter=isReallyHidden) BOOL reallyHidden;
@property (nonatomic, strong) NSMutableArray *messageQueue;
// overwrite property for read-write-access
@property (nonatomic, strong) NSMutableArray *messageHistory;
@property (nonatomic, assign) BOOL forcedToHide;
@property (nonatomic, assign) MTMessageType messageType;

// intern method that posts a new entry to the message-queue
- (void)postMessage:(NSString *)message type:(MTMessageType)messageType duration:(NSTimeInterval)duration animated:(BOOL)animated immediate:(BOOL)immediate;
// intern method that clears the messageQueue and then posts a new entry to it
- (void)postImmediateMessage:(NSString *)message type:(MTMessageType)messageType duration:(NSTimeInterval)duration animated:(BOOL)animated;
// intern method that does all the work of showing the next message in the queue
- (void)showNextMessage;

// is called when the user touches the statusbar
- (void)contentViewClicked:(UIGestureRecognizer *)gestureRecognizer;

// updates the current status bar background image for the given style and current size
- (void)setStatusBarBackground;
// updates the text-colors of the labels for the given style and message type
- (void)setColorSchemeForMessageType:(MTMessageType)messageType;
// updates the visiblity of the activity indicator and finished-label depending on the type
- (void)updateUIForMessageType:(MTMessageType)messageType duration:(NSTimeInterval)duration;
// updates the size of the progressView to always cover only the displayed text-frame
- (void)updateProgressViewSizeForLabel:(UILabel *)label;
// calls the delegate when a switch from one message to another one occured
- (void)callDelegateWithNewMessage:(NSString *)newMessage;

// shrink/expand the overlay
- (void)setShrinked:(BOOL)shrinked animated:(BOOL)animated;

// set hidden-state using alpha-value instead of hidden-property
- (void)setHidden:(BOOL)hidden useAlpha:(BOOL)useAlpha;
// used for performSelector:withObject:
- (void)setHiddenUsingAlpha:(BOOL)hidden;

// History-tracking
- (void)addMessageToHistory:(NSString *)message;
- (void)clearHistory;

// selectors
- (void)rotateToStatusBarFrame:(NSValue *)statusBarFrameValue;
- (void)didChangeStatusBarFrame:(NSNotification *)notification;

// Fix to not overlay Notification Center
- (void)applicationDidBecomeActive:(NSNotification *)notifaction;
- (void)applicationWillResignActive:(NSNotification *)notifaction;

// returns the current frame for the detail view depending on the interface orientation
- (CGRect)backgroundViewFrameForStatusBarInterfaceOrientation;

@end



@implementation MTStatusBarOverlay

@synthesize backgroundView = backgroundView_;
@synthesize statusBarBackgroundImageView = statusBarBackgroundImageView_;
@synthesize statusLabel1 = statusLabel1_;
@synthesize statusLabel2 = statusLabel2_;
@synthesize hiddenStatusLabel = hiddenStatusLabel_;
@synthesize progress = progress_;
@synthesize progressView = progressView_;
@synthesize activityIndicator = activityIndicator_;
@synthesize finishedLabel = finishedLabel_;
@synthesize hidesActivity = hidesActivity_;
@synthesize defaultStatusBarImage = defaultStatusBarImage_;
@synthesize defaultStatusBarImageShrinked = defaultStatusBarImageShrinked_;
@synthesize smallFrame = smallFrame_;
@synthesize oldBackgroundViewFrame = oldBackgroundViewFrame_;
@synthesize animation = animation_;
@synthesize hideInProgress = hideInProgress_;
@synthesize active = active_;
@synthesize messageQueue = messageQueue_;
@synthesize canRemoveImmediateMessagesFromQueue = canRemoveImmediateMessagesFromQueue_;
@synthesize messageHistory = messageHistory_;
@synthesize delegate = delegate_;
@synthesize forcedToHide = forcedToHide_;
@synthesize lastPostedMessage = lastPostedMessage_;

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Lifecycle
////////////////////////////////////////////////////////////////////////

- (id)init {
    if ((self = [super init])) {
        CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
        
		// only use height of 20px even is status bar is doubled
		statusBarFrame.size.height = statusBarFrame.size.height == 2*kStatusBarHeight ? kStatusBarHeight : statusBarFrame.size.height;
		// if we are on the iPad but in iPhone-Mode (non-universal-app) correct the width
		if(IsIPhoneEmulationMode) {
			statusBarFrame.size.width = 320.f;
		}
        
		// Place the window on the correct level and position
        self.windowLevel = UIWindowLevelStatusBar+1.f;
        self.frame = statusBarFrame;
		self.alpha = 0.f;
		self.hidden = NO;
        self.backgroundColor = [UIColor clearColor];
        
		// Default Small size: just show Activity Indicator
		smallFrame_ = CGRectMake(statusBarFrame.size.width - kWidthSmall, 0.f, kWidthSmall, statusBarFrame.size.height);
        
		// Default-values
		animation_ = MTStatusBarOverlayAnimationNone;
		active_ = NO;
		hidesActivity_ = NO;
        forcedToHide_ = NO;
        
		// Message History
		messageHistory_ = [[NSMutableArray alloc] init];
        
        
        // Create view that stores all the content
        CGRect backgroundFrame = [self backgroundViewFrameForStatusBarInterfaceOrientation];
        backgroundView_ = [[UIView alloc] initWithFrame:backgroundFrame];
		backgroundView_.clipsToBounds = YES;
		backgroundView_.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        oldBackgroundViewFrame_ = backgroundView_.frame;
        
		// Add gesture recognizers
		UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(contentViewClicked:)];
        
		[backgroundView_ addGestureRecognizer:tapGestureRecognizer];
        
		// Images used as background when status bar style is Default
        defaultStatusBarImage_ = [S1Global imageWithColor:kBackgroundColor];
        defaultStatusBarImageShrinked_ = [S1Global imageWithColor:kBackgroundColor];
		
        
		// Background-Image of the Content View
		statusBarBackgroundImageView_ = [[UIImageView alloc] initWithFrame:backgroundView_.frame];
		statusBarBackgroundImageView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self addSubviewToBackgroundView:statusBarBackgroundImageView_];
        
		// Activity Indicator
		activityIndicator_ = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		activityIndicator_.frame = CGRectMake(6.f, 3.f, backgroundView_.frame.size.height - 6.f, backgroundView_.frame.size.height - 6.f);
		activityIndicator_.hidesWhenStopped = YES;
        
        // iOS 5 doesn't correctly resize the activityIndicator. Bug?
        if ([activityIndicator_ respondsToSelector:@selector(setColor:)]) {
            [activityIndicator_.layer setValue:[NSNumber numberWithFloat:0.75f] forKeyPath:@"transform.scale"];
        }
        
		[self addSubviewToBackgroundView:activityIndicator_];
        
		// Finished-Label
		finishedLabel_ = [[UILabel alloc] initWithFrame:CGRectMake(4.f,1.f,backgroundView_.frame.size.height, backgroundView_.frame.size.height-1.f)];
		finishedLabel_.shadowOffset = CGSizeMake(0.f, 1.f);
		finishedLabel_.backgroundColor = [UIColor clearColor];
		finishedLabel_.hidden = YES;
		finishedLabel_.text = kFinishedText;
		finishedLabel_.textAlignment = NSTextAlignmentCenter;
		finishedLabel_.font = [UIFont systemFontOfSize:kFinishedFontSize];
        finishedLabel_.adjustsFontSizeToFitWidth = YES;
		[self addSubviewToBackgroundView:finishedLabel_];
        
		// Status Label 1 is first visible
		statusLabel1_ = [[UILabel alloc] initWithFrame:CGRectMake(30.f, 0.f, backgroundView_.frame.size.width - 60.f,backgroundView_.frame.size.height-1.f)];
		statusLabel1_.backgroundColor = [UIColor clearColor];
		statusLabel1_.shadowOffset = CGSizeMake(0.f, 1.f);
        statusLabel1_.font = [UIFont systemFontOfSize:kStatusLabelSize];
		statusLabel1_.textAlignment = NSTextAlignmentCenter;
		statusLabel1_.numberOfLines = 1;
		statusLabel1_.lineBreakMode = NSLineBreakByTruncatingTail;
		statusLabel1_.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self addSubviewToBackgroundView:statusLabel1_];
        
		// Status Label 2 is hidden
		statusLabel2_ = [[UILabel alloc] initWithFrame:CGRectMake(30.f, backgroundView_.frame.size.height,backgroundView_.frame.size.width - 60.f , backgroundView_.frame.size.height-1.f)];
		statusLabel2_.shadowOffset = CGSizeMake(0.f, 1.f);
		statusLabel2_.backgroundColor = [UIColor clearColor];

        statusLabel2_.font = [UIFont systemFontOfSize:kStatusLabelSize];
		statusLabel2_.textAlignment = NSTextAlignmentCenter;
		statusLabel2_.numberOfLines = 1;
		statusLabel2_.lineBreakMode = NSLineBreakByTruncatingTail;
		statusLabel2_.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self addSubviewToBackgroundView:statusLabel2_];
        
		// the hidden status label at the beginning
		hiddenStatusLabel_ = statusLabel2_;
        
        progress_ = 1.0;
        progressView_ = [[UIImageView alloc] initWithFrame:statusBarBackgroundImageView_.frame];
        progressView_.opaque = NO;
        progressView_.hidden = YES;
        progressView_.alpha = kProgressViewAlpha;
        [self addSubviewToBackgroundView:progressView_];
        
		messageQueue_ = [[NSMutableArray alloc] init];
		canRemoveImmediateMessagesFromQueue_ = YES;
        
        [self addSubview:backgroundView_];
        
		// listen for changes of status bar frame
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeStatusBarFrame:) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willChangeToSize:) name:@"S1ViewWillTransitionToSizeNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColor) name:@"APPaletteDidChangeNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        
        // initial rotation, fixes the issue with a wrong bar appearance in landscape only mode
        [self rotateToStatusBarFrame:nil];
    }
    
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
	delegate_ = nil;
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Status Bar Appearance
////////////////////////////////////////////////////////////////////////

- (void)addSubviewToBackgroundView:(UIView *)view {
	view.userInteractionEnabled = NO;
	[self.backgroundView addSubview:view];
}

- (void)addSubviewToBackgroundView:(UIView *)view atIndex:(NSInteger)index {
	view.userInteractionEnabled = NO;
	[self.backgroundView insertSubview:view atIndex:index];
}


////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Save/Restore current State
////////////////////////////////////////////////////////////////////////

- (void)saveState {
    [self saveStateSynchronized:YES];
}

- (void)saveStateSynchronized:(BOOL)synchronizeAtEnd {
    // TODO: save more state
    [[NSUserDefaults standardUserDefaults] setBool:self.shrinked forKey:kMTStatusBarOverlayStateShrinked];
    
    if (synchronizeAtEnd) {
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)restoreState {
    // restore shrinked-state
    [self setShrinked:[[NSUserDefaults standardUserDefaults] boolForKey:kMTStatusBarOverlayStateShrinked] animated:NO];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Message Posting
////////////////////////////////////////////////////////////////////////

- (void)postMessage:(NSString *)message {
	[self postMessage:message animated:YES];
}

- (void)postMessage:(NSString *)message animated:(BOOL)animated {
	[self postMessage:message type:MTMessageTypeActivity duration:0 animated:animated immediate:NO];
}

- (void)postMessage:(NSString *)message duration:(NSTimeInterval)duration {
	[self postMessage:message type:MTMessageTypeActivity duration:duration animated:YES immediate:NO];
}

- (void)postMessage:(NSString *)message duration:(NSTimeInterval)duration animated:(BOOL)animated {
    [self postMessage:message type:MTMessageTypeActivity duration:duration animated:animated immediate:NO];
}

- (void)postImmediateMessage:(NSString *)message animated:(BOOL)animated {
	[self postImmediateMessage:message type:MTMessageTypeActivity duration:0 animated:animated];
}

- (void)postImmediateMessage:(NSString *)message duration:(NSTimeInterval)duration {
    [self postImmediateMessage:message type:MTMessageTypeActivity duration:duration animated:YES];
}

- (void)postImmediateMessage:(NSString *)message duration:(NSTimeInterval)duration animated:(BOOL)animated {
    [self postImmediateMessage:message type:MTMessageTypeActivity duration:duration animated:animated];
}

- (void)postFinishMessage:(NSString *)message duration:(NSTimeInterval)duration {
	[self postFinishMessage:message duration:duration animated:YES];
}

- (void)postFinishMessage:(NSString *)message duration:(NSTimeInterval)duration animated:(BOOL)animated {
	[self postMessage:message type:MTMessageTypeFinish duration:duration animated:animated immediate:NO];
}

- (void)postImmediateFinishMessage:(NSString *)message duration:(NSTimeInterval)duration animated:(BOOL)animated {
	[self postImmediateMessage:message type:MTMessageTypeFinish duration:duration animated:animated];
}

- (void)postErrorMessage:(NSString *)message duration:(NSTimeInterval)duration {
	[self postErrorMessage:message duration:duration animated:YES];
}

- (void)postErrorMessage:(NSString *)message duration:(NSTimeInterval)duration animated:(BOOL)animated {
	[self postMessage:message type:MTMessageTypeError duration:duration animated:animated immediate:NO];
}

- (void)postImmediateErrorMessage:(NSString *)message duration:(NSTimeInterval)duration animated:(BOOL)animated {
	[self postImmediateMessage:message type:MTMessageTypeError duration:duration animated:animated];
}

- (void)postMessageDictionary:(NSDictionary *)messageDictionary {
    [self postMessage:[messageDictionary valueForKey:kMTStatusBarOverlayMessageKey]
                 type:[[messageDictionary valueForKey:kMTStatusBarOverlayMessageTypeKey] intValue]
             duration:[[messageDictionary valueForKey:kMTStatusBarOverlayDurationKey] doubleValue]
             animated:[[messageDictionary valueForKey:kMTStatusBarOverlayAnimationKey] boolValue]
            immediate:[[messageDictionary valueForKey:kMTStatusBarOverlayImmediateKey] boolValue]];
}

- (void)postMessage:(NSString *)message type:(MTMessageType)messageType duration:(NSTimeInterval)duration animated:(BOOL)animated immediate:(BOOL)immediate {
    mt_dispatch_sync_on_main_thread(^{
        // don't add to queue when message is empty
        if (message.length == 0) {
            return;
        }
        
        NSDictionary *messageDictionaryRepresentation = [NSDictionary dictionaryWithObjectsAndKeys:message, kMTStatusBarOverlayMessageKey,
                                                         [NSNumber numberWithInt:messageType], kMTStatusBarOverlayMessageTypeKey,
                                                         [NSNumber numberWithDouble:duration], kMTStatusBarOverlayDurationKey,
                                                         [NSNumber numberWithBool:animated],  kMTStatusBarOverlayAnimationKey,
                                                         [NSNumber numberWithBool:immediate], kMTStatusBarOverlayImmediateKey, nil];
        
        @synchronized (self.messageQueue) {
            [self.messageQueue insertObject:messageDictionaryRepresentation atIndex:0];
        }
        
        // if the overlay is currently not active, begin with showing of messages
        if (!self.active) {
            [self showNextMessage];
        }
    });
}

- (void)postImmediateMessage:(NSString *)message type:(MTMessageType)messageType duration:(NSTimeInterval)duration animated:(BOOL)animated {
	@synchronized(self.messageQueue) {
		NSMutableArray *clearedMessages = [NSMutableArray array];
        
		for (id messageDictionary in self.messageQueue) {
			if (messageDictionary != [self.messageQueue lastObject] &&
				(self.canRemoveImmediateMessagesFromQueue || [[messageDictionary valueForKey:kMTStatusBarOverlayImmediateKey] boolValue] == NO)) {
				[clearedMessages addObject:messageDictionary];
			}
		}
        
		[self.messageQueue removeObjectsInArray:clearedMessages];
        
		// call delegate
		if ([self.delegate respondsToSelector:@selector(statusBarOverlayDidClearMessageQueue:)] && clearedMessages.count > 0) {
			[self.delegate statusBarOverlayDidClearMessageQueue:clearedMessages];
		}
	}
    
	[self postMessage:message type:messageType duration:duration animated:animated immediate:YES];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Showing Next Message
////////////////////////////////////////////////////////////////////////

- (void)showNextMessage {
    if (self.forcedToHide) {
        return;
    }
    
	// if there is no next message to show overlay is not active anymore
	@synchronized(self.messageQueue) {
		if([self.messageQueue count] < 1) {
			self.active = NO;
			return;
		}
	}
    
	// there is a next message, overlay is active
	self.active = YES;
    
	NSDictionary *nextMessageDictionary = nil;
    
	// read out next message
	@synchronized(self.messageQueue) {
		nextMessageDictionary = [self.messageQueue lastObject];
	}
    
	NSString *message = [nextMessageDictionary valueForKey:kMTStatusBarOverlayMessageKey];
	MTMessageType messageType = (MTMessageType)[[nextMessageDictionary valueForKey:kMTStatusBarOverlayMessageTypeKey] intValue];
	NSTimeInterval duration = (NSTimeInterval)[[nextMessageDictionary valueForKey:kMTStatusBarOverlayDurationKey] doubleValue];
	BOOL animated = [[nextMessageDictionary valueForKey:kMTStatusBarOverlayAnimationKey] boolValue];
    
	// don't show anything if status bar is hidden (queue gets cleared)
	if([UIApplication sharedApplication].statusBarHidden) {
		@synchronized(self.messageQueue) {
			[self.messageQueue removeAllObjects];
		}
        
		self.active = NO;
        
		return;
	}
    
	// don't duplicate animation if already displaying with text
	if (!self.reallyHidden && [self.visibleStatusLabel.text isEqualToString:message]) {
		// remove unneccesary message
		@synchronized(self.messageQueue) {
            if (self.messageQueue.count > 0)
                [self.messageQueue removeLastObject];
		}
        
		// show the next message w/o delay
		[self showNextMessage];
        
		return;
	}
    
	// cancel previous hide- and clear requests
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearHistory) object:nil];
    
	// update UI depending on current status bar style
	[self setStatusBarBackground];
	[self setColorSchemeForMessageType:messageType];
	[self updateUIForMessageType:messageType duration:duration];
    
	// if status bar is currently hidden, show it unless it is forced to hide
	if (self.reallyHidden) {
		// clear currently visible status label
		self.visibleStatusLabel.text = @"";
        
		// show status bar overlay with animation
		[UIView animateWithDuration:self.shrinked ? 0 : kAppearAnimationDuration
						 animations:^{
							 [self setHidden:NO useAlpha:YES];
						 }];
	}
    
    
    if (animated) {
        // set text of currently not visible label to new text
        self.hiddenStatusLabel.text = message;
        // update progressView to only cover displayed text
        [self updateProgressViewSizeForLabel:self.hiddenStatusLabel];
        
        // position hidden status label under visible status label
        self.hiddenStatusLabel.frame = CGRectMake(self.hiddenStatusLabel.frame.origin.x,
                                                  kStatusBarHeight,
                                                  self.hiddenStatusLabel.frame.size.width,
                                                  self.hiddenStatusLabel.frame.size.height);
        
        
        // animate hidden label into user view and visible status label out of view
        [UIView animateWithDuration:kNextStatusAnimationDuration
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             // move both status labels up
                             self.statusLabel1.frame = CGRectMake(self.statusLabel1.frame.origin.x,
                                                                  self.statusLabel1.frame.origin.y - kStatusBarHeight,
                                                                  self.statusLabel1.frame.size.width,
                                                                  self.statusLabel1.frame.size.height);
                             self.statusLabel2.frame = CGRectMake(self.statusLabel2.frame.origin.x,
                                                                  self.statusLabel2.frame.origin.y - kStatusBarHeight,
                                                                  self.statusLabel2.frame.size.width,
                                                                  self.statusLabel2.frame.size.height);
                         }
                         completion:^(BOOL finished) {
                             // add old message to history
                             [self addMessageToHistory:self.visibleStatusLabel.text];
                             
                             // after animation, set new hidden status label indicator
                             if (self.hiddenStatusLabel == self.statusLabel1) {
                                 self.hiddenStatusLabel = self.statusLabel2;
                             } else {
                                 self.hiddenStatusLabel = self.statusLabel1;
                             }
                             
                             // remove the message from the queue
                             @synchronized(self.messageQueue) {
                                 if (self.messageQueue.count > 0)
                                     [self.messageQueue removeLastObject];
                             }
                             
                             // inform delegate about message-switch
                             [self callDelegateWithNewMessage:message];
                             
                             // show the next message
                             [self performSelector:@selector(showNextMessage) withObject:nil afterDelay:kMinimumMessageVisibleTime];
                         }];
    }
    
    // w/o animation just save old text and set new one
    else {
        // add old message to history
        [self addMessageToHistory:self.visibleStatusLabel.text];
        // set new text
        self.visibleStatusLabel.text = message;
        // update progressView to only cover displayed text
        [self updateProgressViewSizeForLabel:self.visibleStatusLabel];
        
        // remove the message from the queue
        @synchronized(self.messageQueue) {
            if (self.messageQueue.count > 0)
                [self.messageQueue removeLastObject];
        }
        
        // inform delegate about message-switch
        [self callDelegateWithNewMessage:message];
        
        // show next message
        [self performSelector:@selector(showNextMessage) withObject:nil afterDelay:kMinimumMessageVisibleTime];
    }
    
    self.lastPostedMessage = message;
}

- (void)hide {
	[self.activityIndicator stopAnimating];
	self.statusLabel1.text = @"";
	self.statusLabel2.text = @"";
    
	self.hideInProgress = NO;
	// cancel previous hide- and clear requests
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil];
    
	// hide status bar overlay with animation
    [UIView animateWithDuration:self.shrinked ? 0. : kAppearAnimationDuration
                          delay:0 
                        options:UIViewAnimationOptionAllowUserInteraction 
                     animations:^{
		[self setHidden:YES useAlpha:YES];
	} completion:^(BOOL finished) {
		// call delegate
		if ([self.delegate respondsToSelector:@selector(statusBarOverlayDidHide)]) {
			[self.delegate statusBarOverlayDidHide];
		}
	}];
}

- (void)hideTemporary {
    self.forcedToHide = YES;
    
    // hide status bar overlay with animation
	[UIView animateWithDuration:self.shrinked ? 0. : kAppearAnimationDuration animations:^{
		[self setHidden:YES useAlpha:YES];
	}];
}
// this shows the status bar overlay, if there is text to show
- (void)show {
    self.forcedToHide = NO;
    
    if (self.reallyHidden) {
        if (self.visibleStatusLabel.text.length > 0) {
            // show status bar overlay with animation
            [UIView animateWithDuration:self.shrinked ? 0. : kAppearAnimationDuration animations:^{
                [self setHidden:NO useAlpha:YES];
            }];
        }
        
        [self showNextMessage];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Rotation
////////////////////////////////////////////////////////////////////////

- (void)layoutSubviews {
    NSLog(@"%@",@"layout");
}

- (void)didChangeStatusBarFrame:(NSNotification *)notification {
	NSValue * statusBarFrameValue = [notification.userInfo valueForKey:UIApplicationStatusBarFrameUserInfoKey];
    
	// have to use performSelector to prohibit animation of rotation
	[self performSelector:@selector(rotateToStatusBarFrame:) withObject:statusBarFrameValue afterDelay:0];
}

- (void)willChangeToSize:(NSNotification *)notification {
    CGSize size = [(NSValue *)notification.object CGSizeValue];
    [self changeFrameToFitWindowSize:size];
}

- (void)changeFrameToFitWindowSize:(CGSize)size {
    // current interface orientation
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    // is the statusBar visible before rotation?
    BOOL visibleBeforeTransformation = !self.reallyHidden;
    // store a flag, if the StatusBar is currently shrinked
    BOOL shrinkedBeforeTransformation = self.shrinked;
    
    CGFloat windowWidth = size.width;
    CGFloat windowHeight = size.height;
    
    // hide and then unhide after rotation
    if (visibleBeforeTransformation) {
        [self setHidden:YES useAlpha:YES];
    }
    NSLog(@"overlay : h%f, w%f", windowHeight, windowWidth);
    CGFloat pi = (CGFloat)M_PI;
    if (SYSTEM_VERSION_LESS_THAN(@"9") || (!IS_IPAD)) {
        if (orientation == UIDeviceOrientationPortrait) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,windowWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.0f, kWidthSmall, self.frame.size.height);
        }else if (orientation == UIDeviceOrientationLandscapeLeft) {
            self.transform = CGAffineTransformMakeRotation(pi * (90.f) / 180.0f);
            self.frame = CGRectMake((SYSTEM_VERSION_LESS_THAN(@"8")? windowWidth : windowHeight) - kStatusBarHeight, 0, kStatusBarHeight, windowHeight);
            self.smallFrame = CGRectMake(windowHeight-kWidthSmall,0,kWidthSmall,kStatusBarHeight);
        } else if (orientation == UIDeviceOrientationLandscapeRight) {
            self.transform = CGAffineTransformMakeRotation(pi * (-90.f) / 180.0f);
            self.frame = CGRectMake(0.f,0.f, kStatusBarHeight, SYSTEM_VERSION_LESS_THAN(@"8")?windowHeight : windowWidth);
            self.smallFrame = CGRectMake(windowHeight-kWidthSmall,0.f, kWidthSmall, kStatusBarHeight);
        } else if (orientation == UIDeviceOrientationPortraitUpsideDown) {
            self.transform = CGAffineTransformMakeRotation(pi);
            self.frame = CGRectMake(0.f,windowHeight - kStatusBarHeight,windowWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.f, kWidthSmall, self.frame.size.height);
        }
    } else {
        if (orientation == UIInterfaceOrientationPortrait) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,windowWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.0f, kWidthSmall, self.frame.size.height);
        }else if (orientation == UIInterfaceOrientationLandscapeLeft) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,windowWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(windowHeight-kWidthSmall,0,kWidthSmall,kStatusBarHeight);
        } else if (orientation == UIInterfaceOrientationLandscapeRight) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,windowWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(windowHeight-kWidthSmall,0.f, kWidthSmall, kStatusBarHeight);
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,windowWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.f, kWidthSmall, self.frame.size.height);
        }
    }
    
    
    self.backgroundView.frame = [self backgroundViewFrameForStatusBarInterfaceOrientationWithWindowSize:size];
    
    // if the statusBar is currently shrinked, update the frames for the new rotation state
    if (shrinkedBeforeTransformation) {
        // the oldBackgroundViewFrame is the frame of the whole StatusBar
        self.oldBackgroundViewFrame = CGRectMake(0.f,0.f,UIInterfaceOrientationIsPortrait(orientation) ? windowWidth : windowHeight,kStatusBarHeight);
        // the backgroundView gets the newly computed smallFrame
        self.backgroundView.frame = self.smallFrame;
    }
    
    // make visible after given time
    if (visibleBeforeTransformation) {
        // TODO:
        // somehow this doesn't work anymore since rotation-method was changed from
        // DeviceDidRotate-Notification to StatusBarFrameChanged-Notification
        // therefore iplemented it with a UIView-Animation instead
        //[self performSelector:@selector(setHiddenUsingAlpha:) withObject:[NSNumber numberWithBool:NO] afterDelay:kRotationAppearDelay];
        
        [UIView animateWithDuration:kAppearAnimationDuration
                              delay:kRotationAppearDelay
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [self setHiddenUsingAlpha:NO];
                         }
                         completion:NULL];
    }
}

- (void)rotateToStatusBarFrame:(NSValue *)statusBarFrameValue {
	// current interface orientation
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	// is the statusBar visible before rotation?
	BOOL visibleBeforeTransformation = !self.reallyHidden;
	// store a flag, if the StatusBar is currently shrinked
	BOOL shrinkedBeforeTransformation = self.shrinked;
    
    
	// hide and then unhide after rotation
	if (visibleBeforeTransformation) {
		[self setHidden:YES useAlpha:YES];
	}
    NSLog(@"overlay : w%f, h%f",kScreenWidth, kScreenHeight);
	CGFloat pi = (CGFloat)M_PI;
    if (SYSTEM_VERSION_LESS_THAN(@"9") || (!IS_IPAD)) {
        if (orientation == UIDeviceOrientationPortrait) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,kScreenWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.0f, kWidthSmall, self.frame.size.height);
        }else if (orientation == UIDeviceOrientationLandscapeLeft) {
            self.transform = CGAffineTransformMakeRotation(pi * (90.f) / 180.0f);
            self.frame = CGRectMake((SYSTEM_VERSION_LESS_THAN(@"8")? kScreenWidth : kScreenHeight) - kStatusBarHeight, 0, kStatusBarHeight, kScreenHeight);
            self.smallFrame = CGRectMake(kScreenHeight-kWidthSmall,0,kWidthSmall,kStatusBarHeight);
        } else if (orientation == UIDeviceOrientationLandscapeRight) {
            self.transform = CGAffineTransformMakeRotation(pi * (-90.f) / 180.0f);
            self.frame = CGRectMake(0.f,0.f, kStatusBarHeight, SYSTEM_VERSION_LESS_THAN(@"8")?kScreenHeight : kScreenWidth);
            self.smallFrame = CGRectMake(kScreenHeight-kWidthSmall,0.f, kWidthSmall, kStatusBarHeight);
        } else if (orientation == UIDeviceOrientationPortraitUpsideDown) {
            self.transform = CGAffineTransformMakeRotation(pi);
            self.frame = CGRectMake(0.f,kScreenHeight - kStatusBarHeight,kScreenWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.f, kWidthSmall, self.frame.size.height);
        }
    } else {
        if (orientation == UIInterfaceOrientationPortrait) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,kScreenWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.0f, kWidthSmall, self.frame.size.height);
        }else if (orientation == UIInterfaceOrientationLandscapeLeft) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,kScreenWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(kScreenHeight-kWidthSmall,0,kWidthSmall,kStatusBarHeight);
        } else if (orientation == UIInterfaceOrientationLandscapeRight) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,kScreenWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(kScreenHeight-kWidthSmall,0.f, kWidthSmall, kStatusBarHeight);
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            self.transform = CGAffineTransformIdentity;
            self.frame = CGRectMake(0.f,0.f,kScreenWidth,kStatusBarHeight);
            self.smallFrame = CGRectMake(self.frame.size.width - kWidthSmall, 0.f, kWidthSmall, self.frame.size.height);
        }
    }
	
    
    self.backgroundView.frame = [self backgroundViewFrameForStatusBarInterfaceOrientation];
    
	// if the statusBar is currently shrinked, update the frames for the new rotation state
	if (shrinkedBeforeTransformation) {
		// the oldBackgroundViewFrame is the frame of the whole StatusBar
		self.oldBackgroundViewFrame = CGRectMake(0.f,0.f,UIInterfaceOrientationIsPortrait(orientation) ? kScreenWidth : kScreenHeight,kStatusBarHeight);
		// the backgroundView gets the newly computed smallFrame
		self.backgroundView.frame = self.smallFrame;
	}
    
	// make visible after given time
	if (visibleBeforeTransformation) {
		// TODO:
		// somehow this doesn't work anymore since rotation-method was changed from
		// DeviceDidRotate-Notification to StatusBarFrameChanged-Notification
		// therefore iplemented it with a UIView-Animation instead
		//[self performSelector:@selector(setHiddenUsingAlpha:) withObject:[NSNumber numberWithBool:NO] afterDelay:kRotationAppearDelay];
        
		[UIView animateWithDuration:kAppearAnimationDuration
							  delay:kRotationAppearDelay
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^{
							 [self setHiddenUsingAlpha:NO];
                         }
						 completion:NULL];
	}
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Setter/Getter
////////////////////////////////////////////////////////////////////////

- (void)setProgress:(double)progress {
    // bound progress to 0.0 - 1.0
    progress = MAX(0.0, MIN(progress, 1.0));
    
    // do not decrease progress if it is no reset
    if (progress == 0.0 || progress > progress_) {
        progress_ = progress;
    }
    
    // update UI on main thread
    [self performSelectorOnMainThread:@selector(updateProgressViewSizeForLabel:) withObject:self.visibleStatusLabel waitUntilDone:NO];
}

- (void)setAnimation:(MTStatusBarOverlayAnimation)animation {
	animation_ = animation;
}

- (BOOL)isShrinked {
	return self.backgroundView.frame.size.width == self.smallFrame.size.width;
}

- (void)setShrinked:(BOOL)shrinked animated:(BOOL)animated {
	[UIView animateWithDuration:animated ? kAnimationDurationShrink : 0.
					 animations:^{
						 // shrink the overlay
						 if (shrinked) {
							 self.oldBackgroundViewFrame = self.backgroundView.frame;
							 self.backgroundView.frame = self.smallFrame;
                             
							 self.statusLabel1.hidden = YES;
							 self.statusLabel2.hidden = YES;
						 }
						 // expand the overlay
						 else {
							 self.backgroundView.frame = self.oldBackgroundViewFrame;
                             
							 self.statusLabel1.hidden = NO;
							 self.statusLabel2.hidden = NO;
                             
                             if ([activityIndicator_ respondsToSelector:@selector(setColor:)]) {
                                 CGRect frame = self.statusLabel1.frame;
                                 frame.size.width = self.backgroundView.frame.size.width-60.f;
                                 self.statusLabel1.frame = frame;
                                 
                                 frame = self.statusLabel2.frame;
                                 frame.size.width = self.backgroundView.frame.size.width-60.f;
                                 self.statusLabel2.frame = frame;
                             }
						 }
                         
						 // update status bar background
						 [self setStatusBarBackground];
					 }];
}


- (UILabel *)visibleStatusLabel {
	if (self.hiddenStatusLabel == self.statusLabel1) {
		return self.statusLabel2;
	}
    
	return self.statusLabel1;
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Gesture Recognizer
////////////////////////////////////////////////////////////////////////

- (void)contentViewClicked:(UIGestureRecognizer *)gestureRecognizer {
	if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        // if we are currently in a special state, restore to normal
        // and ignore current set animation in that case
        if (self.shrinked) {
            [self setShrinked:NO animated:YES];
        } else {
            // normal case/status, do what's specified in animation-state
            switch (self.animation) {
                case MTStatusBarOverlayAnimationShrink:
                    [self setShrinked:!self.shrinked animated:YES];
                    break;

                case MTStatusBarOverlayAnimationNone:
                    // ignore
                    break;
            }
        }
        
		if ([self.delegate respondsToSelector:@selector(statusBarOverlayDidRecognizeGesture:)]) {
			[self.delegate statusBarOverlayDidRecognizeGesture:gestureRecognizer];
		}
	}
}


////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIApplication Notifications
////////////////////////////////////////////////////////////////////////

- (void)applicationWillResignActive:(NSNotification *)notifaction {
    // We hide temporary when the application resigns active s.t the overlay
    // doesn't overlay the Notification Center. Let's hope this helps AppStore 
    // Approval ...
    [self hideTemporary];
}

- (void)applicationDidBecomeActive:(NSNotification *)notifaction {
    [self show];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Methods
////////////////////////////////////////////////////////////////////////


- (void)updateColor {
    // Images used as background when status bar style is Default
    defaultStatusBarImage_ = [S1Global imageWithColor:kBackgroundColor];
    defaultStatusBarImageShrinked_ = [S1Global imageWithColor:kBackgroundColor];
    [self setStatusBarBackground];
    [self setColorSchemeForMessageType:self.messageType];
}

- (void)setStatusBarBackground {
	// gray status bar?
	// on iPad the Default Status Bar Style is black too
    if (self.shrinked) {
        self.statusBarBackgroundImageView.image = [self.defaultStatusBarImageShrinked stretchableImageWithLeftCapWidth:2.0f topCapHeight:0.0f];
    } else {
        self.statusBarBackgroundImageView.image = [self.defaultStatusBarImage stretchableImageWithLeftCapWidth:2.0f topCapHeight:0.0f];
    }
    statusBarBackgroundImageView_.backgroundColor = [UIColor clearColor];
	
}

- (void)setColorSchemeForMessageType:(MTMessageType)messageType {
	// gray status bar?
	// on iPad the Default Status Bar Style is black too
	
    // set color of labels depending on messageType
    self.messageType = messageType;
    switch(messageType) {
        case MTMessageTypeFinish:
            self.statusLabel1.textColor = kFinishedMessageTextColor;
            self.statusLabel2.textColor = kFinishedMessageTextColor;
            self.finishedLabel.textColor = kFinishedMessageTextColor;
            break;
        case MTMessageTypeError:
            self.statusLabel1.textColor = kErrorMessageTextColor;
            self.statusLabel2.textColor = kErrorMessageTextColor;
            self.finishedLabel.textColor = kErrorMessageTextColor;
            break;
        default:
            self.statusLabel1.textColor = kTextColor;
            self.statusLabel2.textColor = kTextColor;
            self.finishedLabel.textColor = kTextColor;
            break;
    }
    self.activityIndicator.activityIndicatorViewStyle = kActivityIndicatorViewStyle;
    [self.activityIndicator setColor:kTextColor];
    

    self.progressView.backgroundColor = [UIColor clearColor];
    self.progressView.image = [self.defaultStatusBarImageShrinked stretchableImageWithLeftCapWidth:2.0f topCapHeight:0.0f];

    //self.progressView.backgroundColor = kProgressViewBackgroundColor;
    //self.progressView.image = nil;

}

- (void)updateUIForMessageType:(MTMessageType)messageType duration:(NSTimeInterval)duration {
	// set properties depending on message-type
	switch (messageType) {
		case MTMessageTypeActivity:
			// will not call hide after delay
			self.hideInProgress = NO;
			// show activity indicator, hide finished-label
			self.finishedLabel.hidden = YES;
			self.activityIndicator.hidden = self.hidesActivity;
            
			// start activity indicator
			if (!self.hidesActivity) {
				[self.activityIndicator startAnimating];
			}
			break;
		case MTMessageTypeFinish:
			// will call hide after delay
			self.hideInProgress = YES;
			// show finished-label, hide acitvity indicator
			self.finishedLabel.hidden = self.hidesActivity;
			self.activityIndicator.hidden = YES;
            
			// stop activity indicator
			[self.activityIndicator stopAnimating];
            
			// update font and text
			self.finishedLabel.font = [UIFont systemFontOfSize:kFinishedFontSize];
			self.finishedLabel.text = kFinishedText;
            self.progress = 1.0;
			break;
		case MTMessageTypeError:
			// will call hide after delay
			self.hideInProgress = YES;
			// show finished-label, hide activity indicator
			self.finishedLabel.hidden = self.hidesActivity;
			self.activityIndicator.hidden = YES;
            
			// stop activity indicator
			[self.activityIndicator stopAnimating];
            
			// update font and text
			self.finishedLabel.font = [UIFont boldSystemFontOfSize:kErrorFontSize];
			self.finishedLabel.text = kErrorText;
            self.progress = 1.0;
			break;
	}
    
    // if a duration is specified, hide after given duration
    if (duration > 0.) {
        // hide after duration
        [self performSelector:@selector(hide) withObject:nil afterDelay:duration];
        // clear history after duration
        [self performSelector:@selector(clearHistory) withObject:nil afterDelay:duration];
    }
}

- (void)callDelegateWithNewMessage:(NSString *)newMessage {
	if ([self.delegate respondsToSelector:@selector(statusBarOverlayDidSwitchFromOldMessage:toNewMessage:)]) {
		NSString *oldMessage = nil;
        
		if (self.messageHistory.count > 0) {
			oldMessage = [self.messageHistory lastObject];
		}
        
		[self.delegate statusBarOverlayDidSwitchFromOldMessage:oldMessage
												  toNewMessage:newMessage];
	}
}

- (void)updateProgressViewSizeForLabel:(UILabel *)label {
    if (self.progress < 1.) {
        CGSize size = [label sizeThatFits:label.frame.size];
        CGFloat width = size.width * (float)(1. - self.progress);
        CGFloat x = label.center.x + size.width/2.f - width;
        
        // if we werent able to determine a size, do nothing
        if (size.width == 0.f) {
            return;
        }
        
        // progressView always covers only the visible portion of the text
        // it "shrinks" to the right with increased progress to reveal more
        // text under it
        self.progressView.hidden = NO;
        //[UIView animateWithDuration:self.progress > 0.0 ? kUpdateProgressViewDuration : 0.0
        //                 animations:^{
        self.progressView.frame = CGRectMake(x, self.progressView.frame.origin.y,
                                             self.backgroundView.frame.size.width-x, self.progressView.frame.size.height);
        //                 }];
    } else {
        self.progressView.hidden = YES;
    }
}

- (CGRect)backgroundViewFrameForStatusBarInterfaceOrientation{
    
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    return (UIInterfaceOrientationIsLandscape(interfaceOrientation) ? 
            CGRectMake(0, 0, SYSTEM_VERSION_LESS_THAN(@"8")?kScreenHeight : kScreenWidth, kStatusBarHeight) :
            CGRectMake(0, 0, kScreenWidth, kStatusBarHeight));
}

- (CGRect)backgroundViewFrameForStatusBarInterfaceOrientationWithWindowSize:(CGSize)size{
    
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    return (UIInterfaceOrientationIsLandscape(interfaceOrientation) ?
            CGRectMake(0, 0, SYSTEM_VERSION_LESS_THAN(@"8")?size.height : size.width, kStatusBarHeight) :
            CGRectMake(0, 0, size.width, kStatusBarHeight));
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark History Tracking
////////////////////////////////////////////////////////////////////////

- (void)addMessageToHistory:(NSString *)message {
	if (message != nil
		&& [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length > 0) {
		// add message to history-array
		[self.messageHistory addObject:message];
	}
}

- (void)clearHistory {
	[self.messageHistory removeAllObjects];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Custom Hide Methods
////////////////////////////////////////////////////////////////////////

// used for performSelector:withObject
- (void)setHiddenUsingAlpha:(BOOL)hidden {
	[self setHidden:hidden useAlpha:YES];
}

- (void)setHidden:(BOOL)hidden useAlpha:(BOOL)useAlpha {
	if (useAlpha) {
		self.alpha = hidden ? 0.f : 1.f;
	} else {
		self.hidden = hidden;
	}
}

- (BOOL)isReallyHidden {
	return self.alpha == 0.f || self.hidden;
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Singleton Definitions
////////////////////////////////////////////////////////////////////////

+ (MTStatusBarOverlay *)sharedInstance {
    static dispatch_once_t pred;
    __strong static MTStatusBarOverlay *sharedOverlay = nil; 
    
    dispatch_once(&pred, ^{ 
        sharedOverlay = [[MTStatusBarOverlay alloc] init]; 
    }); 
    
	return sharedOverlay;
}

@end


////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Helper
////////////////////////////////////////////////////////////////////////


void mt_dispatch_sync_on_main_thread(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
