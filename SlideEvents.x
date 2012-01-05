#import "libactivator-private.h"
#import "Constants.h"
#import "LASpringBoardActivator.h"

#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBGestureRecognizer.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <CaptainHook/CaptainHook.h>

%config(generator=internal)

__attribute__((visibility("hidden")))
@interface LASlideGestureWindow : UIWindow {
@private
	BOOL hasSentSlideEvent;
	NSString *_eventName;
}

+ (LASlideGestureWindow *)leftWindow;
+ (LASlideGestureWindow *)middleWindow;
+ (LASlideGestureWindow *)rightWindow;
+ (void)updateVisibility;

- (id)initWithFrame:(CGRect)frame eventName:(NSString *)eventName;

- (void)updateVisibility;

@end

static LASlideGestureWindow *leftSlideGestureWindow;
static LASlideGestureWindow *middleSlideGestureWindow;
static LASlideGestureWindow *rightSlideGestureWindow;

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
	if (!%c(SBOffscreenSwipeGestureRecognizer)) {
		[[LASlideGestureWindow leftWindow] updateVisibility];
		[[LASlideGestureWindow middleWindow] updateVisibility];
		[[LASlideGestureWindow rightWindow] updateVisibility];
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

static void *kStartedSlideGestureName;
#define SetStartedSlideGestureName(value) objc_setAssociatedObject(self, &kStartedSlideGestureName, value, OBJC_ASSOCIATION_ASSIGN)
#define GetStartedSlideGestureName() objc_getAssociatedObject(self, &kStartedSlideGestureName)

static void *kStartedTwoFingerSlideGestureName;
#define SetStartedTwoFingerSlideGestureName(value) objc_setAssociatedObject(self, &kStartedTwoFingerSlideGestureName, value, OBJC_ASSOCIATION_ASSIGN)
#define GetStartedTwoFingerSlideGestureName() objc_getAssociatedObject(self, &kStartedTwoFingerSlideGestureName)

static void *kRectToEnterToSendSlideGesture;
#define SetRectToEnterToSendSlideGesture(value) objc_setAssociatedObject(self, &kRectToEnterToSendSlideGesture, [NSValue valueWithCGRect:value], OBJC_ASSOCIATION_RETAIN_NONATOMIC)
#define GetRectToEnterToSendSlideGesture() [objc_getAssociatedObject(self, &kRectToEnterToSendSlideGesture) CGRectValue]

static NSInteger activeSlideGestures;

static inline BOOL SlideGestureStartWithRotatedLocation(id self, CGPoint location)
{
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	UIInterfaceOrientation interfaceOrientation = [(SpringBoard *)UIApp activeInterfaceOrientation];
	NSString *startedSlideGestureName;
	NSString *startedTwoFingerSlideGestureName;
	CGRect rectToEnterToSendSlideGesture;
	if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
		CGFloat temp = screenSize.width;
		screenSize.width = screenSize.height;
		screenSize.height = temp;
	}
	if (location.y + kSlideGestureWindowHeight >= screenSize.height) {
		if (location.x < screenSize.width * 0.25f) {
			startedSlideGestureName = LAEventNameSlideInFromBottomLeft;
			startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromBottomLeft;
		} else if (location.x < screenSize.width * 0.75f) {
			startedSlideGestureName = LAEventNameSlideInFromBottom;
			startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromBottom;
		} else {
			startedSlideGestureName = LAEventNameSlideInFromBottomRight;
			startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromBottomRight;
		}
		rectToEnterToSendSlideGesture = (CGRect){ { 0.0f, 0.0f }, { screenSize.width, screenSize.height - (kSlideGestureWindowHeight + 50.0f) }};
	} else if (location.y < kSlideGestureWindowHeight) {
		if (location.x < screenSize.width * 0.25f) {
			startedSlideGestureName = LAEventNameSlideInFromTopLeft;
			startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromTopLeft;
		} else if (location.x < screenSize.width * 0.75f) {
			startedSlideGestureName = LAEventNameSlideInFromTop;
			startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromTop;
		} else {
			startedSlideGestureName = LAEventNameSlideInFromTopRight;
			startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromTopRight;
		}
		rectToEnterToSendSlideGesture = (CGRect){ { 0.0f, kSlideGestureWindowHeight + 50.0f }, { screenSize.width, screenSize.height - (kSlideGestureWindowHeight + 50.0f) }};
	} else if (location.x < kSlideGestureWindowHeight) {
		startedSlideGestureName = LAEventNameSlideInFromLeft;
		startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromLeft;
		rectToEnterToSendSlideGesture = (CGRect){ { kSlideGestureWindowHeight + 50.0f, 0.0f }, { screenSize.width - (kSlideGestureWindowHeight + 50.0f), screenSize.height }};
	} else if (location.x >= screenSize.width - kSlideGestureWindowHeight) {
		startedSlideGestureName = LAEventNameSlideInFromRight;
		startedTwoFingerSlideGestureName = LAEventNameTwoFingerSlideInFromRight;
		rectToEnterToSendSlideGesture = (CGRect){ { 0.0f, 0.0f }, { screenSize.width - (kSlideGestureWindowHeight + 50.0f), screenSize.height }};
	} else {
#ifdef DEBUG
		NSLog(@"Activator: No slide gesture from %@", NSStringFromCGPoint(location));
#endif
		if (GetStartedSlideGestureName()) {
			SetStartedSlideGestureName(nil);
			SetStartedTwoFingerSlideGestureName(nil);
			activeSlideGestures--;
		}
		return NO;
	}
	if (![LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:startedSlideGestureName mode:LASharedActivator.currentEventMode]] && ![LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:startedTwoFingerSlideGestureName mode:LASharedActivator.currentEventMode]])  {
#ifdef DEBUG
		NSLog(@"Activator: No listener assigned to %@", startedSlideGestureName);
#endif
		if (GetStartedSlideGestureName()) {
			SetStartedSlideGestureName(nil);
			SetStartedTwoFingerSlideGestureName(nil);
			activeSlideGestures--;
		}
		return NO;
	}
#ifdef DEBUG
	NSLog(@"Activator: Rect to enter is %@ to trigger %@", NSStringFromCGRect(rectToEnterToSendSlideGesture), startedSlideGestureName);
#endif
	if (!GetStartedSlideGestureName())
		activeSlideGestures++;
	SetStartedSlideGestureName(startedSlideGestureName);
	SetStartedTwoFingerSlideGestureName(startedTwoFingerSlideGestureName);
	SetRectToEnterToSendSlideGesture(rectToEnterToSendSlideGesture);
	return YES;
}

static inline LAEvent *SlideGestureMoveWithRotatedLocation(id self, CGPoint location, NSInteger tapCount)
{
	if (CGRectContainsPoint(GetRectToEnterToSendSlideGesture(), location)) {
		NSString *gestureName = (tapCount == 1) ? GetStartedSlideGestureName() : GetStartedTwoFingerSlideGestureName();
		if (gestureName) {
#ifdef DEBUG
			NSLog(@"Activator: Sending %@ in rect %@", gestureName, NSStringFromCGRect(GetRectToEnterToSendSlideGesture()));
#endif
			SetRectToEnterToSendSlideGesture(CGRectZero);
			LAEvent *result = LASendEventWithName(gestureName);
			if (!result.handled) {
				SetStartedSlideGestureName(nil);
				SetStartedTwoFingerSlideGestureName(nil);
				activeSlideGestures--;
			}
			return result;
		}
	}
#ifdef DEBUG
	NSLog(@"Activator: Touch at %@ does not match rect %@", NSStringFromCGPoint(location), NSStringFromCGRect(GetRectToEnterToSendSlideGesture()));
#endif
	return nil;
}

static inline void SlideGestureClear(id self)
{
	if (GetStartedSlideGestureName()) {
		SetStartedSlideGestureName(nil);
		SetStartedTwoFingerSlideGestureName(nil);
		activeSlideGestures--;
	}
}

static CFMutableSetRef activeRecognizers;
static CFMutableDictionaryRef forcedOpenRecognizers;
static SBOffscreenSwipeGestureRecognizer *activeRecognizer;

%hook SBGestureRecognizer

- (id)init
{
	if ((self = %orig)) {
		if (!activeRecognizers) {
			activeRecognizers = CFSetCreateMutable(NULL, 0, NULL);
			forcedOpenRecognizers = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
		}
		CFSetAddValue(activeRecognizers, self);
	}
	return self;
}

- (void)dealloc
{
	CFDictionaryRemoveValue(forcedOpenRecognizers, self);
	SlideGestureClear(self);
	if (activeRecognizer == self)
		activeRecognizer = nil;
	CFSetRemoveValue(activeRecognizers, self);
	%orig;
}

%end

%hook SBOffscreenSwipeGestureRecognizer

- (void)setState:(int)state
{
	if (state == 4) {
		if (!CFDictionaryContainsKey(forcedOpenRecognizers, self)) {
			CFDictionarySetValue(forcedOpenRecognizers, self, (id)self.handler ?: (id)[NSNull null]);
			self.handler = nil;
		}
	} else {
		%orig;
	}
}

- (void)reset
{
	const void *handler;
	if (CFDictionaryGetValueIfPresent(forcedOpenRecognizers, self, &handler)) {
		if (!self.handler && (handler != [NSNull null]))
			self.handler = handler;
		CFDictionaryRemoveValue(forcedOpenRecognizers, self);
	}
	if (activeRecognizer == self)
		activeRecognizer = nil;
	%orig;
}

- (void)touchesBegan:(SBGestureContextRef)touches
{
	if ([(SBBulletinListController *)[%c(SBBulletinListController) sharedInstance] listViewIsActive])
		%orig;
	else {
		%orig;
		SlideGestureStartWithRotatedLocation(self, CHIvar(self, m_activeTouches, SBGestureRecognizerTouchData).location);
	}
}

- (void)touchesMoved:(SBGestureContextRef)touches
{
	%orig;
	if (activeRecognizer) {
		if (activeRecognizer != self)
			SlideGestureClear(self);
	} else {
		LAEvent *event = SlideGestureMoveWithRotatedLocation(self, CHIvar(self, m_activeTouches, SBGestureRecognizerTouchData).location, CHIvar(self, m_activeTouchesCount, NSUInteger));
		if (event) {
			activeRecognizer = self;
			if (event.handled) {
				self.state = 2;
				[self sendTouchesCancelledToApplicationIfNeeded];
				for (SBGestureRecognizer *recognizer in (NSSet *)activeRecognizers)
					if (recognizer != self)
						recognizer.state = 4;
			}
		}
	}
}

- (void)touchesEnded:(SBGestureContextRef)touches
{
	%orig;
	SlideGestureClear(self);
}

- (void)touchesCancelled:(SBGestureContextRef)touches
{
	%orig;
	SlideGestureClear(self);
}

%end

%hook SBBulletinListController

static BOOL waitingToSendBegan;

- (void)handleShowNotificationsGestureBeganWithTouchLocation:(CGPoint)touchLocation
{
	if (activeSlideGestures)
		waitingToSendBegan = YES;
	else {
		waitingToSendBegan = NO;
		%orig;
	}
}

- (void)handleShowNotificationsGestureChangedWithTouchLocation:(CGPoint)touchLocation velocity:(CGPoint)velocity
{
	if (!activeSlideGestures) {
		if (waitingToSendBegan)
			[self handleShowNotificationsGestureBeganWithTouchLocation:touchLocation];
		%orig;
	}
}

- (void)handleShowNotificationsGestureEndedWithVelocity:(CGPoint)velocity completion:(void (^)())completion
{
	if (activeSlideGestures)
		velocity.y = 0.0f;
	%orig;
}

%end

__attribute__((visibility("hidden")))
@interface ActivatorSlideGestureRecognizer : UIGestureRecognizer
@end

@implementation ActivatorSlideGestureRecognizer

- (void)dealloc
{
	SlideGestureClear(self);
	[super dealloc];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	self.state = SlideGestureStartWithRotatedLocation(self, [touch locationInView:self.view]) ? UIGestureRecognizerStatePossible : UIGestureRecognizerStateFailed;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.state == UIGestureRecognizerStatePossible) {
		NSInteger count = [touches count];
		if (count) {
			UITouch *touch = [touches anyObject];
			if (SlideGestureMoveWithRotatedLocation(self, [touch locationInView:self.view], count))
				self.state = UIGestureRecognizerStateRecognized;
		} else {
			self.state = UIGestureRecognizerStateFailed;
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	SlideGestureClear(self);
	if (self.state == UIGestureRecognizerStatePossible)
		self.state = UIGestureRecognizerStateFailed;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	SlideGestureClear(self);
	if (self.state == UIGestureRecognizerStatePossible)
		self.state = UIGestureRecognizerStateFailed;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
	return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
	return NO;
}

@end

%hook SBAwayView

- (id)initWithFrame:(CGRect)frame
{
	if (%c(SBOffscreenSwipeGestureRecognizer)) {
		if ((self = %orig)) {
			ActivatorSlideGestureRecognizer *recognizer = [[ActivatorSlideGestureRecognizer alloc] init];
			[self addGestureRecognizer:recognizer];
			[recognizer release];
		}
		return self;
	} else {
		return %orig;
	}
}

%end

%hook UIStatusBar

- (id)initWithFrame:(CGRect)frame showForegroundView:(BOOL)showForegroundView
{
	if ((self = %orig)) {
		ActivatorSlideGestureRecognizer *recognizer = [[ActivatorSlideGestureRecognizer alloc] init];
		[self addGestureRecognizer:recognizer];
		[recognizer release];
	}
	return self;
}

%end

%hook SBAwayController

- (void)_sendLockStateChangedNotification
{
	[LASlideGestureWindow updateVisibility];
	%orig;
}

%end

%hook SBUIController

- (void)tearDownIconListAndBar
{
	%orig;
	[LASlideGestureWindow updateVisibility];
	[(LASpringBoardActivator *)LASharedActivator _eventModeChanged];
}

- (void)restoreIconList:(BOOL)animate
{
	%orig;
	[LASlideGestureWindow updateVisibility];
	[(LASpringBoardActivator *)LASharedActivator _eventModeChanged];
}

- (void)lock
{
	%orig;
	[LASlideGestureWindow updateVisibility];
	[(LASpringBoardActivator *)LASharedActivator _eventModeChanged];
}

- (void)lockFromSource:(int)source
{
	%orig;
	[LASlideGestureWindow updateVisibility];
	[(LASpringBoardActivator *)LASharedActivator _eventModeChanged];
}

%end

%hook UIFenceController

- (NSSet *)_fenceableWindows
{
	// Don't fence our slider windows that way rotation animation will be immediate
	NSMutableSet *result = [[%orig mutableCopy] autorelease];
	if (leftSlideGestureWindow)
		[result removeObject:leftSlideGestureWindow];
	if (middleSlideGestureWindow)
		[result removeObject:middleSlideGestureWindow];
	if (rightSlideGestureWindow)
		[result removeObject:rightSlideGestureWindow];
	return result;
}

%end
