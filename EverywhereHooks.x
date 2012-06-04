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
static NSString *statusBarHoldEventName;
static NSString *statusBarTapEventName;
static NSString *statusBarDoubleTapEventName;

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
		LASendEventWithName(statusBarHoldEventName);
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
		LASendEventWithName(statusBarTapEventName);
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
		CGFloat width = self.bounds.size.width;
		CGFloat position = [[touches anyObject] locationInView:self].x;
		if (position < width * 0.25f) {
			statusBarHoldEventName = LAEventNameStatusBarHoldLeft;
			statusBarTapEventName = LAEventNameStatusBarTapSingleLeft;
			statusBarDoubleTapEventName = LAEventNameStatusBarTapDoubleLeft;
		} else if (position < width * 0.75f) {
			statusBarHoldEventName = LAEventNameStatusBarHold;
			statusBarTapEventName = LAEventNameStatusBarTapSingle;
			statusBarDoubleTapEventName = LAEventNameStatusBarTapDouble;
		} else {
			statusBarHoldEventName = LAEventNameStatusBarHoldRight;
			statusBarTapEventName = LAEventNameStatusBarTapSingleRight;
			statusBarDoubleTapEventName = LAEventNameStatusBarTapDoubleRight;
		}
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
			LASendEventWithName(statusBarDoubleTapEventName);
		else {
			statusBarTapTimer = CFRunLoopTimerCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + kStatusBarTapDelay, 0.0, 0, 0, StatusBarTapCallback, NULL);
			CFRunLoopAddTimer(CFRunLoopGetCurrent(), statusBarTapTimer, kCFRunLoopCommonModes);
			passThroughStatusBar = YES;
			[self touchesBegan:touches withEvent:event];
			%orig;
		}
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	DestroyCurrentStatusBarHoldTimer();
	DestroyCurrentStatusBarTapTimer();
	%orig;
}

%end

@interface PhoneRootViewController : UIViewController
@property (nonatomic, readonly) UITabBarController *tabBarViewController;
@end

@interface PhoneApplication : UIApplication
- (void)applicationOpenURL:(NSURL *)url;
- (PhoneRootViewController *)rootViewController;
@end

%hook PhoneApplication

- (void)applicationOpenURL:(NSURL *)url
{
	NSString *string = [url absoluteString];
	SEL selector;
	if ([string isEqualToString:@"mobilephone-recents:favorites"])
		selector = @selector(favoritesNavigationController);
	else if ([string isEqualToString:@"mobilephone-recents:contacts"])
		selector = @selector(contactsViewController);
	else if ([string isEqualToString:@"mobilephone-recents:keypad"])
		selector = @selector(keypadViewController);
	else {
		%orig;
		return;
	}
	%orig;
	UITabBarController *tabBarController = [self rootViewController].tabBarViewController;
	tabBarController.selectedViewController = objc_msgSend(tabBarController, selector);
}

%end
