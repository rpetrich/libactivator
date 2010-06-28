#import "libactivator.h"
#import "libactivator-private.h"
#import "LAApplicationListener.h"
#import "LAToggleListener.h"
#import "SimulatorCompat.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>
#import <AppSupport/AppSupport.h>

#include <objc/runtime.h>
#include <sys/stat.h>
#include <notify.h>

NSString * const LAEventModeSpringBoard = @"springboard";
NSString * const LAEventModeApplication = @"application";
NSString * const LAEventModeLockScreen  = @"lockscreen";

LAActivator *LASharedActivator;

CHDeclareClass(SBIconController);

#define ListenerKeyForEventNameAndMode(eventName, eventMode) \
	[NSString stringWithFormat:@"LAEventListener(%@)-%@", (eventMode), (eventName)]

#define InSpringBoard (!!_listeners)

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[LASharedActivator _reloadPreferences];
}

static NSInteger CompareListenerNamesCallback(id a, id b, void *context)
{
	return [[LASharedActivator localizedTitleForListenerName:a] localizedCaseInsensitiveCompare:[LASharedActivator localizedTitleForListenerName:b]];
}

@implementation LAActivator

#define LoadPreferences() do { \
	if (_preferences == nil) \
		if (!(_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:[self settingsFilePath]])) \
			_preferences = [[NSMutableDictionary alloc] init]; \
} while(0)

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
	if ((self = [super init])) {
		// Detect if we're inside SpringBoard
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
			CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
			[messagingCenter runServerOnCurrentThread];
			// Remote messages to id<LAListener> (with event)
			[messagingCenter registerForMessageName:@"activator:receiveEvent:forListenerName:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:abortEvent:forListenerName:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:otherListenerDidHandleEvent:forListenerName:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
			// Remote messages to id<LAListener> (without event)
			[messagingCenter registerForMessageName:@"activator:requiresLocalizedTitleForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresLocalizedDescriptionForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresLocalizedGroupForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresRequiresAssignmentForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresCompatibleEventModesForListenerWithName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresIconDataForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresSmallIconDataForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresIsCompatibleWithEventName:listenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresInfoDictionaryValueOfKey:forListenerWithName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			// Remote messages to LAActivator
			[messagingCenter registerForMessageName:@"_cachedAndSortedListeners" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"currentEventMode" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"availableListenerNames" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			// Preferences
			[messagingCenter registerForMessageName:@"setObjectForPreference" target:self selector:@selector(_setObjectForPreferenceFromMessageName:userInfo:)];
			[messagingCenter registerForMessageName:@"resetPreferences" target:self selector:@selector(_resetPreferences)];
			// Does not retain values!
			_listeners = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
  		}
		// Cache event data
		_eventData = [[NSMutableDictionary alloc] init];
		NSString *eventsPath = SCRootPath(@"/Library/Activator/Events");
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:eventsPath error:NULL])
			if (![fileName hasPrefix:@"."])
				[_eventData setObject:[NSBundle bundleWithPath:[eventsPath stringByAppendingPathComponent:fileName]] forKey:fileName];
		_cachedListenerTitles = [[NSMutableDictionary alloc] init];
		_cachedListenerGroups = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_cachedListenerTitles release];
	[_cachedListenerGroups release];
	[_cachedAndSortedListeners release];
	[_preferences release];
	[_listeners release];
	[_eventData release];
	[super dealloc];
}

- (LAActivatorVersion)version
{
	return LAActivatorVersion_1_3;
}

// Preferences

- (void)_reloadPreferences
{
#ifdef DEBUG
	NSLog(@"Activator: Reloading Preferences");
#endif
	[_preferences release];
	_preferences = nil;
}

- (void)_resetPreferences
{
	if (InSpringBoard) {
		unlink([[self settingsFilePath] UTF8String]);
		[(SpringBoard *)[UIApplication sharedApplication] relaunchSpringBoard];
		//notify_post("com.apple.language.changed");
	} else {
		CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
		[messagingCenter sendMessageName:@"resetPreferences" userInfo:nil];
	}
}

- (id)_getObjectForPreference:(NSString *)preference
{
	LoadPreferences();
	id value = [_preferences objectForKey:preference];
#ifdef DEBUG
	NSLog(@"Activator: Getting Preference %@ resulted in %@", preference, value);
#endif
	return value;
}

- (void)_setObjectForPreferenceFromMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
	[self _setObject:[userInfo objectForKey:@"value"] forPreference:[userInfo objectForKey:@"preference"]];
}

- (void)_setObject:(id)value forPreference:(NSString *)preference
{
	LoadPreferences();
	if (value)
		[_preferences setObject:value forKey:preference];
	else
		[_preferences removeObjectForKey:preference];
	if (InSpringBoard) {
#ifdef DEBUG
		NSLog(@"Activator: Setting preference %@ to %@", preference, value);
#endif
		CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)[self settingsFilePath], kCFURLPOSIXPathStyle, NO);
		CFWriteStreamRef stream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, url);
		CFRelease(url);
		CFWriteStreamOpen(stream);
		CFPropertyListWriteToStream((CFPropertyListRef)_preferences, stream, kCFPropertyListBinaryFormat_v1_0, NULL);
		CFWriteStreamClose(stream);
		CFRelease(stream);
		chmod([[self settingsFilePath] UTF8String], S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
		notify_post("libactivator.preferenceschanged");
	} else {
		// TODO: perform remote
		CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
		[messagingCenter sendMessageName:@"setObjectForPreference" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:preference, @"preference", value, @"value", nil]];
	}
}

- (NSDictionary *)_handleRemoteListenerEventMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	NSString *listenerName = [userInfo objectForKey:@"listenerName"];
	id<LAListener> listener = [self listenerForName:listenerName];
	LAEvent *event = [NSKeyedUnarchiver unarchiveObjectWithData:[userInfo objectForKey:@"event"]];
	objc_msgSend(listener, NSSelectorFromString(message), self, event, listenerName);
	id result = [NSKeyedArchiver archivedDataWithRootObject:event];
	return result ? [NSDictionary dictionaryWithObject:result forKey:@"result"] : [NSDictionary dictionary];
}

- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	NSString *listenerName = [userInfo objectForKey:@"listenerName"];
	id<LAListener> listener = [self listenerForName:listenerName];
	id result = objc_msgSend(listener, NSSelectorFromString(message), self, [userInfo objectForKey:@"object"], [userInfo objectForKey:@"object2"]);
	return result ? [NSDictionary dictionaryWithObject:result forKey:@"result"] : [NSDictionary dictionary];
}

- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	id withObject = [userInfo objectForKey:@"withObject"];
	id withObject2 = [userInfo objectForKey:@"withObject2"];
	id result = [self performSelector:NSSelectorFromString(message) withObject:withObject withObject:withObject2];
	return result ? [NSDictionary dictionaryWithObject:result forKey:@"result"] : [NSDictionary dictionary];
}

- (id)_performRemoteMessage:(SEL)selector withObject:(id)withObject
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:withObject, @"withObject", nil];
	NSDictionary *response = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	return [response objectForKey:@"result"];
}

- (NSDictionary *)_cachedAndSortedListeners
{
	if (_cachedAndSortedListeners)
		return _cachedAndSortedListeners;
	if (!InSpringBoard)
		return [self _performRemoteMessage:_cmd withObject:nil];
	NSMutableDictionary *listeners = [[NSMutableDictionary alloc] init];
	for (NSString *listenerName in [self availableListenerNames]) {
		NSString *key = [self localizedGroupForListenerName:listenerName] ?: @"";
		NSMutableArray *groupList = [listeners objectForKey:key];
		if (!groupList) {
			groupList = [NSMutableArray array];
			[listeners setObject:groupList forKey:key];
		}					
		[groupList addObject:listenerName];
	}
	for (NSString *key in [listeners allKeys]) {
		// Sort array and make static
		NSArray *array = [listeners objectForKey:key];
		array = [array sortedArrayUsingFunction:CompareListenerNamesCallback context:nil];
		[listeners setObject:array forKey:key];
	}
	_cachedAndSortedListeners = [listeners copy];
	[listeners release];
	return _cachedAndSortedListeners;
}

- (void)_eventModeChanged
{
	NSString *eventMode = [self currentEventMode];
	for (id<LAListener> listener in [_listeners allValues])
		[listener activator:self didChangeToEventMode:eventMode];
}


// Sending Events

- (id<LAListener>)listenerForEvent:(LAEvent *)event
{
	return [self listenerForName:[self assignedListenerNameForEvent:event]];
}

- (void)sendEventToListener:(LAEvent *)event
{
	NSString *listenerName = [self assignedListenerNameForEvent:event];
	id<LAListener> listener = [self listenerForName:listenerName];
	[listener activator:self receiveEvent:event forListenerName:listenerName];
	if ([event isHandled])
		for (NSString *other in [self availableListenerNames])
			if (![other isEqualToString:listenerName])
				[[self listenerForName:other] activator:self otherListenerDidHandleEvent:event forListenerName:other];
}

- (void)sendAbortToListener:(LAEvent *)event
{
	NSString *listenerName = [self assignedListenerNameForEvent:event];
	[[self listenerForName:listenerName] activator:self abortEvent:event forListenerName:listenerName];
}

- (void)sendDeactivateEventToListeners:(LAEvent *)event
{
	BOOL handled = [event isHandled];
	for (NSString *listenerName in [self availableListenerNames]) {
		[[self listenerForName:listenerName] activator:self receiveDeactivateEvent:event forListenerName:listenerName];
		handled |= [event isHandled];
	}
	[event setHandled:handled];
}

// Registration of listeners

- (id<LAListener>)listenerForName:(NSString *)name
{
	if (!InSpringBoard)
		return [LARemoteListener sharedInstance];
	return [_listeners objectForKey:name];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name
{
	[_cachedAndSortedListeners release];
	_cachedAndSortedListeners = nil;
	[_listeners setObject:listener forKey:name];
	NSString *key = [@"LAHasSeenListener-" stringByAppendingString:name];
	if (![[self _getObjectForPreference:key] boolValue])
		[self _setObject:(id)kCFBooleanTrue forPreference:key];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen
{
	[_cachedAndSortedListeners release];
	_cachedAndSortedListeners = nil;
	[_listeners setObject:listener forKey:name];
	if (!ignoreHasSeen) {
		NSString *key = [@"LAHasSeenListener-" stringByAppendingString:name];
		if (![[self _getObjectForPreference:key] boolValue])
			[self _setObject:(id)kCFBooleanTrue forPreference:key];
	}
}

- (void)unregisterListenerWithName:(NSString *)name
{
	[_cachedListenerTitles removeObjectForKey:name];
	[_cachedListenerGroups removeObjectForKey:name];
	[_cachedAndSortedListeners release];
	_cachedAndSortedListeners = nil;
	[_listeners removeObjectForKey:name];
}

- (BOOL)hasSeenListenerWithName:(NSString *)name
{
	NSString *key = [@"LAHasSeenListener-" stringByAppendingString:name];
	return [[self _getObjectForPreference:key] boolValue];
}

// Setting Assignments

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName
{
	NSString *eventName = [event name];
	NSString *eventMode = [event mode];
	if ([eventMode length]) {
		if ([self listenerWithName:listenerName isCompatibleWithMode:eventMode])
			if ([self eventWithName:eventName isCompatibleWithMode:eventMode])
				[self _setObject:listenerName forPreference:ListenerKeyForEventNameAndMode(eventName, eventMode)];
	} else {
		for (NSString *mode in [self compatibleEventModesForListenerWithName:listenerName])
			if ([self eventWithName:eventName isCompatibleWithMode:mode])
				[self _setObject:listenerName forPreference:ListenerKeyForEventNameAndMode(eventName, mode)];
	}
}

- (void)unassignEvent:(LAEvent *)event
{
	NSString *eventName = [event name];
	NSString *eventMode = [event mode];
	if ([eventMode length]) {
		NSString *prefName = ListenerKeyForEventNameAndMode(eventName, eventMode);
		if ([self _getObjectForPreference:prefName])
			[self _setObject:nil forPreference:prefName];
	} else {
		for (NSString *mode in [self availableEventModes]) {
			NSString *prefName = ListenerKeyForEventNameAndMode(eventName, mode);
			if ([self _getObjectForPreference:prefName])
				[self _setObject:nil forPreference:prefName];
		}
	}
}

// Getting Assignments

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event
{
	NSString *prefName = ListenerKeyForEventNameAndMode([event name], [event mode] ?: [self currentEventMode]);
	return [self _getObjectForPreference:prefName];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName
{
	NSArray *events = [self availableEventNames];
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *eventMode in [self availableEventModes]) {
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
	return [_eventData allKeys];
}

- (BOOL)eventWithNameIsHidden:(NSString *)name
{
	return [[[_eventData objectForKey:name] objectForInfoDictionaryKey:@"hidden"] boolValue];
}

- (NSArray *)compatibleModesForEventWithName:(NSString *)name
{
	return [[_eventData objectForKey:name] objectForInfoDictionaryKey:@"compatible-modes"] ?: [self availableEventModes];
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
	if (eventMode) {
		NSArray *compatibleModes = [[_eventData objectForKey:eventName] objectForInfoDictionaryKey:@"compatible-modes"];
		if (compatibleModes)
			return [compatibleModes containsObject:eventMode];
	}
	return YES;
}

// Listeners

- (NSArray *)availableListenerNames
{
	return InSpringBoard ? [_listeners allKeys] : [self _performRemoteMessage:_cmd withObject:nil];
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
	return [[self listenerForName:name] activator:self requiresCompatibleEventModesForListenerWithName:name] ?: [self availableEventModes];
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
	return [UIImage imageWithData:[[self listenerForName:listenerName] activator:self requiresIconDataForListenerName:listenerName]];
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName
{
	return [UIImage imageWithData:[[self listenerForName:listenerName] activator:self requiresSmallIconDataForListenerName:listenerName]];
}

// Event Modes

- (NSArray *)availableEventModes
{
	return [NSArray arrayWithObjects:LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen, nil];
}

- (NSString *)currentEventMode
{
	if (InSpringBoard) {
		// In SpringBoard
		if ([(SpringBoard *)[UIApplication sharedApplication] isLocked])
			return LAEventModeLockScreen;
		if ([[CHSharedInstance(SBIconController) contentView] window])
			return LAEventModeSpringBoard;
		return LAEventModeApplication;
	} else {
		// Outside SpringBoard
		return [self _performRemoteMessage:_cmd withObject:nil];
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s listeners=%@ events=%@ modes=%@ %p>", class_getName([self class]), _listeners, [self availableEventNames], [self availableEventModes], self];
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
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"title"] ?: eventName;
	return Localize(activatorBundle, [@"EVENT_TITLE_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized) ?: eventName);
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName
{
	NSString *result = [_cachedListenerTitles objectForKey:listenerName];
	if (result)
		return result;
	result = [[self listenerForName:listenerName] activator:self requiresLocalizedTitleForListenerName:listenerName];
	if (result)
		[_cachedListenerTitles setObject:result forKey:listenerName];
	return result;
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"] ?: @"";
	if ([unlocalized length] == 0)
		return @"";
	return Localize(activatorBundle, [@"EVENT_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(bundle, unlocalized, unlocalized) ?: @"");
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName
{
	NSString *result = [_cachedListenerGroups objectForKey:listenerName];
	if (result)
		return result;
	result = [[self listenerForName:listenerName] activator:self requiresLocalizedGroupForListenerName:listenerName];
	if (result)
		[_cachedListenerGroups setObject:result forKey:listenerName];
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
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"description"];
	if (unlocalized)
		return Localize(activatorBundle, [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized));
	NSString *key = [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName];
	NSString *result = Localize(activatorBundle, key, nil);
	return [result isEqualToString:key] ? nil : result;
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName
{
	return [[self listenerForName:listenerName] activator:self requiresLocalizedDescriptionForListenerName:listenerName];
}

@end

CHConstructor
{
	CHAutoreleasePoolForScope();
	LASharedActivator = [[LAActivator alloc] init];
	activatorBundle = [[NSBundle alloc] initWithPath:SCRootPath(@"/Library/Activator")];
	if (CHLoadLateClass(SBIconController)) {
		// Cache listener data
		listenerData = [[NSMutableDictionary alloc] init];
		NSString *listenersPath = SCRootPath(@"/Library/Activator/Listeners");
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:listenersPath error:NULL])
			if (![fileName hasPrefix:@"."])
				[listenerData setObject:[NSBundle bundleWithPath:[listenersPath stringByAppendingPathComponent:fileName]] forKey:fileName];
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR("libactivator.preferenceschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		[LASimpleListener sharedInstance];
		[LAToggleListener sharedInstance];
	}
}
