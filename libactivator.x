#import "libactivator.h"
#import "LARemoteListener.h"
#import "libactivator-private.h"
#import "SimulatorCompat.h"
#import "LAMessaging.h"

#import <SpringBoard/SpringBoard.h>
#import <AppSupport/AppSupport.h>

#include <objc/runtime.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <execinfo.h>
#include <dlfcn.h>

NSString * const LAEventNameMenuPressAtSpringBoard = @"libactivator.menu.press.at-springboard";
NSString * const LAEventNameMenuPressSingle        = @"libactivator.menu.press.single";
NSString * const LAEventNameMenuPressDouble        = @"libactivator.menu.press.double";
NSString * const LAEventNameMenuPressTriple        = @"libactivator.menu.press.triple";
NSString * const LAEventNameMenuHoldShort          = @"libactivator.menu.hold.short";
NSString * const LAEventNameMenuHoldLong           = @"libactivator.menu.hold.long";

NSString * const LAEventNameLockHoldShort          = @"libactivator.lock.hold.short";
NSString * const LAEventNameLockPressDouble        = @"libactivator.lock.press.double";

NSString * const LAEventNameSpringBoardPinch       = @"libactivator.springboard.pinch";
NSString * const LAEventNameSpringBoardSpread      = @"libactivator.springboard.spread";

NSString * const LAEventNameStatusBarSwipeRight    = @"libactivator.statusbar.swipe.right";
NSString * const LAEventNameStatusBarSwipeLeft     = @"libactivator.statusbar.swipe.left";
NSString * const LAEventNameStatusBarTapDouble     = @"libactivator.statusbar.tap.double";
NSString * const LAEventNameStatusBarTapDoubleLeft = @"libactivator.statusbar.tap.double.left";
NSString * const LAEventNameStatusBarTapDoubleRight = @"libactivator.statusbar.tap.double.right";
NSString * const LAEventNameStatusBarTapSingle     = @"libactivator.statusbar.tap.single";
NSString * const LAEventNameStatusBarTapSingleLeft = @"libactivator.statusbar.tap.single.left";
NSString * const LAEventNameStatusBarTapSingleRight = @"libactivator.statusbar.tap.single.right";
NSString * const LAEventNameStatusBarHold          = @"libactivator.statusbar.hold";
NSString * const LAEventNameStatusBarHoldLeft      = @"libactivator.statusbar.hold.left";
NSString * const LAEventNameStatusBarHoldRight     = @"libactivator.statusbar.hold.right";

NSString * const LAEventNameVolumeDownUp           = @"libactivator.volume.down-up";
NSString * const LAEventNameVolumeUpDown           = @"libactivator.volume.up-down";
NSString * const LAEventNameVolumeDisplayTap       = @"libactivator.volume.display-tap";
NSString * const LAEventNameVolumeToggleMuteTwice  = @"libactivator.volume.toggle-mute-twice";
NSString * const LAEventNameVolumeDownHoldShort    = @"libactivator.volume.down.hold.short";
NSString * const LAEventNameVolumeUpHoldShort      = @"libactivator.volume.up.hold.short";
NSString * const LAEventNameVolumeDownPress        = @"libactivator.volume.down.press";
NSString * const LAEventNameVolumeUpPress          = @"libactivator.volume.up.press";
NSString * const LAEventNameVolumeBothPress        = @"libactivator.volume.both.press";

NSString * const LAEventNameSlideInFromBottom      = @"libactivator.slide-in.bottom";
NSString * const LAEventNameSlideInFromBottomLeft  = @"libactivator.slide-in.bottom-left";
NSString * const LAEventNameSlideInFromBottomRight = @"libactivator.slide-in.bottom-right";
NSString * const LAEventNameSlideInFromLeft        = @"libactivator.slide-in.left";
NSString * const LAEventNameSlideInFromLeftTop     = @"libactivator.slide-in.left-top";
NSString * const LAEventNameSlideInFromLeftBottom  = @"libactivator.slide-in.left-bottom";
NSString * const LAEventNameSlideInFromRight       = @"libactivator.slide-in.right";
NSString * const LAEventNameSlideInFromRightTop    = @"libactivator.slide-in.right-top";
NSString * const LAEventNameSlideInFromRightBottom = @"libactivator.slide-in.right-bottom";
NSString * const LAEventNameStatusBarSwipeDown     = @"libactivator.statusbar.swipe.down"; // Now a slide in gesture on iOS5.0+
NSString * const LAEventNameSlideInFromTopLeft     = @"libactivator.slide-in.top-left";
NSString * const LAEventNameSlideInFromTopRight    = @"libactivator.slide-in.top-right";

NSString * const LAEventNameTwoFingerSlideInFromBottom      = @"libactivator.two-finger-slide-in.bottom";
NSString * const LAEventNameTwoFingerSlideInFromBottomLeft  = @"libactivator.two-finger-slide-in.bottom-left";
NSString * const LAEventNameTwoFingerSlideInFromBottomRight = @"libactivator.two-finger-slide-in.bottom-right";
NSString * const LAEventNameTwoFingerSlideInFromLeft        = @"libactivator.two-finger-slide-in.left";
NSString * const LAEventNameTwoFingerSlideInFromLeftTop     = @"libactivator.two-finger-slide-in.left-top";
NSString * const LAEventNameTwoFingerSlideInFromLeftBottom  = @"libactivator.two-finger-slide-in.left-bottom";
NSString * const LAEventNameTwoFingerSlideInFromRight       = @"libactivator.two-finger-slide-in.right";
NSString * const LAEventNameTwoFingerSlideInFromRightTop    = @"libactivator.two-finger-slide-in.right-top";
NSString * const LAEventNameTwoFingerSlideInFromRightBottom = @"libactivator.two-finger-slide-in.right-bottom";
NSString * const LAEventNameTwoFingerSlideInFromTop         = @"libactivator.two-finger-slide-in.top";
NSString * const LAEventNameTwoFingerSlideInFromTopLeft     = @"libactivator.two-finger-slide-in.top-left";
NSString * const LAEventNameTwoFingerSlideInFromTopRight    = @"libactivator.two-finger-slide-in.top-right";

NSString * const LAEventNameMotionShake            = @"libactivator.motion.shake";

NSString * const LAEventNameHeadsetButtonPressSingle = @"libactivator.headset-button.press.single";
NSString * const LAEventNameHeadsetButtonHoldShort = @"libactivator.headset-button.hold.short";
NSString * const LAEventNameHeadsetConnected       = @"libactivator.headset.connected";
NSString * const LAEventNameHeadsetDisconnected    = @"libactivator.headset.disconnected";

NSString * const LAEventNameLockScreenClockDoubleTap = @"libactivator.lockscreen.clock.double-tap";

NSString * const LAEventNamePowerConnected         = @"libactivator.power.connected";
NSString * const LAEventNamePowerDisconnected      = @"libactivator.power.disconnected";


NSString * const LAEventModeSpringBoard = @"springboard";
NSString * const LAEventModeApplication = @"application";
NSString * const LAEventModeLockScreen  = @"lockscreen";

LAActivator *LASharedActivator;

NSMutableDictionary *listenerBundles;
NSMutableDictionary *listenerDictionaries;
NSBundle *activatorBundle;

static NSNull *sharedNull;

#define ListenerKeyForEventNameAndMode(eventName, eventMode) \
	[NSString stringWithFormat:@"LAEventListener(%@)-%@", (eventMode), (eventName)]

@interface UIDevice (OS32)
@property (nonatomic, readonly) NSInteger idiom;
@end

@interface UIScreen (OS4)
@property (nonatomic, readonly) CGFloat scale;
@end

@interface UIImage (OS4)
+ (UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale;
@end

CFMessagePortRef serverPort;

__attribute__((always_inline))
static inline void LAInvalidSpringBoardOperation(SEL _cmd)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	void *symbols[20];
	size_t size = backtrace(symbols, 20);
	NSString *culprit = nil;
	if (size) {
		char **strings = backtrace_symbols(symbols, size);
		for (int i = 0; i < size; i++) {
			NSString *description = [NSString stringWithUTF8String:strings[i]];
			culprit = [[[description componentsSeparatedByString:@" "] objectAtIndex:3] stringByDeletingPathExtension];
			if (![culprit isEqualToString:@"Activator"] && ![culprit isEqualToString:@"libactivator"])
				break;
		}
		free(strings);
	}
	NSDictionary *culpritDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithUTF8String:(char *)_cmd], @"selector",
		culprit, @"culprit",
		nil];
	[LASharedActivator performSelector:@selector(apiFailWithCulpritDictionary:) withObject:culpritDictionary afterDelay:0.0];
	NSLog(@"Activator: %@ called -[LAActivator %s] from outside SpringBoard. This is invalid!", culprit, _cmd);
	[pool drain];
}

#define LAInvalidSpringBoardOperation() LAInvalidSpringBoardOperation(_cmd)

@interface LAActivator () <UIAlertViewDelegate>
@end

@implementation LAActivator

+ (LAActivator *)sharedInstance
{
	return LASharedActivator;
}

- (NSString *)settingsFilePath
{
	return SCMobilePath(@"/Library/Caches/libactivator.plist");
}

- (id)init
{
	if (LASharedActivator) {
		[self release];
		return nil;
	}
	if ((self = [super init])) {
		sharedNull = [[NSNull null] retain];
		serverPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kLAMessageServerName);
		_availableEventModes = [[NSArray arrayWithObjects:LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen, nil] retain];
		// Caches
		_cachedListenerGroups = [[NSMutableDictionary alloc] init];
		_cachedListenerTitles = [[NSMutableDictionary alloc] init];
		_cachedListenerDescriptions = [[NSMutableDictionary alloc] init];
		_cachedListenerIcons = [[NSMutableDictionary alloc] init];
		_cachedListenerSmallIcons = [[NSMutableDictionary alloc] init];
		_listenerInstances = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
		LASharedActivator = self;
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	if (_listenerInstances)
		CFRelease(_listenerInstances);
	[_cachedListenerSmallIcons release];
	[_cachedListenerIcons release];
	[_cachedListenerDescriptions release];
	[_cachedListenerTitles release];
	[_cachedListenerGroups release];
	[_availableEventModes release];
	LASharedActivator = nil;
	[super dealloc];
}

- (void)didReceiveMemoryWarning
{
	[listenerBundles release];
	listenerBundles = nil;
	[listenerDictionaries release];
	listenerDictionaries = nil;
	@synchronized (self) {
		[_cachedListenerSmallIcons removeAllObjects];
	}
	[_cachedListenerIcons removeAllObjects];
	[_cachedListenerTitles removeAllObjects];
	[_cachedListenerDescriptions removeAllObjects];
	[_cachedListenerGroups removeAllObjects];
}

- (LAActivatorVersion)version
{
	return LAActivatorVersion_1_6_2;
}

- (BOOL)isRunningInsideSpringBoard
{
	return NO;
}

- (void)apiFailWithCulpritDictionary:(NSDictionary *)culpritDictionary
{
	if (UIApp) {
		UIAlertView *av = [[UIAlertView alloc] init];
		av.title = @"Invalid Operation";
		NSString *culprit = [culpritDictionary objectForKey:@"culprit"];
		NSString *selector = [culpritDictionary objectForKey:@"selector"];
		av.message = [NSString stringWithFormat:@"%@ has called -[LAActivator %@] improperly from outside SpringBoard.\nContact %@'s developer.", culprit, selector, culprit];
		[av addButtonWithTitle:@"OK"];
		[av show];
		[av release];
	}
}

// Preferences

- (void)_resetPreferences
{
	LASendOneWayMessage(LAMessageIdResetPreferences, NULL);
}

- (id)_getObjectForPreference:(NSString *)preference
{
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetPreference, (CFDataRef)LATransformStringToData(preference)), nil);
}

- (void)_setObject:(id)value forPreference:(NSString *)preference
{
	NSArray *args = [NSArray arrayWithObjects:preference, value, nil];
	LASendOneWayMessage(LAMessageIdSetPreference, (CFDataRef)LATransformPropertyListToData(args));
}

- (BOOL)isAlive
{
	CFMessagePortRef mp = LAGetServerPort();
	return mp && CFMessagePortIsValid(mp);
}

// Sending Events

- (BOOL)isDangerousToSendEvents
{
	return NO;
}

- (id<LAListener>)listenerForEvent:(LAEvent *)event
{
	return [self listenerForName:[self assignedListenerNameForEvent:event]];
}

static UIAlertView *inCydiaAlert;

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	inCydiaAlert.delegate = nil;
	[inCydiaAlert release];
	inCydiaAlert = nil;
}

- (void)sendEventToListener:(LAEvent *)event
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:event waitUntilDone:YES];
		return;
	}
	NSString *listenerName = [self assignedListenerNameForEvent:event];
	if (listenerName && [self listenerWithName:listenerName isCompatibleWithEventName:[event name]]) {
		if ([self isDangerousToSendEvents]) {
			NSString *eventName = event.name;
			if (![eventName isEqualToString:LAEventNameMenuPressSingle] &&
				![eventName isEqualToString:LAEventNameMenuPressDouble]
			) {
				if (!inCydiaAlert) {
					inCydiaAlert = [[UIAlertView alloc] init];
					inCydiaAlert.title = [self localizedStringForKey:@"ACTIVATOR" value:@"Activator"];
					inCydiaAlert.message = [self localizedStringForKey:@"IN_CYDIA_WARNING" value:@"It is potentially dangerous to perform actions while Cydia is installing software."];
					[inCydiaAlert addButtonWithTitle:[self localizedStringForKey:@"ALERT_OK" value:@"OK"]];
					inCydiaAlert.delegate = self;
				}
				[inCydiaAlert show];
			}
			NSLog(@"Activator: sendEventToListener:%@ (listener=%@) aborted in Cydia", event, listenerName);
			return;
		}
		NSString *displayIdentifier = self.displayIdentifierForCurrentApplication;
		if (displayIdentifier && [self applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier]) {
			NSLog(@"Activator: sendEventToListener:%@ (listener=%@) aborted in blacklisted app \"%@\"", event, listenerName, displayIdentifier);
			return;
		}
		id<LAListener> listener = [self listenerForName:listenerName];
		if (self._activeTouchCount && [[listener activator:self requiresInfoDictionaryValueOfKey:@"requires-no-touch-events" forListenerWithName:listenerName] boolValue]) {
			[self _deferReceiveEventUntilTouchesComplete:event listenerName:listenerName];
			event.handled = YES;
		} else {
			[listener activator:self receiveEvent:event forListenerName:listenerName];
		}
		if ([event isHandled])
			for (id<LAListener> otherListener in (NSSet *)_listenerInstances)
				if (otherListener != listener)
					[otherListener activator:self otherListenerDidHandleEvent:event];
	}
#ifdef DEBUG
	NSLog(@"Activator: sendEventToListener:%@ (listener=%@)", event, listenerName);
#endif
}

- (void)sendAbortToListener:(LAEvent *)event
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:event waitUntilDone:YES];
		return;
	}
	NSString *listenerName = [self assignedListenerNameForEvent:event];
	if ([self listenerWithName:listenerName isCompatibleWithEventName:[event name]])
		[[self listenerForName:listenerName] activator:self abortEvent:event forListenerName:listenerName];
#ifdef DEBUG
	NSLog(@"Activator: sendAbortToListener:%@ (listener=%@)", event, listenerName);
#endif
}

- (void)sendDeactivateEventToListeners:(LAEvent *)event
{
	if (event) {
		NSData *input = [NSKeyedArchiver archivedDataWithRootObject:event];
		event.handled = LAConsume(LATransformDataToBOOL, LASendTwoWayMessage(LAMessageIdSendDeactivateEventToListeners, (CFDataRef)input), NO);
	}
}

// Registration of listeners

- (id<LAListener>)listenerForName:(NSString *)name
{
	return [LARemoteListener sharedInstance];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name
{
	LAInvalidSpringBoardOperation();
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen
{
	LAInvalidSpringBoardOperation();
}

- (void)unregisterListenerWithName:(NSString *)name
{
	LAInvalidSpringBoardOperation();
}

- (BOOL)hasSeenListenerWithName:(NSString *)name
{
	NSString *key = [@"LAHasSeenListener-" stringByAppendingString:name];
	return [[self _getObjectForPreference:key] boolValue];
}

// Setting Assignments

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName
{
#ifdef DEBUG
	NSLog(@"Activator: assignEvent:%@ toListenerWithName:%@", event, listenerName);
#endif
	NSString *eventName = [event name];
	NSString *eventMode = [event mode];
	if ([eventMode length]) {
		if ([self eventWithName:eventName isCompatibleWithMode:eventMode])
			[self _setObject:listenerName forPreference:ListenerKeyForEventNameAndMode(eventName, eventMode)];
	} else {
		for (NSString *mode in _availableEventModes)
			if ([self eventWithName:eventName isCompatibleWithMode:mode])
				[self _setObject:listenerName forPreference:ListenerKeyForEventNameAndMode(eventName, mode)];
	}
}

- (void)unassignEvent:(LAEvent *)event
{
#ifdef DEBUG
	NSLog(@"Activator: unassignEvent:%@", event);
#endif
	NSString *eventName = [event name];
	NSString *eventMode = [event mode];
	if ([eventMode length]) {
		NSString *prefName = ListenerKeyForEventNameAndMode(eventName, eventMode);
		[self _setObject:nil forPreference:prefName];
	} else {
		for (NSString *mode in _availableEventModes) {
			NSString *prefName = ListenerKeyForEventNameAndMode(eventName, mode);
			[self _setObject:nil forPreference:prefName];
		}
	}
}

// Getting Assignments

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event
{
	NSString *eventName = event.name;
	NSString *eventMode = event.mode ?: [self currentEventMode];
	NSString *listenerName = [self _getObjectForPreference:ListenerKeyForEventNameAndMode(eventName, eventMode)];
	if ([self listenerWithName:listenerName isCompatibleWithMode:eventMode] &&
		[self listenerWithName:listenerName isCompatibleWithEventName:eventName])
	{
		return listenerName;
	}
	return nil;
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName
{
	NSArray *events = [self availableEventNames];
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *eventMode in _availableEventModes) {
		for (NSString *eventName in events) {
			NSString *prefName = ListenerKeyForEventNameAndMode(eventName, eventMode);
			NSString *assignedListener = [self _getObjectForPreference:prefName];
			if ([assignedListener isEqual:listenerName])
				[result addObject:[LAEvent eventWithName:eventName mode:eventMode]];
		}
	}
	return result;
}

// Events

- (NSArray *)availableEventNames
{
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetAvaliableEventNames, NULL), nil);
}

- (BOOL)eventWithNameIsHidden:(NSString *)name
{
	return LAConsume(LATransformDataToBOOL, LASendTwoWayMessage(LAMessageIdGetEventIsHidden, (CFDataRef)LATransformStringToData(name)), NO);
}

- (NSArray *)compatibleModesForEventWithName:(NSString *)name
{
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetCompatibleModesForEventName, (CFDataRef)LATransformStringToData(name)), nil);
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
	NSArray *args = [NSArray arrayWithObjects:eventMode, eventName, nil];
	return LAConsume(LATransformDataToBOOL, LASendTwoWayMessage(LAMessageIdGetEventWithNameIsCompatibleWithMode, (CFDataRef)LATransformPropertyListToData(args)), NO);
}

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName
{
	LAInvalidSpringBoardOperation();
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName
{
	LAInvalidSpringBoardOperation();
}

// Deferred events

- (NSInteger)_activeTouchCount
{
	return 0;
}

- (void)_deferReceiveEventUntilTouchesComplete:(LAEvent *)event listenerName:(NSString *)listenerName
{
}

// Listeners

- (NSArray *)availableListenerNames
{
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetListenerNames, NULL), nil);
}

- (NSDictionary *)_cachedAndSortedListeners
{
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetCachedAnsSortedListeners, NULL), nil);
}

- (void)_cacheAllListenerMetadata
{
	for (NSString *listenerName in self.availableListenerNames) {
		[self localizedTitleForListenerName:listenerName];
		[self localizedDescriptionForListenerName:listenerName];
	}
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name
{
	return [[self listenerForName:name] activator:self requiresInfoDictionaryValueOfKey:key forListenerWithName:name];
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name
{
	return [[[self listenerForName:name] activator:self requiresRequiresAssignmentForListenerName:name] boolValue];
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name;
{
	return [[self listenerForName:name] activator:self requiresCompatibleEventModesForListenerWithName:name] ?: _availableEventModes;
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithMode:(NSString *)eventMode
{
	if (listenerName)
		// TODO: optimize this
		return [[self compatibleEventModesForListenerWithName:listenerName] containsObject:eventMode];
	return YES;
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithEventName:(NSString *)eventName
{
	NSNumber *result = [[self listenerForName:listenerName] activator:self requiresIsCompatibleWithEventName:eventName listenerName:listenerName];
	return result ? [result boolValue] : YES;
}

- (UIImage *)iconForListenerName:(NSString *)listenerName
{
	UIImage *result;
	@synchronized (self) {
		result = [_cachedListenerIcons objectForKey:listenerName];
	}
	if (!result) {
		CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f;
		id<LAListener> listener = [self listenerForName:listenerName];
		result = [listener activator:self requiresIconForListenerName:listenerName scale:scale];
		if (!result) {
			NSData *data = [listener activator:self requiresIconDataForListenerName:listenerName scale:&scale];
			result = [UIImage imageWithData:data];
			if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)])
				result = [UIImage imageWithCGImage:result.CGImage scale:scale orientation:result.imageOrientation];
		}
		if (result) {
			@synchronized (self) {
				[_cachedListenerIcons setObject:result forKey:listenerName];
			}
		}
	}
	return result;
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName
{
	id result;
	@synchronized (self) {
		result = [_cachedListenerSmallIcons objectForKey:listenerName];
	}
	if (!result) {
		CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f;
		id<LAListener> listener = [self listenerForName:listenerName];
		result = [listener activator:self requiresSmallIconForListenerName:listenerName scale:scale];
		if (!result) {
			NSData *data = [listener activator:self requiresSmallIconDataForListenerName:listenerName scale:&scale];
			result = [UIImage imageWithData:data];
			if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)])
				result = [UIImage imageWithCGImage:[result CGImage] scale:scale orientation:[result imageOrientation]];
		}
		@synchronized (self) {
			[_cachedListenerSmallIcons setObject:result ?: sharedNull forKey:listenerName];
		}
	}
	return (result == sharedNull) ? nil : result;
}

- (UIImage *)cachedSmallIconForListenerName:(NSString *)listenerName
{
	@synchronized (self) {
		id result = [_cachedListenerSmallIcons objectForKey:listenerName];
		return (result == sharedNull) ? nil : result;
	}
}

// Event Modes

- (NSArray *)availableEventModes
{
	return _availableEventModes;
}

- (NSString *)currentEventMode
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetCurrentEventMode, NULL), nil);
}

- (NSString *)displayIdentifierForCurrentApplication
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetDisplayIdentifierForCurrentApplication, NULL), nil);
}

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier
{
	return [[self _getObjectForPreference:[@"LABlacklisted-" stringByAppendingString:displayIdentifier]] boolValue];
}

- (void)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted
{
	if (displayIdentifier)
		[self _setObject:blacklisted ? (id)kCFBooleanTrue : nil forPreference:[@"LABlacklisted-" stringByAppendingString:displayIdentifier]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<LAActivator listenerCount=%d eventCount=%d %p>", [[self availableListenerNames] count], [[self availableEventNames] count], self];
}

static inline NSURL *URLWithDeviceData(NSString *format)
{
	UIDevice *device = [UIDevice currentDevice];
	NSInteger idiom = [device respondsToSelector:@selector(idiom)] ? [device idiom] : 0;
	size_t size = 0;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char machine[size+1];
	if (sysctlbyname("hw.machine", machine, &size, NULL, 0) != 0)
		machine[0] = '\0';
	NSString *url = [NSString stringWithFormat:format, device.uniqueIdentifier, idiom, device.systemVersion, LASharedActivator.version, machine];
	return [NSURL URLWithString:url];
}

#define URLWithDeviceData(baseURL) URLWithDeviceData(baseURL"?udid=%@&idiom=%d&version=%@&activator=%d&machine=%s")

- (NSURL *)moreActionsURL
{
	return URLWithDeviceData(@"http://rpetri.ch/cydia/activator/actions/");
}

- (NSURL *)adPaneURL
{
	return URLWithDeviceData(@"http://rpetri.ch/cydia/activator/ads/");
}

- (NSBundle *)bundle
{
	return activatorBundle;
}

@end

@implementation LAActivator (Localization)

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value;
{
	return Localize(activatorBundle, key, value);
}

- (NSString *)localizedTitleForEventMode:(NSString *)eventMode
{
	if ([eventMode isEqual:LAEventModeSpringBoard])
		return Localize(activatorBundle, @"MODE_TITLE_springboard", @"At Home Screen");
	if ([eventMode isEqual:LAEventModeApplication])
		return Localize(activatorBundle, @"MODE_TITLE_application", @"In Application");
	if ([eventMode isEqual:LAEventModeLockScreen])
		return Localize(activatorBundle, @"MODE_TITLE_lockscreen", @"At Lock Screen");
	return Localize(activatorBundle, @"MODE_TITLE_all", @"Anytime");
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetLocalizedTitleForEventName, (CFDataRef)LATransformStringToData(eventName)), nil);
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName
{
	id result = [_cachedListenerTitles objectForKey:listenerName];
	if (result)
		return (result == sharedNull) ? nil : result;
	result = [[self listenerForName:listenerName] activator:self requiresLocalizedTitleForListenerName:listenerName];
	[_cachedListenerTitles setObject:result ?: sharedNull forKey:listenerName];
	return result;
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetLocalizedGroupForEventName, (CFDataRef)LATransformStringToData(eventName)), nil);
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName
{
	id result = [_cachedListenerGroups objectForKey:listenerName];
	if (result)
		return (result == sharedNull) ? nil : result;
	result = [[self listenerForName:listenerName] activator:self requiresLocalizedGroupForListenerName:listenerName];
	[_cachedListenerGroups setObject:result ?: sharedNull forKey:listenerName];
	return result;
}

- (NSString *)localizedDescriptionForEventMode:(NSString *)eventMode
{
	if ([eventMode isEqual:LAEventModeSpringBoard])
		return Localize(activatorBundle, @"MODE_DESCRIPTION_springboard", @"When SpringBoard icons are visible");
	if ([eventMode isEqual:LAEventModeApplication])
		return Localize(activatorBundle, @"MODE_DESCRIPTION_application", @"When an application is visible");
	if ([eventMode isEqual:LAEventModeLockScreen])
		return Localize(activatorBundle, @"MODE_DESCRIPTION_lockscreen", @"When is locked and lock screen is visible");
	return Localize(activatorBundle, @"MODE_DESCRIPTION_all", @"");
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetLocalizedDescriptionForEventName, (CFDataRef)LATransformStringToData(eventName)), nil);
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName
{
	id result = [_cachedListenerDescriptions objectForKey:listenerName];
	if (result)
		return (result == sharedNull) ? nil : result;
	result = [[self listenerForName:listenerName] activator:self requiresLocalizedDescriptionForListenerName:listenerName];
	[_cachedListenerDescriptions setObject:result ?: sharedNull forKey:listenerName];
	return result;
}

@end

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	%init;
	activatorBundle = [[NSBundle alloc] initWithPath:SCRootPath(@"/Library/Activator")];
	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		dlopen("/Library/Activator/SpringBoard.dylib", RTLD_LAZY);
	} else {
		[[LAActivator alloc] init];
		if ([bundleIdentifier isEqualToString:@"com.apple.Preferences"]) {
			// Prevent disabling PreferenceLoader
			// This has come up quite often where users can't get back in to change their settings
			if (!dlopen("/Library/MobileSubstrate/DynamicLibraries/PreferenceLoader.dylib", RTLD_LAZY)) {
				if (dlopen("/Library/MobileSubstrate/DynamicLibraries/PreferenceLoader.disabled", RTLD_LAZY)) {
					NSLog(@"Activator: PreferenceLoader was disabled; forced load!");
				}
			}
		}
	}
	[pool drain];
}
