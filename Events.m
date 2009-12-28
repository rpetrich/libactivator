#import "libactivator.h"

#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>
#import <UIKit/UIKit-Private.h>

NSString * const LAEventNameMenuPressAtSpringBoard = @"libactivator.menu.press.at-springboard";
NSString * const LAEventNameMenuPressSingle        = @"libactivator.menu.press.single";
NSString * const LAEventNameMenuPressDouble        = @"libactivator.menu.press.double";
NSString * const LAEventNameMenuHoldShort          = @"libactivator.menu.hold.short";

NSString * const LAEventNameLockHoldShort          = @"libactivator.lock.hold.short";

NSString * const LAEventNameSpringBoardPinch       = @"libactivator.springboard.pinch";
NSString * const LAEventNameSpringBoardSpread      = @"libactivator.springboard.spread";

NSString * const LAEventNameStatusBarSwipeRight    = @"libactivator.statusbar.swipe.right";
NSString * const LAEventNameStatusBarSwipeLeft     = @"libactivator.statusbar.swipe.left";
NSString * const LAEventNameStatusBarSwipeDown     = @"libactivator.statusbar.swipe.down";
NSString * const LAEventNameStatusBarTapDouble     = @"libactivator.statusbar.tap.double";
NSString * const LAEventNameStatusBarHold          = @"libactivator.statusbar.hold";

#define kSpringBoardPinchThreshold         0.95f
#define kSpringBoardSpreadThreshold        1.05f
#define kButtonHoldDelay                   1.0f
#define kStatusBarHorizontalSwipeThreshold 50.0f
#define kStatusBarVerticalSwipeThreshold   10.0f
#define kStatusBarHoldDelay                0.5f

CHInline
static LAEvent *LASendEventWithName(NSString *eventName)
{
	LAEvent *event = [[[LAEvent alloc] initWithName:eventName] autorelease];
	[[LAActivator sharedInstance] sendEventToListener:event];
	return event;
}

CHInline
static void LAAbortEvent(LAEvent *event)
{
	[[LAActivator sharedInstance] sendAbortToListener:event];
}

static BOOL shouldInterceptMenuPresses;

CHDeclareClass(SpringBoard);
CHDeclareClass(SBUIController);
CHDeclareClass(SBIconController);
CHDeclareClass(SBIconScrollView);
CHDeclareClass(SBIcon);
CHDeclareClass(SBStatusBar);

CHMethod0(void, SpringBoard, _handleMenuButtonEvent)
{
	// Unfortunately there isn't a better way of doing this :(
	shouldInterceptMenuPresses = YES;
	CHSuper0(SpringBoard, _handleMenuButtonEvent);
	shouldInterceptMenuPresses = NO;
}

CHMethod0(BOOL, SpringBoard, allowMenuDoubleTap)
{
	CHSuper0(SpringBoard, allowMenuDoubleTap);
	return YES;
}

CHMethod0(void, SpringBoard, handleMenuDoubleTap)
{
	if ([LASendEventWithName(LAEventNameMenuPressDouble) isHandled])
		return;
	CHSuper0(SpringBoard, handleMenuDoubleTap);
}

static LAEvent *lockEventToAbort;

CHMethod1(void, SpringBoard, lockButtonDown, GSEventRef, event)
{
	[self performSelector:@selector(activatorLockButtonTimerCompleted) withObject:nil afterDelay:kButtonHoldDelay];
	CHSuper1(SpringBoard, lockButtonDown, event);
}

CHMethod1(void, SpringBoard, lockButtonUp, GSEventRef, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorLockButtonTimerCompleted) object:nil];
	if (lockEventToAbort) {
		[lockEventToAbort release];
		lockEventToAbort = nil;
		NSTimer **timer = CHIvarRef([UIApplication sharedApplication], _lockButtonTimer, NSTimer *);
		if (timer) {
			[*timer invalidate];
			[*timer release];
			*timer = nil;
		}
	} else {
		CHSuper1(SpringBoard, lockButtonUp, event);
	}
}

CHMethod0(void, SpringBoard, lockButtonWasHeld)
{
	if (lockEventToAbort) {
		LAAbortEvent(lockEventToAbort);
		[lockEventToAbort release];
		lockEventToAbort = nil;
	}
	CHSuper0(SpringBoard, lockButtonWasHeld);
}

CHMethod0(void, SpringBoard, activatorLockButtonTimerCompleted)
{
	[lockEventToAbort release];
	lockEventToAbort = nil;
	LAEvent *event = LASendEventWithName(LAEventNameLockHoldShort);
	if ([event isHandled])
		lockEventToAbort = [event retain];
}

static LAEvent *menuEventToAbort;

CHMethod1(void, SpringBoard, menuButtonDown, GSEventRef, event)
{
	[self performSelector:@selector(activatorMenuButtonTimerCompleted) withObject:nil afterDelay:kButtonHoldDelay];
	CHSuper1(SpringBoard, menuButtonDown, event);
}

CHMethod1(void, SpringBoard, menuButtonUp, GSEventRef, event)
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
		CHSuper1(SpringBoard, menuButtonUp, event);
	}
}

CHMethod0(void, SpringBoard, menuButtonWasHeld)
{
	if (lockEventToAbort) {
		LAAbortEvent(menuEventToAbort);
		[menuEventToAbort release];
		menuEventToAbort = nil;
	}
	CHSuper0(SpringBoard, menuButtonWasHeld);
}

CHMethod0(void, SpringBoard, activatorMenuButtonTimerCompleted)
{
	[menuEventToAbort release];
	menuEventToAbort = nil;
	LAEvent *event = LASendEventWithName(LAEventNameMenuHoldShort);
	if ([event isHandled])
		menuEventToAbort = [event retain];
}


CHMethod0(BOOL, SBUIController, clickedMenuButton)
{
	if (![CHSharedInstance(SBIconController) isEditing])
		if ([LASendEventWithName(LAEventNameMenuPressSingle) isHandled])
			return YES;
	return CHSuper0(SBUIController, clickedMenuButton);
}


CHMethod2(void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (shouldInterceptMenuPresses) {
		if ([LASendEventWithName(LAEventNameMenuPressAtSpringBoard) isHandled])
			return;
	}
	CHSuper2(SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

static BOOL hasSentPinchSpread;


CHMethod1(id, SBIconScrollView, initWithFrame, CGRect, frame)
{
	if ((self = CHSuper1(SBIconScrollView, initWithFrame, frame))) {
		// Add Pinch Gesture by allowing a nonstandard zoom (reuse the existing gesture)
		[self setMinimumZoomScale:0.95f];
	}
	return self;
}

CHMethod2(void, SBIconScrollView, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	hasSentPinchSpread = NO;
	CHSuper2(SBIconScrollView, touchesBegan, touches, withEvent, event);
}

CHMethod1(void, SBIconScrollView, handlePinch, UIPinchGestureRecognizer *, pinchGesture)
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


CHMethod0(id, SBIcon, initWithDefaultSize)
{
	// Enable multitouch
	if ((self = CHSuper0(SBIcon, initWithDefaultSize))) {
		[self setMultipleTouchEnabled:YES];
	}
	return self;
}

// SBIcons don't seem to respond to the pinch gesture (and eat it for pinch gestures on superviews), so this hack is necessary. Hopefully something better can be found
static NSInteger lastTouchesCount;
static CGFloat startingDistanceSquared;

CHMethod2(void, SBIcon, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	lastTouchesCount = 1;
	hasSentPinchSpread = NO;
	CHSuper2(SBIcon, touchesBegan, touches, withEvent, event);
}

CHMethod2(void, SBIcon, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
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
	CHSuper2(SBIcon, touchesMoved, touches, withEvent, event);
}

static CGPoint statusBarTouchDown;
static BOOL hasSentStatusBarEvent;


CHMethod0(void, SBStatusBar, activatorHoldEventCompleted)
{
	if (!hasSentStatusBarEvent) {
		hasSentStatusBarEvent = YES;
		LASendEventWithName(LAEventNameStatusBarHold);
	}
}

CHMethod2(void, SBStatusBar, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event)
{
	[self performSelector:@selector(activatorHoldEventCompleted) withObject:nil afterDelay:kStatusBarHoldDelay];
	statusBarTouchDown = [[touches anyObject] locationInView:self];
	hasSentStatusBarEvent = NO;
	CHSuper2(SBStatusBar, touchesBegan, touches, withEvent, event);
}

CHMethod2(void, SBStatusBar, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
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
	CHSuper2(SBStatusBar, touchesMoved, touches, withEvent, event);
}

CHMethod2(void, SBStatusBar, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatorHoldEventCompleted) object:nil];
	if (!hasSentStatusBarEvent)
		if ([[touches anyObject] tapCount] == 2)
			LASendEventWithName(LAEventNameStatusBarTapDouble);
	CHSuper2(SBStatusBar, touchesEnded, touches, withEvent, event);
}

CHConstructor
{
	CHLoadLateClass(SpringBoard);
	CHHook0(SpringBoard, _handleMenuButtonEvent);
	CHHook0(SpringBoard, allowMenuDoubleTap);
	CHHook0(SpringBoard, handleMenuDoubleTap);
	CHHook1(SpringBoard, lockButtonDown);
	CHHook1(SpringBoard, lockButtonUp);
	CHHook0(SpringBoard, lockButtonWasHeld);
	CHHook0(SpringBoard, activatorLockButtonTimerCompleted);
	CHHook1(SpringBoard, menuButtonDown);
	CHHook1(SpringBoard, menuButtonUp);
	CHHook0(SpringBoard, menuButtonWasHeld);
	CHHook0(SpringBoard, activatorMenuButtonTimerCompleted);
	
	CHLoadLateClass(SBUIController);
	CHHook0(SBUIController, clickedMenuButton);

	CHLoadLateClass(SBIconController);
	CHHook2(SBIconController, scrollToIconListAtIndex, animate);
	
	CHLoadLateClass(SBIconScrollView);
	CHHook1(SBIconScrollView, initWithFrame);
	CHHook2(SBIconScrollView, touchesBegan, withEvent);
	CHHook1(SBIconScrollView, handlePinch);
	
	CHLoadLateClass(SBIcon);
	CHHook0(SBIcon, initWithDefaultSize);
	CHHook2(SBIcon, touchesBegan, withEvent);
	CHHook2(SBIcon, touchesMoved, withEvent);
	
	CHLoadLateClass(SBStatusBar);
	CHHook0(SBStatusBar, activatorHoldEventCompleted);
	CHHook2(SBStatusBar, touchesBegan, withEvent);
	CHHook2(SBStatusBar, touchesMoved, withEvent);
	CHHook2(SBStatusBar, touchesEnded, withEvent);
}
