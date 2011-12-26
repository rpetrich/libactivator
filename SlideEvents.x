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

static NSString *startedSlideGestureName;
static CGFloat yCoordinateToPassToSendSlideGesture;

static inline BOOL SlideGestureStartWithRotatedLocation(CGPoint location)
{
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	UIInterfaceOrientation interfaceOrientation = [(SpringBoard *)UIApp activeInterfaceOrientation];
	if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
		CGFloat temp = screenSize.width;
		screenSize.width = screenSize.height;
		screenSize.height = temp;
	}
	if (location.y + kSlideGestureWindowHeight < screenSize.height) {
		startedSlideGestureName = nil;
		return NO;
	}
	if (location.x < screenSize.width * 0.25f)
		startedSlideGestureName = LAEventNameSlideInFromBottomLeft;
	else if (location.x < screenSize.width * 0.75f)
		startedSlideGestureName = LAEventNameSlideInFromBottom;
	else
		startedSlideGestureName = LAEventNameSlideInFromBottomRight;
	yCoordinateToPassToSendSlideGesture = screenSize.height - (kSlideGestureWindowHeight + 50.0f);
	return YES;
}

static inline BOOL SlideGestureMoveWithRotatedLocation(CGPoint location)
{
	if (location.y < yCoordinateToPassToSendSlideGesture) {
		BOOL result = LASendEventWithName(startedSlideGestureName).handled;
		startedSlideGestureName = nil;
		return result;
	}
	return NO;
}

%hook SBOffscreenSwipeGestureRecognizer
static SBOffscreenSwipeGestureRecognizer *forcedOpenGesture;

- (void)dealloc
{
	if (forcedOpenGesture == self)
		forcedOpenGesture = nil;
	%orig;
}

- (void)setState:(int)state
{
	if (state == 4)
		forcedOpenGesture = self;
	else
		%orig;
}

- (void)reset
{
	if (forcedOpenGesture == self)
		forcedOpenGesture = nil;
	%orig;
}

- (void)touchesBegan:(SBGestureContextRef)touches
{
	%orig;
	SlideGestureStartWithRotatedLocation(CHIvar(self, m_activeTouches, SBGestureRecognizerTouchData).location);
}

- (void)touchesMoved:(SBGestureContextRef)touches
{
	%orig;
	if (startedSlideGestureName)
		if (SlideGestureMoveWithRotatedLocation(CHIvar(self, m_activeTouches, SBGestureRecognizerTouchData).location))
			[self sendTouchesCancelledToApplicationIfNeeded];
}

- (void)touchesCancelled:(SBGestureContextRef)touches
{
	%orig;
	if (forcedOpenGesture == self)
		forcedOpenGesture = nil;
}

%end

__attribute__((visibility("hidden")))
@interface ActivatorSlideGestureRecognizer : UIGestureRecognizer
@end

@implementation ActivatorSlideGestureRecognizer

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	self.state = SlideGestureStartWithRotatedLocation([touch locationInView:self.view]) ? UIGestureRecognizerStatePossible : UIGestureRecognizerStateFailed;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (startedSlideGestureName) {
		if ([touches count] == 1) {
			UITouch *touch = [touches anyObject];
			if (SlideGestureMoveWithRotatedLocation([touch locationInView:self.view]))
				self.state = UIGestureRecognizerStateRecognized;
		} else {
			startedSlideGestureName = nil;
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	startedSlideGestureName = nil;
	if (self.state == UIGestureRecognizerStatePossible)
		self.state = UIGestureRecognizerStateFailed;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	startedSlideGestureName = nil;
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
