#import "libactivator.h"

#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>
#import <UIKit/UIKit-Private.h>

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

NSString * const LAEventNameSlideInFromBottom      = @"libactivator.slide-in.bottom";
NSString * const LAEventNameSlideInFromBottomLeft  = @"libactivator.slide-in.bottom-left";
NSString * const LAEventNameSlideInFromBottomRight = @"libactivator.slide-in.bottom-right";

NSString * const LAEventNameMotionShake            = @"libactivator.motion.shake";

#define kSpringBoardPinchThreshold         0.95f
#define kSpringBoardSpreadThreshold        1.05f
#define kButtonHoldDelay                   0.8f
#define kStatusBarHorizontalSwipeThreshold 50.0f
#define kStatusBarVerticalSwipeThreshold   10.0f
#define kStatusBarHoldDelay                0.5f
#define kSlideGestureWindowHeight          13.0f

@interface LASlideGestureWindow : UIWindow {
	BOOL hasSentSlideEvent;
}
+ (id)sharedInstance;
- (void)acceptEventsFromControl:(UIControl *)control;
@end

CHDeclareClass(SpringBoard);
CHDeclareClass(SBUIController);
CHDeclareClass(SBIconController);
CHDeclareClass(SBIconScrollView);
CHDeclareClass(SBIcon);
CHDeclareClass(SBStatusBar);
CHDeclareClass(SBNowPlayingAlertItem);
CHDeclareClass(iHome);
CHDeclareClass(SBAwayController);
CHDeclareClass(SBStatusBarController);

static BOOL shouldInterceptMenuPresses;

static LASlideGestureWindow *slideGestureWindow;
static UIButton *quickDoButton;

static LAActivator *activator;

CHConstructor {
	activator = [LAActivator sharedInstance];
}

CHInline
static LAEvent *LASendEventWithName(NSString *eventName)
{
	LAEvent *event = [[[LAEvent alloc] initWithName:eventName mode:[activator currentEventMode]] autorelease];
	[activator sendEventToListener:event];
	return event;
}

CHInline
static void LAAbortEvent(LAEvent *event)
{
	[activator sendAbortToListener:event];
}

@implementation LASlideGestureWindow

+ (id)sharedInstance
{
	if (!slideGestureWindow) {
		CGRect frame = [[UIScreen mainScreen] bounds];
		frame.origin.y += frame.size.height - kSlideGestureWindowHeight;
		frame.size.height = kSlideGestureWindowHeight;
		slideGestureWindow = [[LASlideGestureWindow alloc] initWithFrame:frame];
		[slideGestureWindow setWindowLevel:9999.0f];
		[slideGestureWindow setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:(1.0f / 255.0f)]]; // Content seems to be required for swipe gestures to work in-app
	}
	return slideGestureWindow;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	hasSentSlideEvent = NO;
}

- (void)controlTouchesBegan:(UIControl *)control withEvent:(UIEvent *)event
{
	hasSentSlideEvent = NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!hasSentSlideEvent) {
		hasSentSlideEvent = YES;
		UITouch *touch = [touches anyObject];
		CGFloat xFactor = [touch locationInView:self].x / [self bounds].size.width;
		if (xFactor < 0.25f)
			LASendEventWithName(LAEventNameSlideInFromBottomLeft);
		else if (xFactor < 0.75f)
			LASendEventWithName(LAEventNameSlideInFromBottom);
		else
			LASendEventWithName(LAEventNameSlideInFromBottomRight);
	}
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

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	hasSentSlideEvent = NO;
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

CHMethod(0, void, SpringBoard, _handleMenuButtonEvent)
{
	// Unfortunately there isn't a better way of doing this :(
	shouldInterceptMenuPresses = YES;
	CHSuper(0, SpringBoard, _handleMenuButtonEvent);
	shouldInterceptMenuPresses = NO;
}

CHMethod(0, BOOL, SpringBoard, allowMenuDoubleTap)
{
	LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressDouble mode:[activator currentEventMode]];
	if ([activator listenerForEvent:event]) {
		CHSuper(0, SpringBoard, allowMenuDoubleTap);
		return YES;
	} else {
		return CHSuper(0, SpringBoard, allowMenuDoubleTap);
	}
}

CHMethod(0, void, SpringBoard, handleMenuDoubleTap)
{
	if (![self canShowNowPlayingHUD])
		if ([LASendEventWithName(LAEventNameMenuPressDouble) isHandled])
			return;
	CHSuper(0, SpringBoard, handleMenuDoubleTap);
}

static LAEvent *lockEventToAbort;
static BOOL isWaitingForLockDoubleTap;
static BOOL wasLockedBefore;

CHMethod(1, void, SpringBoard, lockButtonDown, GSEventRef, event)
{
	[self performSelector:@selector(activatorLockButtonHoldCompleted) withObject:nil afterDelay:kButtonHoldDelay];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorLockButtonDoubleTapAborted) object:nil];
	if (!isWaitingForLockDoubleTap)
		wasLockedBefore = [self isLocked];
	CHSuper(1, SpringBoard, lockButtonDown, event);
}

CHMethod(0, void, SpringBoard, activatorFixStatusBar)
{
	[[CHClass(SBStatusBarController) sharedStatusBarController] setIsLockVisible:NO isTimeVisible:YES];
}

CHMethod(1, void, SpringBoard, lockButtonUp, GSEventRef, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorLockButtonHoldCompleted) object:nil];
	[self performSelector:@selector(activatorLockButtonDoubleTapAborted) withObject:nil afterDelay:kButtonHoldDelay];
	if (lockEventToAbort) {
		[lockEventToAbort release];
		lockEventToAbort = nil;
		NSTimer **timer = CHIvarRef([UIApplication sharedApplication], _lockButtonTimer, NSTimer *);
		if (timer) {
			[*timer invalidate];
			[*timer release];
			*timer = nil;
		}
	} if (isWaitingForLockDoubleTap) {
		isWaitingForLockDoubleTap = NO;
		if (!wasLockedBefore) {
			BOOL oldAnimationsEnabled = [UIView areAnimationsEnabled];
			[UIView setAnimationsEnabled:NO];
			[[CHClass(SBAwayController) sharedAwayController] unlockWithSound:NO];
			[UIView setAnimationsEnabled:oldAnimationsEnabled];
		}
		if ([LASendEventWithName(LAEventNameLockPressDouble) isHandled]) {
			[self performSelector:@selector(activatorFixStatusBar) withObject:nil afterDelay:0.0f];
			NSTimer **timer = CHIvarRef([UIApplication sharedApplication], _lockButtonTimer, NSTimer *);
			if (timer) {
				[*timer invalidate];
				[*timer release];
				*timer = nil;
			}
		} else {
			[CHSharedInstance(SBUIController) lock];
			CHSuper(1, SpringBoard, lockButtonUp, event);
		}
	} else {
		isWaitingForLockDoubleTap = YES;
		CHSuper(1, SpringBoard, lockButtonUp, event);
	}
}

CHMethod(0, void, SpringBoard, lockButtonWasHeld)
{
	if (lockEventToAbort) {
		LAAbortEvent(lockEventToAbort);
		[lockEventToAbort release];
		lockEventToAbort = nil;
	}
	CHSuper(0, SpringBoard, lockButtonWasHeld);
}

CHMethod(0, void, SpringBoard, activatorLockButtonHoldCompleted)
{
	[lockEventToAbort release];
	lockEventToAbort = nil;
	LAEvent *event = LASendEventWithName(LAEventNameLockHoldShort);
	if ([event isHandled])
		lockEventToAbort = [event retain];
}

CHMethod(0, void, SpringBoard, activatorLockButtonDoubleTapAborted)
{
	isWaitingForLockDoubleTap = NO;
}

CHMethod(0, void, SpringBoard, _showEditAlertView)
{
	if (![LASendEventWithName(LAEventNameMotionShake) isHandled])
		CHSuper(0, SpringBoard, _showEditAlertView);
}

static LAEvent *menuEventToAbort;

CHMethod(1, void, SpringBoard, menuButtonDown, GSEventRef, event)
{
	[self performSelector:@selector(activatorMenuButtonTimerCompleted) withObject:nil afterDelay:kButtonHoldDelay];
	CHSuper(1, SpringBoard, menuButtonDown, event);
}

CHMethod(1, void, SpringBoard, menuButtonUp, GSEventRef, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorMenuButtonTimerCompleted) object:nil];
	if (menuEventToAbort) {
		[menuEventToAbort release];
		menuEventToAbort = nil;
		NSTimer **timer = CHIvarRef([UIApplication sharedApplication], _menuButtonTimer, NSTimer *);
		if (timer) {
			[*timer invalidate];
			[*timer release];
			*timer = nil;
		}
	} else {
		CHSuper(1, SpringBoard, menuButtonUp, event);
	}
}

CHMethod(0, void, SpringBoard, menuButtonWasHeld)
{
	if (lockEventToAbort) {
		LAAbortEvent(menuEventToAbort);
		[menuEventToAbort release];
		menuEventToAbort = nil;
	}
	CHSuper(0, SpringBoard, menuButtonWasHeld);
}

CHMethod(0, void, SpringBoard, activatorMenuButtonTimerCompleted)
{
	[menuEventToAbort release];
	menuEventToAbort = nil;
	LAEvent *event = LASendEventWithName(LAEventNameMenuHoldShort);
	if ([event isHandled])
		menuEventToAbort = [event retain];
}

static NSUInteger lastVolumeEvent;

CHMethod(1, void, SpringBoard, volumeChanged, GSEventRef, gsEvent)
{
	CHSuper(1, SpringBoard, volumeChanged, gsEvent);
	switch (GSEventGetType(gsEvent)) {
		case kGSEventVolumeUpKeyReleased:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorCancelVolumeChord) object:nil];
			if (lastVolumeEvent == kGSEventVolumeDownKeyReleased) {
				lastVolumeEvent = 0;
				LASendEventWithName(LAEventNameVolumeDownUp);
			} else {
				lastVolumeEvent = kGSEventVolumeUpKeyReleased;
				[self performSelector:@selector(activatorCancelVolumeChord) withObject:nil afterDelay:kButtonHoldDelay];
			}
			break;
		case kGSEventVolumeDownKeyReleased:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorCancelVolumeChord) object:nil];
			if (lastVolumeEvent == kGSEventVolumeUpKeyReleased) {
				lastVolumeEvent = 0;
				LASendEventWithName(LAEventNameVolumeUpDown);
			} else {
				lastVolumeEvent = kGSEventVolumeDownKeyReleased;
				[self performSelector:@selector(activatorCancelVolumeChord) withObject:nil afterDelay:kButtonHoldDelay];
			}
			break;
	}
}

CHMethod(0, void, SpringBoard, activatorCancelVolumeChord)
{
	lastVolumeEvent = 0;
}

CHMethod(0, BOOL, SBUIController, clickedMenuButton)
{
	if (![CHSharedInstance(SBIconController) isEditing])
		if ([LASendEventWithName(LAEventNameMenuPressSingle) isHandled])
			return YES;
	return CHSuper(0, SBUIController, clickedMenuButton);
}

CHMethod(0, void, SBUIController, finishLaunching)
{
	if (!quickDoButton)
		[[LASlideGestureWindow sharedInstance] setHidden:NO];
	CHSuper(0, SBUIController, finishLaunching);
}

CHMethod(2, void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (shouldInterceptMenuPresses) {
		if ([LASendEventWithName(LAEventNameMenuPressAtSpringBoard) isHandled])
			return;
	}
	CHSuper(2, SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

static BOOL hasSentPinchSpread;


CHMethod(1, id, SBIconScrollView, initWithFrame, CGRect, frame)
{
	if ((self = CHSuper(1, SBIconScrollView, initWithFrame, frame))) {
		// Add Pinch Gesture by allowing a nonstandard zoom (reuse the existing gesture)
		[self setMinimumZoomScale:0.95f];
	}
	return self;
}

CHMethod(2, void, SBIconScrollView, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	hasSentPinchSpread = NO;
	CHSuper(2, SBIconScrollView, touchesBegan, touches, withEvent, event);
}

CHMethod(1, void, SBIconScrollView, handlePinch, UIPinchGestureRecognizer *, pinchGesture)
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


CHMethod(0, id, SBIcon, initWithDefaultSize)
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

CHMethod(2, void, SBIcon, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	lastTouchesCount = 1;
	hasSentPinchSpread = NO;
	CHSuper(2, SBIcon, touchesBegan, touches, withEvent, event);
}

CHMethod(2, void, SBIcon, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
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


CHMethod(0, void, SBStatusBar, activatorHoldEventCompleted)
{
	if (!hasSentStatusBarEvent) {
		hasSentStatusBarEvent = YES;
		LASendEventWithName(LAEventNameStatusBarHold);
	}
}

CHMethod(2, void, SBStatusBar, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	[self performSelector:@selector(activatorHoldEventCompleted) withObject:nil afterDelay:kStatusBarHoldDelay];
	statusBarTouchDown = [[touches anyObject] locationInView:self];
	hasSentStatusBarEvent = NO;
	CHSuper(2, SBStatusBar, touchesBegan, touches, withEvent, event);
}

CHMethod(2, void, SBStatusBar, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
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

CHMethod(2, void, SBStatusBar, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorHoldEventCompleted) object:nil];
	if (!hasSentStatusBarEvent)
		if ([[touches anyObject] tapCount] == 2)
			LASendEventWithName(LAEventNameStatusBarTapDouble);
	CHSuper(2, SBStatusBar, touchesEnded, touches, withEvent, event);
}

NSInteger nowPlayingButtonIndex;

CHMethod(2, void, SBNowPlayingAlertItem, configure, BOOL, configure, requirePasscodeForActions, BOOL, requirePasscode)
{
	LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressDouble];
	NSString *listenerName = [activator assignedListenerNameForEvent:event];
	if ([activator listenerForEvent:event]) {
		CHSuper(2, SBNowPlayingAlertItem, configure, configure, requirePasscodeForActions, requirePasscode);
		NSString *title = [activator localizedTitleForListenerName:listenerName];
		id alertSheet = [self alertSheet];
		//[alertSheet setNumberOfRows:2];
		nowPlayingButtonIndex = [alertSheet addButtonWithTitle:title];
	} else {
		CHSuper(2, SBNowPlayingAlertItem, configure, configure, requirePasscodeForActions, requirePasscode);
	}
}

CHMethod(2, void, SBNowPlayingAlertItem, alertSheet, id, sheet, buttonClicked, NSInteger, buttonIndex)
{
	CHSuper(2, SBNowPlayingAlertItem, alertSheet, sheet, buttonClicked, buttonIndex);
	if (buttonIndex == nowPlayingButtonIndex + 1)
		LASendEventWithName(LAEventNameMenuPressDouble);
}

CHMethod(0, void, iHome, inject)
{
	CHSuper(0, iHome, inject);
	quickDoButton = [CHIvar(self, touchButton, UIButton *) retain];
	if (quickDoButton) {
		LASlideGestureWindow *sgw = [LASlideGestureWindow sharedInstance];
		[sgw setHidden:YES];
		[sgw acceptEventsFromControl:quickDoButton];
	}
}

CHConstructor
{  
	CHLoadLateClass(SpringBoard);
	CHHook(0, SpringBoard, _handleMenuButtonEvent);
	CHHook(0, SpringBoard, allowMenuDoubleTap);
	CHHook(0, SpringBoard, handleMenuDoubleTap);
	CHHook(1, SpringBoard, lockButtonDown);
	CHHook(0, SpringBoard, activatorFixStatusBar);
	CHHook(1, SpringBoard, lockButtonUp);
	CHHook(0, SpringBoard, lockButtonWasHeld);
	CHHook(0, SpringBoard, activatorLockButtonHoldCompleted);
	CHHook(0, SpringBoard, activatorLockButtonDoubleTapAborted);
	CHHook(1, SpringBoard, menuButtonDown);
	CHHook(1, SpringBoard, menuButtonUp);
	CHHook(0, SpringBoard, menuButtonWasHeld);
	CHHook(0, SpringBoard, activatorMenuButtonTimerCompleted);
	CHHook(1, SpringBoard, volumeChanged);
	CHHook(0, SpringBoard, activatorCancelVolumeChord);
	CHHook(0, SpringBoard, _showEditAlertView);
	
	CHLoadLateClass(SBUIController);
	CHHook(0, SBUIController, clickedMenuButton);
	CHHook(0, SBUIController, finishLaunching);

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
	CHHook(2, SBNowPlayingAlertItem, configure, requirePasscodeForActions);
	CHHook(2, SBNowPlayingAlertItem, alertSheet, buttonClicked);
	
	dlopen("/Library/MobileSubstrate/DynamicLibraries/mQuickDo.dylib", RTLD_LAZY);
	CHLoadLateClass(iHome);
	CHHook(0, iHome, inject);
	
	CHLoadLateClass(SBAwayController);
	CHLoadLateClass(SBStatusBarController);
}
