#import "libactivator.h"
#import "libactivator-private.h"

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
NSString * const LAEventNameVolumeDisplayTap       = @"libactivator.volume.display-tap";

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
#define kWindowLevelTransparentTopMost     9999.0f
#define kAlmostTransparentColor            [[UIColor blackColor] colorWithAlphaComponent:(1.0f / 255.0f)]

CHDeclareClass(SpringBoard);
CHDeclareClass(iHome);
CHDeclareClass(SBUIController);
CHDeclareClass(SBIconController);
CHDeclareClass(SBIconScrollView);
CHDeclareClass(SBIcon);
CHDeclareClass(SBStatusBar);
CHDeclareClass(SBNowPlayingAlertItem);
CHDeclareClass(SBAwayController);
CHDeclareClass(VolumeControl);
CHDeclareClass(SBStatusBarController);

static BOOL shouldInterceptMenuPresses;
static BOOL shouldSuppressMenuReleases;
static BOOL shouldSuppressLockSound;
static BOOL shouldAddNowPlayingButton;

static LASlideGestureWindow *leftSlideGestureWindow;
static LASlideGestureWindow *middleSlideGestureWindow;
static LASlideGestureWindow *rightSlideGestureWindow;

static LAQuickDoDelegate *sharedQuickDoDelegate;
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

CHInline
static id<LAListener> LAListenerForEventWithName(NSString *eventName)
{
	return [activator listenerForEvent:[LAEvent eventWithName:eventName mode:[activator currentEventMode]]];
}

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

- (void)updateVisibility
{
	[self setHidden:[activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName]] == nil];
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
		hasSentSlideEvent = YES;
		LASendEventWithName(_eventName);
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	hasSentSlideEvent = NO;
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

@implementation LAVolumeTapWindow

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	LASendEventWithName(LAEventNameVolumeDisplayTap);
}

@end

CHOptimizedMethod(0, self, void, SpringBoard, _handleMenuButtonEvent)
{
	if (!shouldSuppressMenuReleases) {
		// Unfortunately there isn't a better way of doing this :(
		shouldInterceptMenuPresses = YES;
		CHSuper(0, SpringBoard, _handleMenuButtonEvent);
		shouldInterceptMenuPresses = NO;
	}
}

CHOptimizedMethod(0, self, BOOL, SpringBoard, allowMenuDoubleTap)
{
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
static BOOL wasLockedBefore;
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
	if (!isWaitingForLockDoubleTap)
		wasLockedBefore = [self isLocked];
	CHSuper(1, SpringBoard, lockButtonDown, event);
}

CHOptimizedMethod(0, new, void, SpringBoard, activatorFixStatusBar)
{
	[[CHClass(SBStatusBarController) sharedStatusBarController] setIsLockVisible:NO isTimeVisible:YES];
}

CHOptimizedMethod(1, self, void, SpringBoard, lockButtonUp, GSEventRef, event)
{
	if (lockHoldEventToAbort) {
		[lockHoldEventToAbort release];
		lockHoldEventToAbort = nil;
		NSTimer **timer = CHIvarRef([UIApplication sharedApplication], _lockButtonTimer, NSTimer *);
		if (timer) {
			[*timer invalidate];
			[*timer release];
			*timer = nil;
		}
	} else if (isWaitingForLockDoubleTap) {
		isWaitingForLockDoubleTap = NO;
		if (!wasLockedBefore) {
			BOOL oldAnimationsEnabled = [UIView areAnimationsEnabled];
			[UIView setAnimationsEnabled:NO];
			[[CHClass(SBAwayController) sharedAwayController] unlockWithSound:NO];
			[UIView setAnimationsEnabled:oldAnimationsEnabled];
		}
		suppressIsLocked = YES;
		if ([LASendEventWithName(LAEventNameLockPressDouble) isHandled]) {
			suppressIsLocked = NO;
			[self performSelector:@selector(activatorFixStatusBar) withObject:nil afterDelay:0.0f];
			NSTimer **timer = CHIvarRef([UIApplication sharedApplication], _lockButtonTimer, NSTimer *);
			if (timer) {
				[*timer invalidate];
				[*timer release];
				*timer = nil;
			}
		} else {
			suppressIsLocked = NO;
			shouldSuppressLockSound = YES;
			[CHSharedInstance(SBUIController) lock];
			shouldSuppressLockSound = NO;
			CHSuper(1, SpringBoard, lockButtonUp, event);
		}
	} else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorLockButtonHoldCompleted) object:nil];
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

CHOptimizedMethod(0, self, void, SpringBoard, _showEditAlertView)
{
	if (![LASendEventWithName(LAEventNameMotionShake) isHandled])
		CHSuper(0, SpringBoard, _showEditAlertView);
}

static LAEvent *menuEventToAbort;

CHOptimizedMethod(1, self, void, SpringBoard, menuButtonDown, GSEventRef, event)
{
	[self performSelector:@selector(activatorMenuButtonTimerCompleted) withObject:nil afterDelay:kButtonHoldDelay];
	shouldSuppressMenuReleases = NO;
	CHSuper(1, SpringBoard, menuButtonDown, event);
}

CHOptimizedMethod(1, self, void, SpringBoard, menuButtonUp, GSEventRef, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorMenuButtonTimerCompleted) object:nil];
	if (menuEventToAbort || shouldSuppressMenuReleases) {
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

CHOptimizedMethod(0, self, void, SpringBoard, menuButtonWasHeld)
{
	if (menuEventToAbort) {
		LAAbortEvent(menuEventToAbort);
		[menuEventToAbort release];
		menuEventToAbort = nil;
	}
	CHSuper(0, SpringBoard, menuButtonWasHeld);
}

CHOptimizedMethod(0, new, void, SpringBoard, activatorMenuButtonTimerCompleted)
{
	[menuEventToAbort release];
	menuEventToAbort = nil;
	LAEvent *event = LASendEventWithName(LAEventNameMenuHoldShort);
	if ([event isHandled])
		menuEventToAbort = [event retain];
}

static NSUInteger lastVolumeEvent;

CHOptimizedMethod(1, self, void, SpringBoard, volumeChanged, GSEventRef, gsEvent)
{
	CHSuper(1, SpringBoard, volumeChanged, gsEvent);
	switch (GSEventGetType(gsEvent)) {
		case kGSEventVolumeUpButtonUp:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorCancelVolumeChord) object:nil];
			if (lastVolumeEvent == kGSEventVolumeDownButtonUp) {
				lastVolumeEvent = 0;
				LASendEventWithName(LAEventNameVolumeDownUp);
			} else {
				lastVolumeEvent = kGSEventVolumeUpButtonUp;
				[self performSelector:@selector(activatorCancelVolumeChord) withObject:nil afterDelay:kButtonHoldDelay];
			}
			break;
		case kGSEventVolumeDownButtonUp:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorCancelVolumeChord) object:nil];
			if (lastVolumeEvent == kGSEventVolumeUpButtonUp) {
				lastVolumeEvent = 0;
				LASendEventWithName(LAEventNameVolumeUpDown);
			} else {
				lastVolumeEvent = kGSEventVolumeDownButtonUp;
				[self performSelector:@selector(activatorCancelVolumeChord) withObject:nil afterDelay:kButtonHoldDelay];
			}
			break;
		default:
			break;
	}
}

CHOptimizedMethod(0, new, void, SpringBoard, activatorCancelVolumeChord)
{
	lastVolumeEvent = 0;
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
	if (![CHSharedInstance(SBIconController) isEditing])
		if ([LASendEventWithName(LAEventNameMenuPressSingle) isHandled])
			return YES;
	return CHSuper(0, SBUIController, clickedMenuButton);
}

CHOptimizedMethod(0, self, void, SBUIController, finishLaunching)
{
	if (!CHClass(iHome)) {
		CHLoadLateClass(iHome);
		CHHook(0, iHome, inject);
	}
	CHSuper(0, SBUIController, finishLaunching);
	[LASlideGestureWindow updateVisibility];
}

CHOptimizedMethod(0, self, void, SBUIController, tearDownIconListAndBar)
{
	CHSuper(0, SBUIController, tearDownIconListAndBar);
	[LASlideGestureWindow updateVisibility];
	[activator _eventModeChanged];
}

CHOptimizedMethod(1, self, void, SBUIController, restoreIconList, BOOL, animate)
{
	CHSuper(1, SBUIController, restoreIconList, animate);
	[LASlideGestureWindow updateVisibility];
	[activator _eventModeChanged];
}

CHOptimizedMethod(0, self, void, SBUIController, lock)
{
	CHSuper(0, SBUIController, lock);
	[LASlideGestureWindow updateVisibility];
	[activator _eventModeChanged];
}

CHOptimizedMethod(2, self, void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (shouldInterceptMenuPresses) {
		shouldInterceptMenuPresses = NO;
		if ([LASendEventWithName(LAEventNameMenuPressAtSpringBoard) isHandled])
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
	hasSentPinchSpread = NO;
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

NSInteger nowPlayingButtonIndex;

CHOptimizedMethod(2, self, void, SBNowPlayingAlertItem, configure, BOOL, configure, requirePasscodeForActions, BOOL, requirePasscode)
{
	LAEvent *event = [LAEvent eventWithName:LAEventNameMenuPressDouble];
	if (shouldAddNowPlayingButton && [activator assignedListenerNameForEvent:event]) {
		CHSuper(2, SBNowPlayingAlertItem, configure, configure, requirePasscodeForActions, requirePasscode);
		NSString *listenerName = [activator assignedListenerNameForEvent:event];
		NSString *title = [activator localizedTitleForListenerName:listenerName];
		id alertSheet = [self alertSheet];
		//[alertSheet setNumberOfRows:2];
		nowPlayingButtonIndex = [alertSheet addButtonWithTitle:title];
	} else {
		nowPlayingButtonIndex = -1000;
		CHSuper(2, SBNowPlayingAlertItem, configure, configure, requirePasscodeForActions, requirePasscode);
	}
}

CHOptimizedMethod(2, self, void, SBNowPlayingAlertItem, alertSheet, id, sheet, buttonClicked, NSInteger, buttonIndex)
{
	CHSuper(2, SBNowPlayingAlertItem, alertSheet, sheet, buttonClicked, buttonIndex);
	if (buttonIndex == nowPlayingButtonIndex + 1)
		LASendEventWithName(LAEventNameMenuPressDouble);
}

CHOptimizedMethod(0, self, void, SBAwayController, playLockSound)
{
	if (!shouldSuppressLockSound)
		CHSuper(0, SBAwayController, playLockSound);
}

static LAVolumeTapWindow *volumeTapWindow;

CHOptimizedMethod(0, self, void, VolumeControl, _createUI)
{
	if (LAListenerForEventWithName(LAEventNameVolumeDisplayTap)) {
		CHSuper(0, VolumeControl, _createUI);
		UIWindow *window = CHIvar(self, _volumeWindow, UIWindow *);
		if (window) {
			if (volumeTapWindow)
				[volumeTapWindow setFrame:[window frame]];
			else
				volumeTapWindow = [[LAVolumeTapWindow alloc] initWithFrame:[window frame]];
			[volumeTapWindow setWindowLevel:kWindowLevelTransparentTopMost];
			[volumeTapWindow setBackgroundColor:kAlmostTransparentColor]; // Content seems to be required for swipe gestures to work in-app
			[volumeTapWindow setHidden:NO];
		}
	} else {
		CHSuper(0, VolumeControl, _createUI);
	}
}

CHOptimizedMethod(0, self, void, VolumeControl, _tearDown)
{
	[volumeTapWindow setHidden:YES];
	[volumeTapWindow release];
	volumeTapWindow = nil;
	CHSuper(0, VolumeControl, _tearDown);
}

CHConstructor
{  
	CHLoadLateClass(SpringBoard);
	CHHook(0, SpringBoard, _handleMenuButtonEvent);
	CHHook(0, SpringBoard, allowMenuDoubleTap);
	CHHook(0, SpringBoard, handleMenuDoubleTap);
	CHHook(0, SpringBoard, isLocked);
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
	CHHook(0, SBUIController, tearDownIconListAndBar);
	CHHook(1, SBUIController, restoreIconList);
	CHHook(0, SBUIController, lock);

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
	
	CHLoadLateClass(SBAwayController);
	CHHook(0, SBAwayController, playLockSound);

	CHLoadLateClass(VolumeControl);
	CHHook(0, VolumeControl, _createUI);
	CHHook(0, VolumeControl, _tearDown);

	CHLoadLateClass(iHome);
	if (CHClass(iHome))
		CHHook(0, iHome, inject);
	
	CHLoadLateClass(SBStatusBarController);
}
