#import "libactivator.h"

#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>
#import <UIKit/UIKit-Private.h>

NSString * const LAEventNameMenuSinglePress       = @"libactivator.menu.single-press";
NSString * const LAEventNameMenuDoublePress       = @"libactivator.menu.double-press";
NSString * const LAEventNameMenuShortHold         = @"libactivator.menu.short-hold";

NSString * const LAEventNameLockShortHold         = @"libactivator.lock.short-hold";

NSString * const LAEventNameMenuSpringBoardPinch  = @"libactivator.springboard.pinch";
NSString * const LAEventNameMenuSpringBoardSpread = @"libactivator.springboard.spread";

#define kPinchThreshold  0.95f
#define kSpreadThreshold 1.05f
#define kButtonHoldDelay 1.0f

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
	if ([LASendEventWithName(LAEventNameMenuDoublePress) isHandled])
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
	[lockEventToAbort release];
	lockEventToAbort = nil;
	CHSuper1(SpringBoard, lockButtonUp, event);
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
	LAEvent *event = LASendEventWithName(LAEventNameLockShortHold);
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
	[menuEventToAbort release];
	menuEventToAbort = nil;
	CHSuper1(SpringBoard, menuButtonUp, event);
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
	LAEvent *event = LASendEventWithName(LAEventNameMenuShortHold);
	if ([event isHandled])
		menuEventToAbort = [event retain];
}

CHDeclareClass(SBIconController);

CHMethod2(void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (shouldInterceptMenuPresses) {
		if ([LASendEventWithName(LAEventNameMenuSinglePress) isHandled])
			return;
	}
	CHSuper2(SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

CHDeclareClass(SBIconScrollView);

CHMethod1(id, SBIconScrollView, initWithFrame, CGRect, frame)
{
	if ((self = CHSuper1(SBIconScrollView, initWithFrame, frame))) {
		// Add Pinch Gesture by allowing a nonstandard zoom (reuse the existing gesture)
		[self setMinimumZoomScale:0.95f];
	}
	return self;
}

CHMethod1(void, SBIconScrollView, handlePinch, UIPinchGestureRecognizer *, pinchGesture)
{
	CGFloat scale = [pinchGesture scale];
	if (scale < kPinchThreshold)
		LASendEventWithName(LAEventNameMenuSpringBoardPinch);
	else if (scale > kSpreadThreshold)
		LASendEventWithName(LAEventNameMenuSpringBoardSpread);
}

CHDeclareClass(SBIcon);

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
	CHSuper2(SBIcon, touchesBegan, touches, withEvent, event);
}

CHMethod2(void, SBIcon, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event)
{
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
		else if (currentDistanceSquared < startingDistanceSquared * (kPinchThreshold * kPinchThreshold))
			LASendEventWithName(LAEventNameMenuSpringBoardPinch);
		else if (currentDistanceSquared > startingDistanceSquared * (kSpreadThreshold * kSpreadThreshold))
			LASendEventWithName(LAEventNameMenuSpringBoardSpread);
	}
	lastTouchesCount = allTouchesCount;
	CHSuper2(SBIcon, touchesMoved, touches, withEvent, event);
}

CHMethod2(void, SBIcon, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event)
{
	lastTouchesCount = 0;
	CHSuper2(SBIcon, touchesEnded, touches, withEvent, event);
}

CHMethod2(void, SBIcon, touchesCancelled, NSSet *, touches, withEvent, UIEvent *, event)
{
	lastTouchesCount = 0;
	CHSuper2(SBIcon, touchesCancelled, touches, withEvent, event);
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

	CHLoadLateClass(SBIconController);
	CHHook2(SBIconController, scrollToIconListAtIndex, animate);
	
	CHLoadLateClass(SBIconScrollView);
	CHHook1(SBIconScrollView, initWithFrame);
	CHHook1(SBIconScrollView, handlePinch);
	
	CHLoadLateClass(SBIcon);
	CHHook0(SBIcon, initWithDefaultSize);
	CHHook2(SBIcon, touchesBegan, withEvent);
	CHHook2(SBIcon, touchesMoved, withEvent);
	CHHook2(SBIcon, touchesEnded, withEvent);
	CHHook2(SBIcon, touchesCancelled, withEvent);	
}
