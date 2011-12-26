#import "libactivator-private.h"
#import "Constants.h"

#import <UIKit/UIKit2.h>

%config(generator=internal)

%hook UIStatusBar

static BOOL passThroughStatusBar;
static CGPoint statusBarTouchDown;
static BOOL hasSentStatusBarEvent;
static CFRunLoopTimerRef statusBarHoldTimer;
static CFRunLoopTimerRef statusBarTapTimer;

static void DestroyCurrentStatusBarHoldTimer()
{
	if (statusBarHoldTimer) {
		CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), statusBarHoldTimer, kCFRunLoopCommonModes);
		CFRelease(statusBarHoldTimer);
		statusBarHoldTimer = NULL;
	}
}

static void StatusBarHeldCallback(CFRunLoopTimerRef timer, void *info)
{
	DestroyCurrentStatusBarHoldTimer();
	if (!hasSentStatusBarEvent) {
		hasSentStatusBarEvent = YES;
		LASendEventWithName(LAEventNameStatusBarHold);
	}
}

static void DestroyCurrentStatusBarTapTimer()
{
	if (statusBarTapTimer) {
		CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), statusBarTapTimer, kCFRunLoopCommonModes);
		CFRelease(statusBarTapTimer);
		statusBarTapTimer = NULL;
	}
}

static void StatusBarTapCallback(CFRunLoopTimerRef timer, void *info)
{
	DestroyCurrentStatusBarTapTimer();
	if (!hasSentStatusBarEvent) {
		hasSentStatusBarEvent = YES;
		LASendEventWithName(LAEventNameStatusBarTapSingle);
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (passThroughStatusBar) {
		passThroughStatusBar = NO;
		%orig;
	} else {
		DestroyCurrentStatusBarHoldTimer();
		DestroyCurrentStatusBarTapTimer();
		statusBarHoldTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + kStatusBarHoldDelay, 0.0, 0, 0, StatusBarHeldCallback, NULL);
		CFRunLoopAddTimer(CFRunLoopGetCurrent(), statusBarHoldTimer, kCFRunLoopCommonModes);
		statusBarTouchDown = [[touches anyObject] locationInView:self];
		hasSentStatusBarEvent = NO;
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!hasSentStatusBarEvent) {
		DestroyCurrentStatusBarHoldTimer();
		DestroyCurrentStatusBarTapTimer();
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
			if (deltaY > kStatusBarVerticalSwipeThreshold && (kCFCoreFoundationVersionNumber < 675.00)) {
				hasSentStatusBarEvent = YES;
				LASendEventWithName(LAEventNameStatusBarSwipeDown);
			}
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	DestroyCurrentStatusBarHoldTimer();
	DestroyCurrentStatusBarTapTimer();
	if (!hasSentStatusBarEvent) {
		if ([[touches anyObject] tapCount] == 2)
			LASendEventWithName(LAEventNameStatusBarTapDouble);
		else {
			statusBarTapTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + kStatusBarTapDelay, 0.0, 0, 0, StatusBarTapCallback, NULL);
			CFRunLoopAddTimer(CFRunLoopGetCurrent(), statusBarTapTimer, kCFRunLoopCommonModes);
			passThroughStatusBar = YES;
			[self touchesBegan:touches withEvent:event];
			%orig;
		}
	}
}

%end
