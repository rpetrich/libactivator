#import "libactivator-private.h"
#import "LAApplicationListener.h"

#include <sys/stat.h>

static NSInteger CompareListenerNamesCallback(id a, id b, void *context)
{
	return [[(LAActivator *)context localizedTitleForListenerName:a] localizedCaseInsensitiveCompare:[(LAActivator *)context localizedTitleForListenerName:b]];
}

@implementation LASpringBoardActivator

- (id)init
{
	if ((self = [super init])) {
		CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
		[messagingCenter runServerOnCurrentThread];
		// Remote messages to id<LAListener> (with event)
		[messagingCenter registerForMessageName:@"activator:receiveEvent:forListenerName:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"activator:abortEvent:forListenerName:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
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
		// Remote messages to id<LAListener> (without event, with scale pointer)
		[messagingCenter registerForMessageName:@"activator:requiresIconDataForListenerName:scale:" target:self selector:@selector(_handleRemoteListenerScalePtrMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"activator:requiresSmallIconDataForListenerName:scale:" target:self selector:@selector(_handleRemoteListenerScalePtrMessage:withUserInfo:)];			
		// Remote messages to LAActivator
		[messagingCenter registerForMessageName:@"_cachedAndSortedListeners" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"currentEventMode" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"availableListenerNames" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"availableEventNames" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"eventWithNameIsHidden:" target:self selector:@selector(_handleRemoteBoolMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"compatibleModesForEventWithName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"eventWithName:isCompatibleWithMode:" target:self selector:@selector(_handleRemoteBoolMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"localizedTitleForEventName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"localizedGroupForEventName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		[messagingCenter registerForMessageName:@"localizedDescriptionForEventName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
		// Preferences
		[messagingCenter registerForMessageName:@"setObjectForPreference" target:self selector:@selector(_setObjectForPreferenceFromMessageName:userInfo:)];
		[messagingCenter registerForMessageName:@"getObjectForPreference" target:self selector:@selector(_getObjectForPreferenceFromMessageName:userInfo:)];
		[messagingCenter registerForMessageName:@"resetPreferences" target:self selector:@selector(_resetPreferences)];
		// Does not retain values!
		_listeners = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
		// Load preferences
		if (!(_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:[self settingsFilePath]]))
			_preferences = [[NSMutableDictionary alloc] init];
		_eventData = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_cachedAndSortedListeners release];
	[_eventData release];
	[_preferences release];
	[_listeners release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning
{
	[_cachedAndSortedListeners release];
	_cachedAndSortedListeners = nil;
	[super didReceiveMemoryWarning];
}

- (BOOL)isRunningInsideSpringBoard
{
	return YES;
}

// Remote Messaging

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

- (NSDictionary *)_handleRemoteListenerScalePtrMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	NSString *listenerName = [userInfo objectForKey:@"listenerName"];
	CGFloat scale = [[userInfo objectForKey:@"scale"] floatValue];
	id<LAListener> listener = [self listenerForName:listenerName];
	id result = objc_msgSend(listener, NSSelectorFromString(message), self, [userInfo objectForKey:@"object"], &scale);
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:scale], @"scale", result, @"result", nil];
}

- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	id withObject = [userInfo objectForKey:@"withObject"];
	id withObject2 = [userInfo objectForKey:@"withObject2"];
	id result = [self performSelector:NSSelectorFromString(message) withObject:withObject withObject:withObject2];
	return result ? [NSDictionary dictionaryWithObject:result forKey:@"result"] : [NSDictionary dictionary];
}

- (NSDictionary *)_handleRemoteBoolMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	id withObject = [userInfo objectForKey:@"withObject"];
	id withObject2 = [userInfo objectForKey:@"withObject2"];
	id result = [self performSelector:NSSelectorFromString(message) withObject:withObject withObject:withObject2];
	return [NSDictionary dictionaryWithObject:result ? (id)kCFBooleanTrue : (id)kCFBooleanFalse forKey:@"result"];
}

// Preferences

- (void)_resetPreferences
{
	unlink([[self settingsFilePath] UTF8String]);
	[(SpringBoard *)[UIApplication sharedApplication] relaunchSpringBoard];
}

- (id)_getObjectForPreference:(NSString *)preference
{
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
	if (value)
		[_preferences setObject:value forKey:preference];
	else
		[_preferences removeObjectForKey:preference];
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
}

- (void)_eventModeChanged
{
	NSString *eventMode = [self currentEventMode];
	for (id<LAListener> listener in [_listeners allValues])
		[listener activator:self didChangeToEventMode:eventMode];
}

// Registration of listeners

- (id<LAListener>)listenerForName:(NSString *)name
{
	return [_listeners objectForKey:name];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name
{
#ifdef DEBUG
	NSLog(@"Activator: registerListener:%@ forName:%@", listener, name);
#endif
	[_cachedAndSortedListeners release];
	_cachedAndSortedListeners = nil;
	[_listeners setObject:listener forKey:name];
	// Store all listener instances in a set so deactivate/otherListener methods can be quick
	CFSetAddValue(_listenerInstances, listener);
	NSString *key = [@"LAHasSeenListener-" stringByAppendingString:name];
	if (![[self _getObjectForPreference:key] boolValue])
		[self _setObject:(id)kCFBooleanTrue forPreference:key];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen
{
#ifdef DEBUG
	NSLog(@"Activator: registerListener:%@ forName:%@ ignoreHasSeen:%s", listener, name, ignoreHasSeen ? "YES" : "NO");
#endif
	[_cachedAndSortedListeners release];
	_cachedAndSortedListeners = nil;
	[_listeners setObject:listener forKey:name];
	// Store all listener instances in a set so deactivate/otherListener methods can be quick
	CFSetAddValue(_listenerInstances, listener);
	if (!ignoreHasSeen) {
		NSString *key = [@"LAHasSeenListener-" stringByAppendingString:name];
		if (![[self _getObjectForPreference:key] boolValue])
			[self _setObject:(id)kCFBooleanTrue forPreference:key];
	}
}

- (void)unregisterListenerWithName:(NSString *)name
{
#ifdef DEBUG
	NSLog(@"Activator: unregisterWithName:%@", name);
#endif
	id listener = [_listeners objectForKey:name];
	if (listener) {
		[_cachedListenerTitles removeObjectForKey:name];
		[_cachedListenerGroups removeObjectForKey:name];
		[_cachedAndSortedListeners release];
		_cachedAndSortedListeners = nil;
		// Do some monkey-work so that only the last removal of a shared instance removes it from the set
		// Since removal is uncommon, this is allowed to be slowish
		if ([[_listeners allKeysForObject:listener] count] == 1)
			CFSetRemoveValue(_listenerInstances, listener);
		[_listeners removeObjectForKey:name];
	}
}

// Listeners

- (NSDictionary *)_cachedAndSortedListeners
{
	if (_cachedAndSortedListeners)
		return _cachedAndSortedListeners;
	NSMutableDictionary *listeners = [[[NSMutableDictionary alloc] init] autorelease];
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
		array = [array sortedArrayUsingFunction:CompareListenerNamesCallback context:LASharedActivator];
		[listeners setObject:array forKey:key];
	}
	_cachedAndSortedListeners = [listeners copy];
	return _cachedAndSortedListeners;
}

// Event Modes

- (NSArray *)availableEventModes
{
	return [NSArray arrayWithObjects:LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen, nil];
}

- (NSString *)currentEventMode
{
	if ([(SpringBoard *)[UIApplication sharedApplication] isLocked])
		return LAEventModeLockScreen;
	/*if ([[CHSharedInstance(SBIconController) contentView] window])
		return LAEventModeSpringBoard;
	return LAEventModeApplication;*/
	return [[LAApplicationListener sharedInstance] topApplication] ? LAEventModeApplication : LAEventModeSpringBoard;
}

// Events

- (NSArray *)availableEventNames
{
	return [_eventData allKeys];
}

- (BOOL)eventWithNameIsHidden:(NSString *)name
{
	return [[_eventData objectForKey:name] eventWithNameIsHidden:name];
}

- (NSArray *)compatibleModesForEventWithName:(NSString *)name
{
	id<LAEventDataSource> dataSource = [_eventData objectForKey:name];
	NSArray *availableEventModes = [self availableEventModes];
	NSMutableArray *result = [[availableEventModes mutableCopy] autorelease];
	for (NSString *mode in availableEventModes)
		if (![dataSource eventWithName:name isCompatibleWithMode:mode])
			[result removeObject:mode];
	return result;
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
	return [[_eventData objectForKey:eventName] eventWithName:eventName isCompatibleWithMode:eventMode];
}

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName
{
	[_eventData setObject:dataSource forKey:eventName];
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName
{
	[_eventData removeObjectForKey:eventName];
}

- (NSArray *)availableListenerNames
{
	return [_listeners allKeys];
}

// Localization

- (NSString *)localizedTitleForEventName:(NSString *)eventName
{	
	return [[_eventData objectForKey:eventName] localizedTitleForEventName:eventName];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
	return [[_eventData objectForKey:eventName] localizedGroupForEventName:eventName];
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName
{
	return [[_eventData objectForKey:eventName] localizedDescriptionForEventName:eventName];
}

@end
