#import "libactivator.h"
#import "libactivator-private.h"
#import "LAToggleListener.h"
#import "LAMenuListener.h"

#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>

#include <dlfcn.h>

NSString * const LAEventNameMenuPressAtSpringBoard = @"libactivator.menu.press.at-springboard";
NSString * const LAEventNameMenuPressSingle        = @"libactivator.menu.press.single";
NSString * const LAEventNameMenuPressDouble        = @"libactivator.menu.press.double";
NSString * const LAEventNameMenuHoldShort          = @"libactivator.menu.hold.short";

NSString * const LAEventNameLockHoldShort          = @"libactivator.lock.hold.short";
NSString * const LAEventNameLockPressDouble        = @"libactivator.lock.press.double";

NSString * const LAEventNameSpringBoardPinch       = @"libactivator.springboard.pinch";
NSString * const LAEventNameSpringBoardSpread      = @"libactivator.springboard.spread";

NSString * const LAEventNameStatusBarSwipeRight    = @"libactivator.statusbar.swipe.right";
NSString * const LAEventNameStatusBarSwipeLeft     = @"libactivator.statusbar.swipe.left";
NSString * const LAEventNameStatusBarSwipeDown     = @"libactivator.statusbar.swipe.down";
NSString * const LAEventNameStatusBarTapDouble     = @"libactivator.statusbar.tap.double";
NSString * const LAEventNameStatusBarHold          = @"libactivator.statusbar.hold";

NSString * const LAEventNameVolumeDownUp           = @"libactivator.volume.down-up";
NSString * const LAEventNameVolumeUpDown           = @"libactivator.volume.up-down";
NSString * const LAEventNameVolumeDisplayTap       = @"libactivator.volume.display-tap";
NSString * const LAEventNameVolumeToggleMuteTwice  = @"libactivator.volume.toggle-mute-twice";
NSString * const LAEventNameVolumeDownHoldShort    = @"libactivator.volume.down.hold.short";
NSString * const LAEventNameVolumeUpHoldShort      = @"libactivator.volume.up.hold.short";
NSString * const LAEventNameVolumeBothPress        = @"libactivator.volume.both.press";

NSString * const LAEventNameSlideInFromBottom      = @"libactivator.slide-in.bottom";
NSString * const LAEventNameSlideInFromBottomLeft  = @"libactivator.slide-in.bottom-left";
NSString * const LAEventNameSlideInFromBottomRight = @"libactivator.slide-in.bottom-right";

NSString * const LAEventNameMotionShake            = @"libactivator.motion.shake";

NSString * const LAEventNameHeadsetButtonPressSingle = @"libactivator.headset-button.press.single";
NSString * const LAEventNameHeadsetButtonHoldShort = @"libactivator.headset-button.hold.short";

NSString * const LAEventNameLockScreenClockDoubleTap = @"libactivator.lockscreen.clock.double-tap";

NSString * const LAEventNamePowerConnected         = @"libactivator.power.connected";
NSString * const LAEventNamePowerDisconnected      = @"libactivator.power.disconnected";

#define kSpringBoardPinchThreshold         0.95f
#define kSpringBoardSpreadThreshold        1.05f
#define kButtonHoldDelay                   0.8f
#define kStatusBarHorizontalSwipeThreshold 50.0f
#define kStatusBarVerticalSwipeThreshold   10.0f
#define kStatusBarHoldDelay                0.5f
#define kSlideGestureWindowHeight          13.0f
#define kWindowLevelTransparentTopMost     9999.0f
#define kShakeIgnoreTimeout                2.0
#define kAlmostTransparentColor            [[UIColor grayColor] colorWithAlphaComponent:(2.0f / 255.0f)]

CHDeclareClass(SpringBoard);
CHDeclareClass(iHome);
CHDeclareClass(SBUIController);
CHDeclareClass(SBScreenShotter);
CHDeclareClass(SBIconController);
CHDeclareClass(SBIconScrollView);
CHDeclareClass(SBIcon);
CHDeclareClass(SBStatusBar);
CHDeclareClass(UIStatusBar);
CHDeclareClass(SBNowPlayingAlertItem);
CHDeclareClass(SBVoiceControlAlert);
CHDeclareClass(SBAwayController);
CHDeclareClass(SBAwayDateView);
CHDeclareClass(VolumeControl);
CHDeclareClass(SBVolumeHUDView);
CHDeclareClass(SBStatusBarController);
CHDeclareClass(SBAppSwitcherController);
CHDeclareClass(SBRemoteLocalNotificationAlert);
CHDeclareClass(SBAlertItemsController);
CHDeclareClass(SBAlert);

//static BOOL isInSleep;

static BOOL shouldInterceptMenuPresses;
static BOOL shouldSuppressMenuReleases;
static BOOL shouldSuppressLockSound;

static LASlideGestureWindow *leftSlideGestureWindow;
static LASlideGestureWindow *middleSlideGestureWindow;
static LASlideGestureWindow *rightSlideGestureWindow;

static LAQuickDoDelegate *sharedQuickDoDelegate;
static UIButton *quickDoButton;

CHInline
static LAEvent *LASendEventWithName(NSString *eventName)
{
	LAEvent *event = [[[LAEvent alloc] initWithName:eventName mode:[LASharedActivator currentEventMode]] autorelease];
	[LASharedActivator sendEventToListener:event];
	return event;
}

CHInline
static void LAAbortEvent(LAEvent *event)
{
	[LASharedActivator sendAbortToListener:event];
}

CHInline
static id<LAListener> LAListenerForEventWithName(NSString *eventName)
{
	return [LASharedActivator listenerForEvent:[LAEvent eventWithName:eventName mode:[LASharedActivator currentEventMode]]];
}

@interface SpringBoard (OS40)
- (void)resetIdleTimerAndUndim;
@end

@interface SBAwayController (OS40)
- (void)_unlockWithSound:(BOOL)sound isAutoUnlock:(BOOL)unlock;
@end

@interface VolumeControl (OS40)
+ (float)volumeStep;
- (void)_changeVolumeBy:(float)volumeAdjust;
- (void)hideVolumeHUDIfVisible;
@end

@interface SBIconController (OS40)
- (id)currentFolderIconList;
@end

@interface SBUIController (OS40)
- (BOOL)isSwitcherShowing;
@end

@interface SBAppSwitcherController : NSObject {
}
- (NSDictionary *)_currentIcons;
@end

@interface SBVolumeHUDView : UIView {
}
@end

@interface SBRemoteLocalNotificationAlert : SBAlertItem {
}
+ (BOOL)isPlayingRingtone;
+ (void)stopPlayingAlertSoundOrRingtone;
@end

@interface SBAlertItemsController (OS40)
- (NSArray *)alertItemsOfClass:(Class)aClass;
@end

static void HideVolumeHUD(VolumeControl *volumeControl)
{
	if ([volumeControl respondsToSelector:@selector(hideVolumeHUDIfVisible)])
		[volumeControl hideVolumeHUDIfVisible];
	else
		[volumeControl hideHUD];
}

__attribute__((visibility("hidden")))
@interface LAVersionChecker : NSObject<UIAlertViewDelegate> {
}
@end

typedef enum {
	LASystemVersionStatusJustRight,
	LASystemVersionStatusTooCold,
	LASystemVersionStatusTooHot,
} LAVersionStatus;

@implementation LAVersionChecker

+ (LAVersionStatus)systemVersionStatus
{
	NSArray *components = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
	switch ([[components objectAtIndex:0] integerValue]) {
		case 0:
		case 1:
		case 2:
			return LASystemVersionStatusTooCold;
		case 3:
			return LASystemVersionStatusJustRight;
			//return [[components objectAtIndex:1] integerValue] == 0 ? LASystemVersionStatusTooCold : LASystemVersionStatusJustRight;
		case 4:
			return [[components objectAtIndex:1] integerValue] <= 3 ? LASystemVersionStatusJustRight : LASystemVersionStatusTooHot;
		default:
			return LASystemVersionStatusTooHot;
	}
}

+ (NSString *)versionKey
{
	return [@"LASystemVersionPrompt-" stringByAppendingString:[UIDevice currentDevice].systemVersion];
}

+ (void)checkVersion
{
	NSString *title;
	NSString *message;
	switch ([self systemVersionStatus]) {
		case LASystemVersionStatusTooCold:
			title = [LASharedActivator localizedStringForKey:@"OUT_OF_DATE_TITLE" value:@"System Version Out Of Date"];
			message = [LASharedActivator localizedStringForKey:@"OUT_OF_DATE_MESSAGE" value:@"Activator performs best on a modern version of iOS.\nPlease consider upgrading."];
			break;
		case LASystemVersionStatusTooHot:
			title = [LASharedActivator localizedStringForKey:@"TOO_NEW_TITLE" value:@"System Version Too New"];
			message = [LASharedActivator localizedStringForKey:@"TOO_NEW_MESSAGE" value:@"Activator has not been tested with this version of iOS.\nSome features may not work as intended."];
			break;
		default:
			return;
	}
	// Try to determine if we're locked, but be very careful not to call private APIs if they don't exist
	BOOL showMoreInfo = NO;
	if ([CHClass(SBAwayController) respondsToSelector:@selector(sharedAwayController)]) {
		SBAwayController *awayController = [CHClass(SBAwayController) sharedAwayController];
		if ([awayController respondsToSelector:@selector(isLocked)]) {
			if ([awayController isLocked]) {
				[self performSelector:@selector(checkVersion) withObject:nil afterDelay:0.1];
				return;
			} else {
				showMoreInfo = YES;
			}
		}
	}
	NSString *cancelButton;
	switch ([[LASharedActivator _getObjectForPreference:[self versionKey]] integerValue]) {
		case 0:
			cancelButton = [LASharedActivator localizedStringForKey:@"VERSION_PROMPT_CONTINUE" value:@"Continue"];
			break;
		case 1:
			cancelButton = [LASharedActivator localizedStringForKey:@"VERSION_PROMPT_IGNORE" value:@"Ignore"];
			break;
		default:
			return;
	}
	UIAlertView *av = [[UIAlertView alloc] init];
	av.title = title;
	av.message = message;
	av.delegate = self;
	if (showMoreInfo)
		[av addButtonWithTitle:[LASharedActivator localizedStringForKey:@"VERSION_PROMPT_MORE_INFO" value:@"More Info"]];
	[av setCancelButtonIndex:[av addButtonWithTitle:cancelButton]];
	[av show];
	[av release];
}

+ (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == alertView.cancelButtonIndex) {
		NSString *versionKey = [self versionKey];
		NSNumber *value = [LASharedActivator _getObjectForPreference:versionKey];
		value = [NSNumber numberWithInteger:[value integerValue]+1];
		[LASharedActivator _setObject:value forPreference:versionKey];
	} else {
		NSURL *url = [NSURL URLWithString:@"http://rpetri.ch/cydia/activator/systemversionfail/"];
		SpringBoard *app = (SpringBoard *)[UIApplication sharedApplication];
		if ([app respondsToSelector:@selector(applicationOpenURL:)])
			[app applicationOpenURL:url];
		else
			[app openURL:url];
	}
}

@end

@implementation LASlideGestureWindow

+ (LASlideGestureWindow *)leftWindow
{
	if (!leftSlideGestureWindow) {
		CGRect frame = [[UIScreen mainScreen] bounds];
		frame.origin.y += frame.size.height - kSlideGestureWindowHeight;
		frame.size.height = kSlideGestureWindowHeight;
		frame.size.width *= 0.25f;
		leftSlideGestureWindow = [[LASlideGestureWindow alloc] initWithFrame:frame eventName:LAEventNameSlideInFromBottomLeft];
	}
	return leftSlideGestureWindow;
}

+ (LASlideGestureWindow *)middleWindow
{
	if (!middleSlideGestureWindow) {
		CGRect frame = [[UIScreen mainScreen] bounds];
		frame.origin.y += frame.size.height - kSlideGestureWindowHeight;
		frame.size.height = kSlideGestureWindowHeight;
		frame.origin.x += frame.size.width * 0.25f;
		frame.size.width *= 0.5f;
		middleSlideGestureWindow = [[LASlideGestureWindow alloc] initWithFrame:frame eventName:LAEventNameSlideInFromBottom];
	}
	return middleSlideGestureWindow;
}

+ (LASlideGestureWindow *)rightWindow
{
	if (!rightSlideGestureWindow) {
		CGRect frame = [[UIScreen mainScreen] bounds];
		frame.origin.y += frame.size.height - kSlideGestureWindowHeight;
		frame.size.height = kSlideGestureWindowHeight;
		frame.origin.x += frame.size.width * 0.75f;
		frame.size.width *= 0.25f;
		rightSlideGestureWindow = [[LASlideGestureWindow alloc] initWithFrame:frame eventName:LAEventNameSlideInFromBottomRight];
	}
	return rightSlideGestureWindow;
}

+ (void)updateVisibility
{
	if (!quickDoButton) {
		[[LASlideGestureWindow leftWindow] updateVisibility];
		[[LASlideGestureWindow middleWindow] updateVisibility];
		[[LASlideGestureWindow rightWindow] updateVisibility];
	} else {
		[leftSlideGestureWindow setHidden:YES];
		[middleSlideGestureWindow setHidden:YES];
		[rightSlideGestureWindow setHidden:YES];
	}
}

- (id)initWithFrame:(CGRect)frame eventName:(NSString *)eventName
{
	if ((self = [super initWithFrame:frame])) {
		_eventName = [eventName copy];
		[self setWindowLevel:kWindowLevelTransparentTopMost];
		[self setBackgroundColor:kAlmostTransparentColor];
	}
	return self;
}

- (void)handleStatusBarChangeFromHeight:(CGFloat)fromHeight toHeight:(CGFloat)toHeight
{
	// Do Nothing
}

- (void)updateVisibility
{
	[self setHidden:[LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName]] == nil];
}

- (void)dealloc
{
	[_eventName release];
	[super dealloc];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	hasSentSlideEvent = NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!hasSentSlideEvent) {
		UITouch *touch = [touches anyObject];
		CGPoint location = [touch locationInView:self];
		if (location.y < -50.0f) {
			hasSentSlideEvent = YES;
			LASendEventWithName(_eventName);
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (hasSentSlideEvent)
		hasSentSlideEvent = NO;
	else {
		UITouch *touch = [touches anyObject];
		CGPoint location = [touch locationInView:self];
		if (location.y < -50.0f)
			LASendEventWithName(_eventName);
	}
}

@end

@implementation LAQuickDoDelegate

+ (id)sharedInstance
{
	if (!sharedQuickDoDelegate)
		sharedQuickDoDelegate = [[self alloc] init];
	return sharedQuickDoDelegate;
}

- (void)controlTouchesBegan:(UIControl *)control withEvent:(UIEvent *)event
{
	hasSentSlideEvent = NO;
}

- (void)controlTouchesMoved:(UIControl *)control withEvent:(UIEvent *)event
{
	if (!hasSentSlideEvent) {
		hasSentSlideEvent = YES;
		UITouch *touch = [[event allTouches] anyObject];
		CGFloat xFactor = [touch locationInView:control].x / [control bounds].size.width;
		if (xFactor < 0.25f)
			LASendEventWithName(LAEventNameSlideInFromBottomLeft);
		else if (xFactor < 0.75f)
			LASendEventWithName(LAEventNameSlideInFromBottom);
		else
			LASendEventWithName(LAEventNameSlideInFromBottomRight);
	}
}

- (void)controlTouchesEnded:(UIControl *)control withEvent:(UIEvent *)event
{
	hasSentSlideEvent = NO;
}

- (void)acceptEventsFromControl:(UIControl *)control
{
	[control addTarget:self action:@selector(controlTouchesBegan:withEvent:) forControlEvents:UIControlEventTouchDown];
	[control addTarget:self action:@selector(controlTouchesMoved:withEvent:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
	[control addTarget:self action:@selector(controlTouchesEnded:withEvent:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

@end

static LAVolumeTapWindow *volumeTapWindow;

static void ShowVolumeTapWindow(UIView *view)
{
	if ([LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:LAEventNameVolumeDisplayTap]]) {
		UIWindow *window = [view window];
		CGRect frame = [view convertRect:view.bounds toView:window];
		CGPoint windowPosition = window.frame.origin;
		frame.origin.x += windowPosition.x;
		frame.origin.y += windowPosition.y;
		if (volumeTapWindow)
			volumeTapWindow.frame = frame;
		else {
			volumeTapWindow = [[LAVolumeTapWindow alloc] initWithFrame:frame];
			[volumeTapWindow setWindowLevel:kWindowLevelTransparentTopMost];
			[volumeTapWindow setBackgroundColor:kAlmostTransparentColor]; // Content seems to be required for swipe gestures to work in-app
		}
		[volumeTapWindow setHidden:NO];
	}
}

static void HideVolumeTapWindow()
{
	[volumeTapWindow setHidden:YES];
	[volumeTapWindow release];
	volumeTapWindow = nil;
}

@implementation LAVolumeTapWindow

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	HideVolumeTapWindow();
	if ([LASendEventWithName(LAEventNameVolumeDisplayTap) isHandled])
		HideVolumeHUD([CHClass(VolumeControl) sharedVolumeControl]);
}

@end

static CFAbsoluteTime lastRingerChangedTime;

CHOptimizedMethod(1, self, void, SpringBoard, ringerChanged, int, newState)
{
	CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
	BOOL shouldSendEvent = (currentTime - lastRingerChangedTime) < 1.0;
	lastRingerChangedTime = currentTime;
	if (shouldSendEvent) {
		CHSuper(1, SpringBoard, ringerChanged, newState);
		LASendEventWithName(LAEventNameVolumeToggleMuteTwice);
	} else {
		CHSuper(1, SpringBoard, ringerChanged, newState);
	}
}

/*CHOptimizedMethod(0, self, void, SpringBoard, systemWillSleep)
{
	isInSleep = YES;
	CHSuper(0, SpringBoard, systemWillSleep);
}

CHOptimizedMethod(0, self, void, SpringBoard, undim)
{
	isInSleep = NO;
	CHSuper(0, SpringBoard, undim);
}*/

static BOOL ignoreHeadsetButtonUp;

CHOptimizedMethod(0, self, void, SpringBoard, _performDelayedHeadsetAction)
{
	if (LASendEventWithName(LAEventNameHeadsetButtonHoldShort).handled)
		ignoreHeadsetButtonUp = YES;
	else
		CHSuper(0, SpringBoard, _performDelayedHeadsetAction);
}

CHOptimizedMethod(1, self, void, SpringBoard, headsetButtonDown, GSEventRef, gsEvent)
{
	ignoreHeadsetButtonUp = NO;
	if (LAListenerForEventWithName(LAEventNameHeadsetButtonHoldShort)) {
		CHSuper(1, SpringBoard, headsetButtonDown, gsEvent);
		// Require _performDelayedHeadsetAction timer, event when Voice Control isn't available
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_performDelayedHeadsetAction) object:nil];
		[self performSelector:@selector(_performDelayedHeadsetAction) withObject:nil afterDelay:0.8];
	} else {
		CHSuper(1, SpringBoard, headsetButtonDown, gsEvent);
	}
}

CHOptimizedMethod(1, self, void, SpringBoard, headsetButtonUp, GSEventRef, gsEvent)
{
	if (!ignoreHeadsetButtonUp) {
		LAEvent *event = [LAEvent eventWithName:LAEventNameHeadsetButtonPressSingle mode:[LASharedActivator currentEventMode]];
		[LASharedActivator sendDeactivateEventToListeners:event];
		if (!event.handled) {
			[LASharedActivator sendEventToListener:event];
			if (!event.handled) {
				CHSuper(1, SpringBoard, headsetButtonUp, gsEvent);
				return;
			}
		}
	}
	// Cleanup hold events
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_performDelayedHeadsetAction) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_performDelayedHeadsetClickTimeout) object:nil];
}

CHOptimizedMethod(0, self, void, SpringBoard, _handleMenuButtonEvent)
{
	if (!shouldSuppressMenuReleases) {
		// Unfortunately there isn't a better way of doing this :(
		shouldInterceptMenuPresses = YES;
		CHSuper(0, SpringBoard, _handleMenuButtonEvent);
		shouldInterceptMenuPresses = NO;
	}
}

CHOptimizedMethod(1, self, BOOL, SpringBoard, respondImmediatelyToMenuSingleTapAllowingDoubleTap, BOOL *, allowDoubleTap)
{
	// 3.2
	if (LAListenerForEventWithName(LAEventNameMenuPressDouble)) {
		CHSuper(1, SpringBoard, respondImmediatelyToMenuSingleTapAllowingDoubleTap, allowDoubleTap);
		if (allowDoubleTap)
			*allowDoubleTap = YES;
		return NO;
	} else {
		return CHSuper(1, SpringBoard, respondImmediatelyToMenuSingleTapAllowingDoubleTap, allowDoubleTap);
	}
}

CHOptimizedMethod(0, self, BOOL, SpringBoard, allowMenuDoubleTap)
{
	// 3.0/3.1
	if (LAListenerForEventWithName(LAEventNameMenuPressDouble)) {
		CHSuper(0, SpringBoard, allowMenuDoubleTap);
		return YES;
	} else {
		return CHSuper(0, SpringBoard, allowMenuDoubleTap);
	}
}

CHOptimizedMethod(0, self, void, SpringBoard, handleMenuDoubleTap)
{
	if ([self canShowNowPlayingHUD]) {
		shouldAddNowPlayingButton = YES;
		CHSuper(0, SpringBoard, handleMenuDoubleTap);
		shouldAddNowPlayingButton = NO;
	} else if ([LASendEventWithName(LAEventNameMenuPressDouble) isHandled]) {
		shouldSuppressMenuReleases = YES;
	} else {
		CHSuper(0, SpringBoard, handleMenuDoubleTap);
	}
}

static LAEvent *lockHoldEventToAbort;
static BOOL isWaitingForLockDoubleTap;
static NSString *formerLockEventMode;
static BOOL suppressIsLocked;

CHOptimizedMethod(0, self, BOOL, SpringBoard, isLocked)
{
	if (suppressIsLocked) {
		CHSuper(0, SpringBoard, isLocked);
		return NO;
	} else {
		return CHSuper(0, SpringBoard, isLocked);
	}
}

CHOptimizedMethod(1, self, void, SpringBoard, lockButtonDown, GSEventRef, event)
{
	[self performSelector:@selector(activatorLockButtonHoldCompleted) withObject:nil afterDelay:kButtonHoldDelay];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorLockButtonDoubleTapAborted) object:nil];
	if (!isWaitingForLockDoubleTap) {
		[formerLockEventMode release];
		formerLockEventMode = [[LASharedActivator currentEventMode] copy];
	}
	CHSuper(1, SpringBoard, lockButtonDown, event);
}

CHOptimizedMethod(0, new, void, SpringBoard, activatorFixStatusBar)
{
	[[CHClass(SBStatusBarController) sharedStatusBarController] setIsLockVisible:NO isTimeVisible:YES];
}

static BOOL ignoreResetIdleTimerAndUndim;

CHOptimizedMethod(1, self, void, SpringBoard, resetIdleTimerAndUndim, BOOL, something)
{
	if (!ignoreResetIdleTimerAndUndim)
		CHSuper(1, SpringBoard, resetIdleTimerAndUndim, something);
}

static void DisableLockTimer(SpringBoard *springBoard)
{
	if ([springBoard respondsToSelector:@selector(_setLockButtonTimer:)])
		[springBoard _setLockButtonTimer:nil];
	else {
		NSTimer **timer = CHIvarRef(springBoard, _lockButtonTimer, NSTimer *);
		if (timer) {
			[*timer invalidate];
			[*timer release];
			*timer = nil;
		}
	}
}

CHOptimizedMethod(1, self, void, SpringBoard, lockButtonUp, GSEventRef, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorLockButtonHoldCompleted) object:nil];
	if (lockHoldEventToAbort) {
		[lockHoldEventToAbort release];
		lockHoldEventToAbort = nil;
		DisableLockTimer(self);
	} else if (isWaitingForLockDoubleTap) {
		isWaitingForLockDoubleTap = NO;
		LAEvent *activatorEvent = [[[LAEvent alloc] initWithName:LAEventNameLockPressDouble mode:formerLockEventMode] autorelease];
		if ([LASharedActivator assignedListenerNameForEvent:activatorEvent] == nil)
			CHSuper(1, SpringBoard, lockButtonUp, event);
		else {
			if (![formerLockEventMode isEqualToString:LAEventModeLockScreen]) {
				BOOL oldAnimationsEnabled = [UIView areAnimationsEnabled];
				[UIView setAnimationsEnabled:NO];
				SBAwayController *awayController = [CHClass(SBAwayController) sharedAwayController];
				[awayController setDeviceLocked:NO];
				ignoreResetIdleTimerAndUndim = YES;
				if ([awayController respondsToSelector:@selector(_unlockWithSound:isAutoUnlock:)])
					[awayController _unlockWithSound:NO isAutoUnlock:YES];
				else
					[awayController _unlockWithSound:NO];
				ignoreResetIdleTimerAndUndim = NO;
				[UIView setAnimationsEnabled:oldAnimationsEnabled];
			}
			suppressIsLocked = YES;
			[LASharedActivator sendEventToListener:activatorEvent];
			suppressIsLocked = NO;
			if ([activatorEvent isHandled]) {
				[self performSelector:@selector(activatorFixStatusBar) withObject:nil afterDelay:0.0f];
				DisableLockTimer(self);
				if ([self respondsToSelector:@selector(resetIdleTimerAndUndim)])
					[self resetIdleTimerAndUndim];
				else
					[self undim];
			} else {
				shouldSuppressLockSound = YES;
				[CHSharedInstance(SBUIController) lock];
				shouldSuppressLockSound = NO;
				CHSuper(1, SpringBoard, lockButtonUp, event);
			}
		} 
	} else {
		[self performSelector:@selector(activatorLockButtonDoubleTapAborted) withObject:nil afterDelay:kButtonHoldDelay];
		isWaitingForLockDoubleTap = YES;
		CHSuper(1, SpringBoard, lockButtonUp, event);
	}
}

CHOptimizedMethod(0, self, void, SpringBoard, lockButtonWasHeld)
{
	if (lockHoldEventToAbort) {
		LAAbortEvent(lockHoldEventToAbort);
		[lockHoldEventToAbort release];
		lockHoldEventToAbort = nil;
	}
	CHSuper(0, SpringBoard, lockButtonWasHeld);
}

CHOptimizedMethod(0, new, void, SpringBoard, activatorLockButtonHoldCompleted)
{
	[lockHoldEventToAbort release];
	lockHoldEventToAbort = nil;
	LAEvent *event = LASendEventWithName(LAEventNameLockHoldShort);
	if ([event isHandled])
		lockHoldEventToAbort = [event retain];
}

CHOptimizedMethod(0, new, void, SpringBoard, activatorLockButtonDoubleTapAborted)
{
	isWaitingForLockDoubleTap = NO;
}

static CFAbsoluteTime lastShakeEventSentAt;

CHOptimizedMethod(0, self, void, SpringBoard, _showEditAlertView)
{
	// iOS3.x
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
	if (lastShakeEventSentAt + kShakeIgnoreTimeout < now) {
		if ([LASendEventWithName(LAEventNameMotionShake) isHandled]) {
			lastShakeEventSentAt = now;
			return;
		}
	}
	CHSuper(0, SpringBoard, _showEditAlertView);
}

CHOptimizedMethod(1, super, void, SpringBoard, _sendMotionEnded, int, subtype)
{
	// iOS4.0+
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
	if (lastShakeEventSentAt + kShakeIgnoreTimeout < now) {
		if ([LASendEventWithName(LAEventNameMotionShake) isHandled]) {
			lastShakeEventSentAt = now;
			return;
		}
	}
	CHSuper(1, SpringBoard, _sendMotionEnded, subtype);
}

static LAEvent *menuEventToAbort;
static BOOL justTookScreenshot;

CHOptimizedMethod(1, self, void, SpringBoard, menuButtonDown, GSEventRef, event)
{
	[self performSelector:@selector(activatorMenuButtonTimerCompleted) withObject:nil afterDelay:kButtonHoldDelay];
	justTookScreenshot = NO;
	shouldSuppressMenuReleases = NO;
	CHSuper(1, SpringBoard, menuButtonDown, event);
}

CHOptimizedMethod(1, self, void, SpringBoard, menuButtonUp, GSEventRef, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorMenuButtonTimerCompleted) object:nil];
	if (justTookScreenshot) {
		LAAbortEvent(menuEventToAbort);
		[menuEventToAbort release];
		menuEventToAbort = nil;
		CHSuper(1, SpringBoard, menuButtonUp, event);
		justTookScreenshot = NO;
	} else if (menuEventToAbort || shouldSuppressMenuReleases) {
		[menuEventToAbort release];
		menuEventToAbort = nil;
		NSTimer **timer = CHIvarRef(self, _menuButtonTimer, NSTimer *);
		if (timer) {
			[*timer invalidate];
			[*timer release];
			*timer = nil;
		}
	} else {
		CHSuper(1, SpringBoard, menuButtonUp, event);
	}
}

CHOptimizedMethod(0, self, void, SpringBoard, menuButtonWasHeld)
{
	if (menuEventToAbort) {
		LAAbortEvent(menuEventToAbort);
		[menuEventToAbort release];
		menuEventToAbort = nil;
	}
	CHSuper(0, SpringBoard, menuButtonWasHeld);
}

CHOptimizedMethod(0, self, void, SpringBoard, _menuButtonWasHeld)
{
	if (menuEventToAbort) {
		LAAbortEvent(menuEventToAbort);
		[menuEventToAbort release];
		menuEventToAbort = nil;
	}
	CHSuper(0, SpringBoard, _menuButtonWasHeld);
}

CHOptimizedMethod(0, new, void, SpringBoard, activatorMenuButtonTimerCompleted)
{
	[menuEventToAbort release];
	LAEvent *event = LASendEventWithName(LAEventNameMenuHoldShort);
	menuEventToAbort = event.handled ? [event retain] : nil;
}

static NSUInteger lastVolumeEvent;
static CFAbsoluteTime volumeChordBeganTime;
static BOOL suppressVolumeButtonUp;
static CFRunLoopTimerRef volumeButtonUpTimer;
static BOOL isVolumeButtonDown;

static void DestroyCurrentVolumeButtonUpTimer()
{
	if (volumeButtonUpTimer) {
		CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), volumeButtonUpTimer, kCFRunLoopCommonModes);
		CFRelease(volumeButtonUpTimer);
		volumeButtonUpTimer = NULL;
	}
}

static void VolumeUpButtonHeldCallback(CFRunLoopTimerRef timer, void *info)
{
	DestroyCurrentVolumeButtonUpTimer();
	suppressVolumeButtonUp = YES;
	VolumeControl *volumeControl = [CHClass(VolumeControl) sharedVolumeControl];
	if ([LASendEventWithName(LAEventNameVolumeUpHoldShort) isHandled])
		HideVolumeHUD(volumeControl);
	else
		[volumeControl increaseVolume];
}

static void VolumeDownButtonHeldCallback(CFRunLoopTimerRef timer, void *info)
{
	DestroyCurrentVolumeButtonUpTimer();
	suppressVolumeButtonUp = YES;
	VolumeControl *volumeControl = [CHClass(VolumeControl) sharedVolumeControl];
	if ([LASendEventWithName(LAEventNameVolumeDownHoldShort) isHandled])
		HideVolumeHUD(volumeControl);
	else
		[volumeControl decreaseVolume];
}

static BOOL justSuppressedNotificationSound;

CHOptimizedMethod(1, self, void, SpringBoard, volumeChanged, GSEventRef, gsEvent)
{
	// Suppress ringtone
	if ([CHClass(SBAlert) respondsToSelector:@selector(alertWindow)]) {
		id alertWindow = [CHClass(SBAlert) alertWindow];
		if ([alertWindow respondsToSelector:@selector(currentDisplay)]) {
			id alertDisplay = [alertWindow currentDisplay];
			if ([alertDisplay respondsToSelector:@selector(handleVolumeEvent:)]) {
				[alertDisplay handleVolumeEvent:gsEvent];
				return;
			}
		}
	}
	VolumeControl *volumeControl = [CHClass(VolumeControl) sharedVolumeControl];
	switch (GSEventGetType(gsEvent)) {
		case kGSEventVolumeUpButtonDown:
			if (isVolumeButtonDown) {
				DestroyCurrentVolumeButtonUpTimer();
				suppressVolumeButtonUp = YES;
				if ([LASendEventWithName(LAEventNameVolumeBothPress) isHandled])
					HideVolumeHUD(volumeControl);
				break;
			}
			isVolumeButtonDown = YES;
			suppressVolumeButtonUp = NO;
			if (LAListenerForEventWithName(LAEventNameVolumeUpHoldShort)) {
				CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
				volumeButtonUpTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, currentTime + kButtonHoldDelay, 0.0, 0, 0, VolumeUpButtonHeldCallback, NULL);
				CFRunLoopAddTimer(CFRunLoopGetCurrent(), volumeButtonUpTimer, kCFRunLoopCommonModes);
			} else if (!LAListenerForEventWithName(LAEventNameVolumeBothPress)) {
				CHSuper(1, SpringBoard, volumeChanged, gsEvent);
			}
			break;
		case kGSEventVolumeUpButtonUp: {
			isVolumeButtonDown = NO;
			DestroyCurrentVolumeButtonUpTimer();
			if (suppressVolumeButtonUp) {
				volumeChordBeganTime = 0.0;
				[volumeControl cancelVolumeEvent];
				HideVolumeHUD(volumeControl);
				break;
			}
			if (LAListenerForEventWithName(LAEventNameVolumeUpHoldShort) != nil || LAListenerForEventWithName(LAEventNameVolumeBothPress) != nil) {
				[volumeControl increaseVolume];
				[volumeControl cancelVolumeEvent];
			} else {
				CHSuper(1, SpringBoard, volumeChanged, gsEvent);
			}
			CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
			if ((currentTime - volumeChordBeganTime) > kButtonHoldDelay) {
				lastVolumeEvent = kGSEventVolumeUpButtonUp;
				volumeChordBeganTime = currentTime;
			} else if (lastVolumeEvent == kGSEventVolumeDownButtonUp) {
				lastVolumeEvent = 0;
				LASendEventWithName(LAEventNameVolumeDownUp);
			} else {
				lastVolumeEvent = 0;
			}
			break;
		}
		case kGSEventVolumeDownButtonDown:
			// Suppress notification alert sounds
			if ([CHClass(SBRemoteLocalNotificationAlert) respondsToSelector:@selector(isPlayingRingtone)] && [CHClass(SBRemoteLocalNotificationAlert) isPlayingRingtone]) {
				NSArray *notificationAlerts = [CHSharedInstance(SBAlertItemsController) alertItemsOfClass:CHClass(SBRemoteLocalNotificationAlert)];
				[notificationAlerts makeObjectsPerformSelector:@selector(snoozeIfPossible)];
				if ([CHClass(SBRemoteLocalNotificationAlert) respondsToSelector:@selector(stopPlayingAlertSoundOrRingtone)]) {
					[CHClass(SBRemoteLocalNotificationAlert) stopPlayingAlertSoundOrRingtone];
				}
				justSuppressedNotificationSound = YES;
				break;
			}
			if (isVolumeButtonDown) {
				DestroyCurrentVolumeButtonUpTimer();
				suppressVolumeButtonUp = YES;
				if ([LASendEventWithName(LAEventNameVolumeBothPress) isHandled])
					HideVolumeHUD(volumeControl);
				break;
			}
			isVolumeButtonDown = YES;
			suppressVolumeButtonUp = NO;
			if (LAListenerForEventWithName(LAEventNameVolumeDownHoldShort)) {
				CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
				volumeButtonUpTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, currentTime + kButtonHoldDelay, 0.0, 0, 0, VolumeDownButtonHeldCallback, NULL);
				CFRunLoopAddTimer(CFRunLoopGetCurrent(), volumeButtonUpTimer, kCFRunLoopCommonModes);
			} else if (!LAListenerForEventWithName(LAEventNameVolumeBothPress)) {
				CHSuper(1, SpringBoard, volumeChanged, gsEvent);
			}
			break;
		case kGSEventVolumeDownButtonUp: {
			if (justSuppressedNotificationSound) {
				justSuppressedNotificationSound = NO;
				break;
			}
			isVolumeButtonDown = NO;
			DestroyCurrentVolumeButtonUpTimer();
			if (suppressVolumeButtonUp) {
				volumeChordBeganTime = 0.0;
				[volumeControl cancelVolumeEvent];
				HideVolumeHUD(volumeControl);
				break;
			}
			if (LAListenerForEventWithName(LAEventNameVolumeDownHoldShort) != nil || LAListenerForEventWithName(LAEventNameVolumeBothPress) != nil) {
				if ([CHClass(VolumeControl) respondsToSelector:@selector(volumeStep)])
					[volumeControl _changeVolumeBy:-[CHClass(VolumeControl) volumeStep]];
				else
					[volumeControl decreaseVolume];
				[volumeControl cancelVolumeEvent];
			} else {
				CHSuper(1, SpringBoard, volumeChanged, gsEvent);
			}
			CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
			if ((currentTime - volumeChordBeganTime) > kButtonHoldDelay) {
				lastVolumeEvent = kGSEventVolumeDownButtonUp;
				volumeChordBeganTime = currentTime;
			} else if (lastVolumeEvent == kGSEventVolumeUpButtonUp) {
				lastVolumeEvent = 0;
				LASendEventWithName(LAEventNameVolumeUpDown);
			} else {
				lastVolumeEvent = 0;
			}
			break;
		}
		default:
			CHSuper(1, SpringBoard, volumeChanged, gsEvent);
			break;
	}
}

CHOptimizedMethod(0, self, void, iHome, inject)
{
	CHSuper(0, iHome, inject);
	[quickDoButton release];
	UIButton **buttonRef = CHIvarRef(self, touchButton, UIButton *);
	if (buttonRef) {
		quickDoButton = [*buttonRef retain];
		if (quickDoButton) {
			UIWindow *window = [quickDoButton window];
			if (window) {
				CGRect windowFrame = [window frame];
				CGRect screenBounds = [[UIScreen mainScreen] bounds];
				if (windowFrame.origin.y > screenBounds.origin.y + screenBounds.size.height / 2.0f) {
					[LASlideGestureWindow updateVisibility];
					[[LAQuickDoDelegate sharedInstance] acceptEventsFromControl:quickDoButton];
					return;
				}
			}
		}
	} else {
		quickDoButton = nil;
	}
}

CHOptimizedMethod(0, self, BOOL, SBUIController, clickedMenuButton)
{
	if (menuEventToAbort || justTookScreenshot)
		return YES;
	NSString *mode = [LASharedActivator currentEventMode];
	LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressSingle mode:mode];
	[LASharedActivator sendDeactivateEventToListeners:event];
	if ([event isHandled])
		return YES;
	SBIconController *iconController = CHSharedInstance(SBIconController);
	if (([iconController isEditing]) || 
		([iconController respondsToSelector:@selector(currentFolderIconList)] && [iconController currentFolderIconList]) ||
		([CHClass(SBUIController) instancesRespondToSelector:@selector(isSwitcherShowing)] && [CHSharedInstance(SBUIController) isSwitcherShowing]))
	{
		return CHSuper(0, SBUIController, clickedMenuButton);
	}
	[LASharedActivator sendEventToListener:event];
	if (![event isHandled])
		return CHSuper(0, SBUIController, clickedMenuButton);
	if ([mode isEqualToString:LAEventModeApplication]) {
		NSString *listenerName = [LASharedActivator assignedListenerNameForEvent:event];
		if (![[LASharedActivator infoDictionaryValueOfKey:@"receives-raw-events" forListenerWithName:listenerName] boolValue])
			CHSuper(0, SBUIController, clickedMenuButton);
	}
	return YES;
}

CHOptimizedMethod(0, self, void, SBUIController, finishLaunching)
{
	if (!CHClass(iHome)) {
		CHLoadLateClass(iHome);
		CHHook(0, iHome, inject);
	}
	[LASimpleListener sharedInstance];
	[LAToggleListener sharedInstance];
	[LAMenuListener sharedMenuListener];
	CHSuper(0, SBUIController, finishLaunching);
	[LASlideGestureWindow performSelector:@selector(updateVisibility) withObject:nil afterDelay:1.0];
}

CHOptimizedMethod(0, self, void, SBUIController, tearDownIconListAndBar)
{
	CHSuper(0, SBUIController, tearDownIconListAndBar);
	[LASlideGestureWindow updateVisibility];
	[(LASpringBoardActivator *)LASharedActivator _eventModeChanged];
}

CHOptimizedMethod(1, self, void, SBUIController, restoreIconList, BOOL, animate)
{
	CHSuper(1, SBUIController, restoreIconList, animate);
	[LASlideGestureWindow updateVisibility];
	[(LASpringBoardActivator *)LASharedActivator _eventModeChanged];
}

CHOptimizedMethod(0, self, void, SBUIController, lock)
{
	CHSuper(0, SBUIController, lock);
	[LASlideGestureWindow updateVisibility];
	[(LASpringBoardActivator *)LASharedActivator _eventModeChanged];
}

CHOptimizedMethod(0, self, void, SBUIController, _toggleSwitcher)
{
	if (![self isSwitcherShowing]) {
		LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressSingle mode:LASharedActivator.currentEventMode];
		[LASharedActivator sendDeactivateEventToListeners:event];
	}
	CHSuper(0, SBUIController, _toggleSwitcher);
}

CHOptimizedMethod(0, self, void, SBUIController, ACPowerChanged)
{
	CHSuper(0, SBUIController, ACPowerChanged);
	if ([self respondsToSelector:@selector(isOnAC)])
		LASendEventWithName([self isOnAC] ? LAEventNamePowerConnected : LAEventNamePowerDisconnected);
}

CHOptimizedMethod(1, self, void, SBScreenShotter, saveScreenshot, BOOL, something)
{
	justTookScreenshot = YES;
	CHSuper(1, SBScreenShotter, saveScreenshot, something);
}

CHOptimizedMethod(2, self, void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (shouldInterceptMenuPresses) {
		shouldInterceptMenuPresses = NO;
		if ([LASendEventWithName(LAEventNameMenuPressSingle) isHandled])
			return;
	}
	CHSuper(2, SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

static BOOL hasSentPinchSpread;


CHOptimizedMethod(1, super, id, SBIconScrollView, initWithFrame, CGRect, frame)
{
	if ((self = CHSuper(1, SBIconScrollView, initWithFrame, frame))) {
		// Add Pinch Gesture by allowing a nonstandard zoom (reuse the existing gesture)
		[self setMinimumZoomScale:0.95f];
	}
	return self;
}

CHOptimizedMethod(2, super, void, SBIconScrollView, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	hasSentPinchSpread = NO;
	CHSuper(2, SBIconScrollView, touchesBegan, touches, withEvent, event);
}

CHOptimizedMethod(1, super, void, SBIconScrollView, handlePinch, UIPinchGestureRecognizer *, pinchGesture)
{
	if (!hasSentPinchSpread) {
		CGFloat scale = [pinchGesture scale];
		if (scale < kSpringBoardPinchThreshold) {
			hasSentPinchSpread = YES;
			LASendEventWithName(LAEventNameSpringBoardPinch);
		} else if (scale > kSpringBoardSpreadThreshold) {
			hasSentPinchSpread = YES;
			LASendEventWithName(LAEventNameSpringBoardSpread);
		}
	}
}


CHOptimizedMethod(0, self, id, SBIcon, initWithDefaultSize)
{
	// Enable multitouch
	if ((self = CHSuper(0, SBIcon, initWithDefaultSize))) {
		[self setMultipleTouchEnabled:YES];
	}
	return self;
}

// SBIcons don't seem to respond to the pinch gesture (and eat it for pinch gestures on superviews), so this hack is necessary. Hopefully something better can be found
static NSInteger lastTouchesCount;
static CGFloat startingDistanceSquared;

CHOptimizedMethod(2, self, void, SBIcon, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	lastTouchesCount = 1;
	NSArray *switcherIcons = [[CHSharedInstance(SBAppSwitcherController) _currentIcons] allValues];
	hasSentPinchSpread = switcherIcons && ([switcherIcons indexOfObjectIdenticalTo:self] != NSNotFound);
	CHSuper(2, SBIcon, touchesBegan, touches, withEvent, event);
}

CHOptimizedMethod(2, self, void, SBIcon, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
{
	if (!hasSentPinchSpread) {
		NSArray *allTouches = [[event allTouches] allObjects];
		NSInteger allTouchesCount = [allTouches count];
		if (allTouchesCount == 2) {
			UIWindow *window = [self window];
			UITouch *firstTouch = [allTouches objectAtIndex:0];
			UITouch *secondTouch = [allTouches objectAtIndex:1];
			CGPoint firstPoint = [firstTouch locationInView:window];
			CGPoint secondPoint = [secondTouch locationInView:window];
			CGFloat deltaX = firstPoint.x - secondPoint.x;
			CGFloat deltaY = firstPoint.y - secondPoint.y;
			CGFloat currentDistanceSquared = deltaX * deltaX + deltaY * deltaY;
			if (lastTouchesCount != 2)
				startingDistanceSquared = currentDistanceSquared;
			else if (currentDistanceSquared < startingDistanceSquared * (kSpringBoardPinchThreshold * kSpringBoardPinchThreshold)) {
				hasSentPinchSpread = YES;
				LASendEventWithName(LAEventNameSpringBoardPinch);
			} else if (currentDistanceSquared > startingDistanceSquared * (kSpringBoardSpreadThreshold * kSpringBoardSpreadThreshold)) {
				hasSentPinchSpread = YES;
				LASendEventWithName(LAEventNameSpringBoardSpread);
			}
		}
		lastTouchesCount = allTouchesCount;
	}
	CHSuper(2, SBIcon, touchesMoved, touches, withEvent, event);
}

static CGPoint statusBarTouchDown;
static BOOL hasSentStatusBarEvent;


CHOptimizedMethod(0, new, void, SBStatusBar, activatorHoldEventCompleted)
{
	if (!hasSentStatusBarEvent) {
		hasSentStatusBarEvent = YES;
		LASendEventWithName(LAEventNameStatusBarHold);
	}
}

CHOptimizedMethod(2, self, void, SBStatusBar, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	[self performSelector:@selector(activatorHoldEventCompleted) withObject:nil afterDelay:kStatusBarHoldDelay];
	statusBarTouchDown = [[touches anyObject] locationInView:self];
	hasSentStatusBarEvent = NO;
	CHSuper(2, SBStatusBar, touchesBegan, touches, withEvent, event);
}

CHOptimizedMethod(2, self, void, SBStatusBar, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
{
	if (!hasSentStatusBarEvent) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorHoldEventCompleted) object:nil];
		CGPoint currentPosition = [[touches anyObject] locationInView:self];
		CGFloat deltaX = currentPosition.x - statusBarTouchDown.x;
		CGFloat deltaY = currentPosition.y - statusBarTouchDown.y;
		if ((deltaX * deltaX) > (deltaY * deltaY)) {
			if (deltaX > kStatusBarHorizontalSwipeThreshold) {
				hasSentStatusBarEvent = YES;
				LASendEventWithName(LAEventNameStatusBarSwipeRight);
			} else if (deltaX < -kStatusBarHorizontalSwipeThreshold) {
				hasSentStatusBarEvent = YES;
				LASendEventWithName(LAEventNameStatusBarSwipeLeft);
			}
		} else {
			if (deltaY > kStatusBarVerticalSwipeThreshold) {
				hasSentStatusBarEvent = YES;
				LASendEventWithName(LAEventNameStatusBarSwipeDown);
			}
		}
	}
	CHSuper(2, SBStatusBar, touchesMoved, touches, withEvent, event);
}

CHOptimizedMethod(2, self, void, SBStatusBar, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorHoldEventCompleted) object:nil];
	if (!hasSentStatusBarEvent)
		if ([[touches anyObject] tapCount] == 2)
			LASendEventWithName(LAEventNameStatusBarTapDouble);
	CHSuper(2, SBStatusBar, touchesEnded, touches, withEvent, event);
}

CHOptimizedMethod(0, new, void, UIStatusBar, activatorHoldEventCompleted)
{
	if (!hasSentStatusBarEvent) {
		hasSentStatusBarEvent = YES;
		LASendEventWithName(LAEventNameStatusBarHold);
	}
}

CHOptimizedMethod(2, self, void, UIStatusBar, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	[self performSelector:@selector(activatorHoldEventCompleted) withObject:nil afterDelay:kStatusBarHoldDelay];
	statusBarTouchDown = [[touches anyObject] locationInView:self];
	hasSentStatusBarEvent = NO;
}

CHOptimizedMethod(2, super, void, UIStatusBar, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
{
	if (!hasSentStatusBarEvent) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorHoldEventCompleted) object:nil];
		CGPoint currentPosition = [[touches anyObject] locationInView:self];
		CGFloat deltaX = currentPosition.x - statusBarTouchDown.x;
		CGFloat deltaY = currentPosition.y - statusBarTouchDown.y;
		if ((deltaX * deltaX) > (deltaY * deltaY)) {
			if (deltaX > kStatusBarHorizontalSwipeThreshold) {
				hasSentStatusBarEvent = YES;
				LASendEventWithName(LAEventNameStatusBarSwipeRight);
			} else if (deltaX < -kStatusBarHorizontalSwipeThreshold) {
				hasSentStatusBarEvent = YES;
				LASendEventWithName(LAEventNameStatusBarSwipeLeft);
			}
		} else {
			if (deltaY > kStatusBarVerticalSwipeThreshold) {
				hasSentStatusBarEvent = YES;
				LASendEventWithName(LAEventNameStatusBarSwipeDown);
			}
		}
	}
}

CHOptimizedMethod(2, self, void, UIStatusBar, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorHoldEventCompleted) object:nil];
	if (!hasSentStatusBarEvent) {
		if ([[touches anyObject] tapCount] == 2)
			LASendEventWithName(LAEventNameStatusBarTapDouble);
		else {
			CHSuper(2, UIStatusBar, touchesBegan, touches, withEvent, event);
			CHSuper(2, UIStatusBar, touchesEnded, touches, withEvent, event);
		}
	}
}

static NSInteger nowPlayingButtonIndex;

CHOptimizedMethod(0, super, UIAlertView *, SBNowPlayingAlertItem, createFrontAlertSheet)
{
	nowPlayingButtonIndex = -1000;
	return CHSuper(0, SBNowPlayingAlertItem, createFrontAlertSheet);
}

CHOptimizedMethod(2, super, void, SBNowPlayingAlertItem, configure, BOOL, front, requirePasscodeForActions, BOOL, requirePasscode)
{
	if (shouldAddNowPlayingButton && nowPlayingButtonIndex == -1000) {
		LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressDouble];
		NSString *listenerName = [LASharedActivator assignedListenerNameForEvent:event];
		if (listenerName && ![listenerName isEqualToString:@"libactivator.ipod.music-controls"]) {
			CHSuper(2, SBNowPlayingAlertItem, configure, front, requirePasscodeForActions, requirePasscode);
			NSString *listenerName = [LASharedActivator assignedListenerNameForEvent:event];
			NSString *title = [LASharedActivator localizedTitleForListenerName:listenerName];
			id alertSheet = [self alertSheet];
			//[alertSheet setNumberOfRows:2];
			if ([[LASharedActivator currentEventMode] isEqualToString:LAEventModeLockScreen]) {
				[[[alertSheet buttons] objectAtIndex:1] setTitle:title];
				nowPlayingButtonIndex = 1;
			} else {
				nowPlayingButtonIndex = [alertSheet addButtonWithTitle:title];
			}
			return;
		}
	}
	nowPlayingButtonIndex = -1000;
	if ([[LASharedActivator currentEventMode] isEqualToString:LAEventModeLockScreen]) {
		CHSuper(2, SBNowPlayingAlertItem, configure, front, requirePasscodeForActions, requirePasscode);
		[[[[self alertSheet] buttons] objectAtIndex:1] setHidden:YES];
	} else {
		CHSuper(2, SBNowPlayingAlertItem, configure, front, requirePasscodeForActions, requirePasscode);
	}
}

CHOptimizedMethod(2, super, void, SBNowPlayingAlertItem, configureFront, BOOL, front, requirePasscodeForActions, BOOL, requirePasscode)
{
	if (shouldAddNowPlayingButton && nowPlayingButtonIndex == -1000) {
		LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressDouble];
		NSString *listenerName = [LASharedActivator assignedListenerNameForEvent:event];
		if (listenerName && ![listenerName isEqualToString:@"libactivator.ipod.music-controls"]) {
			CHSuper(2, SBNowPlayingAlertItem, configureFront, front, requirePasscodeForActions, requirePasscode);
			NSString *listenerName = [LASharedActivator assignedListenerNameForEvent:event];
			NSString *title = [LASharedActivator localizedTitleForListenerName:listenerName];
			id alertSheet = [self alertSheet];
			//[alertSheet setNumberOfRows:2];
			if ([[LASharedActivator currentEventMode] isEqualToString:LAEventModeLockScreen]) {
				[[[alertSheet buttons] objectAtIndex:1] setTitle:title];
				nowPlayingButtonIndex = 1;
			} else {
				nowPlayingButtonIndex = [alertSheet addButtonWithTitle:title];
			}
			return;
		}
	}
	nowPlayingButtonIndex = -1000;
	if ([[LASharedActivator currentEventMode] isEqualToString:LAEventModeLockScreen]) {
		CHSuper(2, SBNowPlayingAlertItem, configureFront, front, requirePasscodeForActions, requirePasscode);
		[[[[self alertSheet] buttons] objectAtIndex:1] setHidden:YES];
	} else {
		CHSuper(2, SBNowPlayingAlertItem, configureFront, front, requirePasscodeForActions, requirePasscode);
	}
}

CHOptimizedMethod(2, self, void, SBNowPlayingAlertItem, alertSheet, id, sheet, buttonClicked, NSInteger, buttonIndex)
{
	if (buttonIndex == nowPlayingButtonIndex + 1)
		LASendEventWithName(LAEventNameMenuPressDouble);
	else
		CHSuper(2, SBNowPlayingAlertItem, alertSheet, sheet, buttonClicked, buttonIndex);
}

CHOptimizedMethod(0, self, id, SBVoiceControlAlert, initFromMenuButton)
{
	if (menuEventToAbort) {
		LAAbortEvent(menuEventToAbort);
		[menuEventToAbort release];
		menuEventToAbort = nil;
	}
	return CHSuper(0, SBVoiceControlAlert, initFromMenuButton);
}

CHOptimizedMethod(0, self, void, SBAwayController, playLockSound)
{
	if (!shouldSuppressLockSound)
		CHSuper(0, SBAwayController, playLockSound);
}

CHOptimizedMethod(0, self, BOOL, SBAwayController, handleMenuButtonTap)
{
	NSString *mode = [LASharedActivator currentEventMode];
	LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressSingle mode:mode];
	[LASharedActivator sendDeactivateEventToListeners:event];
	if ([event isHandled])
		return YES;
	[LASharedActivator sendEventToListener:event];
	if ([event isHandled])
		return YES;
	return CHSuper(0, SBAwayController, handleMenuButtonTap);
}

CHOptimizedMethod(0, self, void, SBAwayController, _sendLockStateChangedNotification)
{
	[LASlideGestureWindow updateVisibility];
	CHSuper(0, SBAwayController, _sendLockStateChangedNotification);
}

static CFAbsoluteTime lastAwayDateLastTime;
static NSInteger lastAwayDateTapCount;

CHOptimizedMethod(2, super, void, SBAwayDateView, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
	if (lastAwayDateLastTime + 0.333 < currentTime)
		lastAwayDateTapCount = 0;
	lastAwayDateTapCount++;
	lastAwayDateLastTime = currentTime;
	CHSuper(2, SBAwayDateView, touchesBegan, touches, withEvent, event);
}

CHOptimizedMethod(2, super, void, SBAwayDateView, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
{
	lastAwayDateTapCount = 0;
	lastAwayDateLastTime = 0.0;
	CHSuper(2, SBAwayDateView, touchesMoved, touches, withEvent, event);
}

CHOptimizedMethod(2, super, void, SBAwayDateView, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
	if (lastAwayDateLastTime + 0.333 < currentTime) {
		lastAwayDateTapCount = 0;
		lastAwayDateLastTime = 0.0;
	} else {
		lastAwayDateLastTime = currentTime;
		if (lastAwayDateTapCount == 2)
			LASendEventWithName(LAEventNameLockScreenClockDoubleTap);
	}
	CHSuper(2, SBAwayDateView, touchesEnded, touches, withEvent, event);
}

CHOptimizedMethod(2, super, void, SBAwayDateView, touchesCancelled, NSSet *, touches, withEvent, UIEvent *, event)
{
	lastAwayDateTapCount = 0;
	lastAwayDateLastTime = 0.0;
	CHSuper(2, SBAwayDateView, touchesCancelled, touches, withEvent, event);
}

CHOptimizedMethod(0, self, void, VolumeControl, _createUI)
{
	if (LAListenerForEventWithName(LAEventNameVolumeDisplayTap)) {
		CHSuper(0, VolumeControl, _createUI);
		UIView **view = CHIvarRef(self, _volumeView, UIView *);
		if (view && *view) {
			ShowVolumeTapWindow(*view);
		} else {
			UIWindow *window = CHIvar(self, _volumeWindow, UIWindow *);
			if (window)
				ShowVolumeTapWindow(window);
		}
	} else {
		CHSuper(0, VolumeControl, _createUI);
	}
}

CHOptimizedMethod(0, self, void, VolumeControl, _tearDown)
{
	HideVolumeTapWindow();
	CHSuper(0, VolumeControl, _tearDown);
}

CHOptimizedMethod(0, super, void, SBVolumeHUDView, didMoveToWindow)
{
	UIWindow *window = [self window];
	if (window)
		ShowVolumeTapWindow(self);
	else
		HideVolumeTapWindow();
	CHSuper(0, SBVolumeHUDView, didMoveToWindow);
}

CHConstructor
{
	CHAutoreleasePoolForScope();
	if (CHLoadLateClass(UIStatusBar)) {
		CHHook(0, UIStatusBar, activatorHoldEventCompleted);
		CHHook(2, UIStatusBar, touchesBegan, withEvent);
		CHHook(2, UIStatusBar, touchesMoved, withEvent);
		CHHook(2, UIStatusBar, touchesEnded, withEvent);
	}
	
	if (CHLoadLateClass(SpringBoard)) {
		CHHook(1, SpringBoard, ringerChanged);
		//CHHook(0, SpringBoard, systemWillSleep);
		//CHHook(0, SpringBoard, undim);
		CHHook(0, SpringBoard, _performDelayedHeadsetAction);
		CHHook(1, SpringBoard, headsetButtonDown);
		CHHook(1, SpringBoard, headsetButtonUp);
		CHHook(0, SpringBoard, _handleMenuButtonEvent);
		CHHook(1, SpringBoard, respondImmediatelyToMenuSingleTapAllowingDoubleTap);
		CHHook(0, SpringBoard, allowMenuDoubleTap);
		CHHook(0, SpringBoard, handleMenuDoubleTap);
		CHHook(0, SpringBoard, isLocked);
		CHHook(1, SpringBoard, lockButtonDown);
		CHHook(0, SpringBoard, activatorFixStatusBar);
		CHHook(1, SpringBoard, resetIdleTimerAndUndim);
		CHHook(1, SpringBoard, lockButtonUp);
		CHHook(0, SpringBoard, lockButtonWasHeld);
		CHHook(0, SpringBoard, activatorLockButtonHoldCompleted);
		CHHook(0, SpringBoard, activatorLockButtonDoubleTapAborted);
		CHHook(1, SpringBoard, menuButtonDown);
		CHHook(1, SpringBoard, menuButtonUp);
		CHHook(0, SpringBoard, menuButtonWasHeld);
		CHHook(0, SpringBoard, _menuButtonWasHeld);
		CHHook(0, SpringBoard, activatorMenuButtonTimerCompleted);
		CHHook(1, SpringBoard, volumeChanged);
		CHHook(0, SpringBoard, _showEditAlertView);
		CHHook(1, SpringBoard, _sendMotionEnded);
		
		CHLoadLateClass(SBUIController);
		CHHook(0, SBUIController, clickedMenuButton);
		CHHook(0, SBUIController, finishLaunching);
		CHHook(0, SBUIController, tearDownIconListAndBar);
		CHHook(1, SBUIController, restoreIconList);
		CHHook(0, SBUIController, lock);
		CHHook(0, SBUIController, _toggleSwitcher);
		CHHook(0, SBUIController, ACPowerChanged);
	
		CHLoadLateClass(SBScreenShotter);
		CHHook(1, SBScreenShotter, saveScreenshot);
	
		CHLoadLateClass(SBIconController);
		CHHook(2, SBIconController, scrollToIconListAtIndex, animate);
		
		CHLoadLateClass(SBIconScrollView);
		CHHook(1, SBIconScrollView, initWithFrame);
		CHHook(2, SBIconScrollView, touchesBegan, withEvent);
		CHHook(1, SBIconScrollView, handlePinch);
		
		CHLoadLateClass(SBIcon);
		CHHook(0, SBIcon, initWithDefaultSize);
		CHHook(2, SBIcon, touchesBegan, withEvent);
		CHHook(2, SBIcon, touchesMoved, withEvent);
		
		CHLoadLateClass(SBStatusBar);
		CHHook(0, SBStatusBar, activatorHoldEventCompleted);
		CHHook(2, SBStatusBar, touchesBegan, withEvent);
		CHHook(2, SBStatusBar, touchesMoved, withEvent);
		CHHook(2, SBStatusBar, touchesEnded, withEvent);
		
		CHLoadLateClass(SBNowPlayingAlertItem);
		CHHook(0, SBNowPlayingAlertItem, createFrontAlertSheet);
		CHHook(2, SBNowPlayingAlertItem, configure, requirePasscodeForActions);
		CHHook(2, SBNowPlayingAlertItem, configureFront, requirePasscodeForActions);
		CHHook(2, SBNowPlayingAlertItem, alertSheet, buttonClicked);
		
		CHLoadLateClass(SBVoiceControlAlert);
		CHHook(0, SBVoiceControlAlert, initFromMenuButton);
		
		CHLoadLateClass(SBAwayController);
		CHHook(0, SBAwayController, playLockSound);
		CHHook(0, SBAwayController, handleMenuButtonTap);
		CHHook(0, SBAwayController, _sendLockStateChangedNotification);

		CHLoadLateClass(SBAwayDateView);	
		CHHook(2, SBAwayDateView, touchesBegan, withEvent);
		CHHook(2, SBAwayDateView, touchesMoved, withEvent);
		CHHook(2, SBAwayDateView, touchesEnded, withEvent);
		CHHook(2, SBAwayDateView, touchesCancelled, withEvent);

		CHLoadLateClass(VolumeControl);
		CHHook(0, VolumeControl, _createUI);
		CHHook(0, VolumeControl, _tearDown);
		
		CHLoadLateClass(SBVolumeHUDView);
		if (CHClass(SBVolumeHUDView))
			CHHook(0, SBVolumeHUDView, didMoveToWindow);
	
		CHLoadLateClass(iHome);
		if (CHClass(iHome))
			CHHook(0, iHome, inject);
			
		CHLoadLateClass(SBAppSwitcherController);
		
		CHLoadLateClass(SBStatusBarController);
		CHLoadLateClass(SBRemoteLocalNotificationAlert);
		CHLoadLateClass(SBAlertItemsController);
		CHLoadLateClass(SBAlert);
		[[LAVersionChecker class] performSelector:@selector(checkVersion) withObject:nil afterDelay:0.1];
	}
}
