#import "LASpringBoardActivator.h"
#import "LAApplicationListener.h"
#import "libactivator-private.h"
#import "SlideEvents.h"
#import "LAMessaging.h"

#import <SpringBoard/SpringBoard.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <notify.h>

static NSInteger CompareListenerNamesCallback(id a, id b, void *context)
{
	return [[(LAActivator *)context localizedTitleForListenerName:a] localizedCaseInsensitiveCompare:[(LAActivator *)context localizedTitleForListenerName:b]];
}

@class SBProcess;
@interface SBApplication (OS40)
@property (nonatomic, retain) SBProcess *process;
@end

@implementation LASpringBoardActivator

static void NewCydiaStatusChanged()
{
	[LASharedActivator _setObject:(id)kCFBooleanTrue forPreference:@"LAHasNewCydia"];
}

- (BOOL)isAlive
{
	return YES;
}

- (void)didReceiveMemoryWarning
{
	[_cachedAndSortedListeners release];
	_cachedAndSortedListeners = nil;
	[super didReceiveMemoryWarning];
}

- (BOOL)isDangerousToSendEvents
{
	SBApplication *application = [(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:@"com.saurik.Cydia"];
	if ([application respondsToSelector:@selector(process)]) {
		if (![application process])
			return NO;
	} else if ([application respondsToSelector:@selector(pid)]) {
		if ([application pid] == -1)
			return NO;
	} else {
		return NO;
	}
	if ([[_preferences objectForKey:@"LAHasNewCydia"] boolValue]) {
		uint64_t state = 1;
		notify_get_state(notify_token, &state);
		if (state == 0)
			return NO;
	} else {
		// Workaround to detect installing/not installing on legacy cydia
		struct stat status;
		struct stat lock;
		struct stat partial;
		struct stat archives;
		stat("/var/cache/apt/archives", &archives);
		stat("/var/cache/apt/archives/lock", &lock);
		stat("/var/cache/apt/archives/partial", &partial);
		stat("/var/lib/dpkg/status", &status);
		if (((archives.st_mtime < status.st_mtime) || (archives.st_mtime <= lock.st_mtime)) && (partial.st_mtime < status.st_mtime))
			return NO;
	}
	return ![[self _getObjectForPreference:@"LAIgnoreProtectedApplications"] boolValue];
}

- (BOOL)isRunningInsideSpringBoard
{
	return YES;
}

// Preferences

- (void)_resetPreferences
{
	unlink([[self settingsFilePath] UTF8String]);
	[(SpringBoard *)UIApp relaunchSpringBoard];
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

- (void)_savePreferences
{
	CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)[self settingsFilePath], kCFURLPOSIXPathStyle, NO);
	CFWriteStreamRef stream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, url);
	CFRelease(url);
	if (stream && CFWriteStreamOpen(stream)) {
		CFStringRef errorString = NULL;
		if (CFPropertyListWriteToStream((CFPropertyListRef)_preferences, stream, kCFPropertyListBinaryFormat_v1_0, &errorString) == 0) {
			NSLog(@"Activator Failed to write to settings file: %@", errorString);
			if (UIApp) {
				UIAlertView *av = [[UIAlertView alloc] init];
				av.title = Localize(self.bundle, @"ACTIVATOR", @"Activator");
				av.message = [Localize(self.bundle, @"FAILED_TO_WRITE_SETTINGS_FILE", @"Failed to write to settings file: ") stringByAppendingString:(NSString *)errorString ?: @""];
				[av addButtonWithTitle:Localize(self.bundle, @"OK", @"OK")];
				[av release];
			}
			CFRelease(errorString);
		}
		CFWriteStreamClose(stream);
	} else {
		NSLog(@"Activator: Failed to open settings file for writing");
		if (UIApp) {
			UIAlertView *av = [[UIAlertView alloc] init];
			av.title = Localize(self.bundle, @"ACTIVATOR", @"Activator");
			av.message = Localize(self.bundle, @"FAILED_TO_OPEN_SETTINGS_FILE", @"Failed to open settings file for writing");
			[av addButtonWithTitle:Localize(self.bundle, @"OK", @"OK")];
			[av release];
		}
	}
	if (stream) {
		CFRelease(stream);
	}
	chmod([[self settingsFilePath] UTF8String], S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
}

static CFRunLoopObserverRef writeSettingsObserver;

static void WriteSettingsCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
	CFRunLoopObserverInvalidate(writeSettingsObserver);
	CFRelease(writeSettingsObserver);
	writeSettingsObserver = NULL;
	[(LASpringBoardActivator *)LASharedActivator _savePreferences];
}

- (void)_setObject:(id)value forPreference:(NSString *)preference
{
	if (!preference)
		return;
#ifdef DEBUG
	NSLog(@"Activator: Setting preference %@ to %@", preference, value);
#endif
	if (value) {
		if ([[_preferences objectForKey:preference] isEqual:value])
			return;
		[_preferences setObject:value forKey:preference];
	} else {
		if (![_preferences objectForKey:preference])
			return;
		[_preferences removeObjectForKey:preference];
	}
	if (!writeSettingsObserver) {
		writeSettingsObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, false, 0, WriteSettingsCallback, NULL);
		CFRunLoopRef runLoop = CFRunLoopGetMain();
		CFRunLoopAddObserver(runLoop, writeSettingsObserver, kCFRunLoopCommonModes);
		CFRunLoopAddObserver(runLoop, writeSettingsObserver, (CFStringRef)UITrackingRunLoopMode);
	}
}

- (void)_eventModeChanged
{
	NSString *eventMode = [self currentEventMode];
	static NSString *lastEventMode;
	if (lastEventMode == eventMode)
		return;
	lastEventMode = eventMode;
	CFIndex count = CFSetGetCount(_listenerInstances);
	const void *instances[count];
	CFSetGetValues(_listenerInstances, instances);
	SlideGestureClearAll();
	for (int i = 0; i < count; i++)
		[(id<LAListener>)instances[i] activator:self didChangeToEventMode:eventMode];
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
		[_listeners removeObjectForKey:name];
		for (id l in [_listeners objectEnumerator])
			if (l == listener)
				return;
		CFSetRemoveValue(_listenerInstances, listener);
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

- (void)_cacheAllListenerMetadata
{
}

// Event Modes

- (NSArray *)availableEventModes
{
	return [NSArray arrayWithObjects:LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen, nil];
}

- (NSString *)currentEventMode
{
	if ([(SpringBoard *)UIApp isLocked] || [[%c(SBAwayController) sharedAwayController] isMakingEmergencyCall])
		return LAEventModeLockScreen;
	/*if ([[(SBIconController *)[%c(SBIconController) sharedInstance] contentView] window])
		return LAEventModeSpringBoard;
	return LAEventModeApplication;*/
	return [[LAApplicationListener sharedInstance] topApplication] ? LAEventModeApplication : LAEventModeSpringBoard;
}

- (NSString *)displayIdentifierForCurrentApplication
{
	if ([(SpringBoard *)UIApp isLocked] || [[%c(SBAwayController) sharedAwayController] isMakingEmergencyCall])
		return nil;
	return [[[LAApplicationListener sharedInstance] topApplication] displayIdentifier];
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
	BOOL result = [[_eventData objectForKey:eventName] eventWithName:eventName isCompatibleWithMode:eventMode];
#ifdef DEBUG
	NSLog(@"Activator: eventWithName:%@ isCompatibleWithMode:%@ = %d", eventName, eventMode, result);
#endif
	return result;
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

- (void)sendDeactivateEventToListeners:(LAEvent *)event
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:event waitUntilDone:YES];
		return;
	}
	BOOL handled = [event isHandled];
	[event setHandled:NO];
	for (id<LAListener> listener in (NSSet *)_listenerInstances) {
		[listener activator:self receiveDeactivateEvent:event];
		if ([event isHandled]) {
			handled = YES;
			[event setHandled:NO];
			NSLog(@"Activator: deactivate event was handled by %@ assigned to %@ (suppressing home button event)", [listener class], [[_listeners allKeysForObject:listener] componentsJoinedByString:@", "]);
		}
	}
	[event setHandled:handled];
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

static CFDataRef trueData;

static CFDataRef messageServerCallback(CFMessagePortRef local, SInt32 messageId, CFDataRef data, void *info)
{
	switch (messageId) {
		case LAMessageIdResetPreferences:
			[LASharedActivator _resetPreferences];
			break;
		case LAMessageIdGetPreference:
			return (CFDataRef)[LATransformPropertyListToData([LASharedActivator _getObjectForPreference:LATransformDataToString(data)]) retain];
		case LAMessageIdSetPreference: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]]) {
				NSString *preference = nil;
				id value = nil;
				switch ([args count]) {
					case 2:
						value = [args objectAtIndex:1];
					case 1:
						preference = [args objectAtIndex:0];
						if (![preference isKindOfClass:[NSString class]])
							preference = nil;
				}
				[LASharedActivator _setObject:value forPreference:preference];
			}
			break;
		}
		case LAMessageIdGetAvaliableEventNames:
			return (CFDataRef)[LATransformPropertyListToData([LASharedActivator availableEventNames]) retain];
		case LAMessageIdGetEventIsHidden:
			if ([LASharedActivator eventWithNameIsHidden:LATransformDataToString(data)])
				return (CFDataRef)CFRetain(trueData);
			break;
		case LAMessageIdGetCompatibleModesForEventName:
			return (CFDataRef)[LATransformPropertyListToData([LASharedActivator compatibleModesForEventWithName:LATransformDataToString(data)]) retain];
		case LAMessageIdGetEventWithNameIsCompatibleWithMode: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]]) {
				NSString *eventMode = nil;
				NSString *eventName = nil;
				switch ([args count]) {
					case 2:
						eventName = [args objectAtIndex:1];
						if (![eventName isKindOfClass:[NSString class]])
							eventName = nil;
					case 1:
						eventMode = [args objectAtIndex:0];
						if (![eventMode isKindOfClass:[NSString class]])
							eventMode = nil;
				}
				if ([LASharedActivator eventWithName:eventName isCompatibleWithMode:eventMode])
					return (CFDataRef)CFRetain(trueData);
			}
			break;
		}	
		case LAMessageIdGetListenerNames:
			return (CFDataRef)[LATransformPropertyListToData([LASharedActivator availableListenerNames]) retain];
		case LAMessageIdGetCachedAnsSortedListeners:
			return (CFDataRef)[LATransformPropertyListToData([LASharedActivator _cachedAndSortedListeners]) retain];
		case LAMessageIdGetCurrentEventMode:
			return (CFDataRef)[LATransformStringToData([LASharedActivator currentEventMode]) retain];
		case LAMessageIdGetDisplayIdentifierForCurrentApplication:
			return (CFDataRef)[LATransformStringToData([LASharedActivator displayIdentifierForCurrentApplication]) retain];
		case LAMessageIdGetLocalizedTitleForEventName:
			return (CFDataRef)[LATransformStringToData([LASharedActivator localizedTitleForEventName:LATransformDataToString(data)]) retain];
		case LAMessageIdGetLocalizedDescriptionForEventName:
			return (CFDataRef)[LATransformStringToData([LASharedActivator localizedDescriptionForEventName:LATransformDataToString(data)]) retain];
		case LAMessageIdGetLocalizedGroupForEventName:
			return (CFDataRef)[LATransformStringToData([LASharedActivator localizedGroupForEventName:LATransformDataToString(data)]) retain];
		case LAMessageIdSendDeactivateEventToListeners: {
			LAEvent *event = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)data];
			if ([event isKindOfClass:[LAEvent class]]) {
				[LASharedActivator sendDeactivateEventToListeners:event];
				if (event.handled)
					return (CFDataRef)CFRetain(trueData);
			}
			break;
		}
		case LAMessageIdReceiveEventForListenerName: {
			NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:(NSData *)data];
			LAEvent *event = [unarchiver decodeObjectForKey:@"event"];
			NSString *listenerName = [unarchiver decodeObjectForKey:@"listenerName"];
			[unarchiver release];
			if ([event isKindOfClass:[LAEvent class]] && [listenerName isKindOfClass:[NSString class]]) {
				[[LASharedActivator listenerForName:listenerName] activator:LASharedActivator receiveEvent:event forListenerName:listenerName];
				if (event.handled)
					return (CFDataRef)CFRetain(trueData);
			}
		}
		case LAMessageIdAbortEventForListenerName: {
			NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:(NSData *)data];
			LAEvent *event = [unarchiver decodeObjectForKey:@"event"];
			NSString *listenerName = [unarchiver decodeObjectForKey:@"listenerName"];
			[unarchiver release];
			if ([event isKindOfClass:[LAEvent class]] && [listenerName isKindOfClass:[NSString class]]) {
				[[LASharedActivator listenerForName:listenerName] activator:LASharedActivator abortEvent:event forListenerName:listenerName];
				if (event.handled)
					return (CFDataRef)CFRetain(trueData);
			}
		}
		case LAMessageIdGetLocalizedTitleForListenerName: {
			NSString *listenerName = LATransformDataToString(data);
			NSString *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresLocalizedTitleForListenerName:listenerName];
			return (CFDataRef)[LATransformStringToData(result) retain];
		}
		case LAMessageIdGetLocalizedDescriptionForListenerName: {
			NSString *listenerName = LATransformDataToString(data);
			NSString *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresLocalizedDescriptionForListenerName:listenerName];
			return (CFDataRef)[LATransformStringToData(result) retain];
		}
		case LAMessageIdGetLocalizedGroupForListenerName: {
			NSString *listenerName = LATransformDataToString(data);
			NSString *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresLocalizedGroupForListenerName:listenerName];
			return (CFDataRef)[LATransformStringToData(result) retain];
		}
		case LAMessageIdGetRequiresAssignmentForListenerName: {
			NSString *listenerName = LATransformDataToString(data);
			NSNumber *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresRequiresAssignmentForListenerName:listenerName];
			return (CFDataRef)[LATransformPropertyListToData(result) retain];
		}
		case LAMessageIdGetCompatibleEventModesForListenerName: {
			NSString *listenerName = LATransformDataToString(data);
			NSArray *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresCompatibleEventModesForListenerWithName:listenerName];
			return (CFDataRef)[LATransformPropertyListToData(result) retain];
		}
		case LAMessageIdGetIconDataForListenerName: {
			NSString *listenerName = LATransformDataToString(data);
			NSData *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresIconDataForListenerName:listenerName];
			return (CFDataRef)[result retain];
		}
		case LAMessageIdGetIconDataForListenerNameWithScale: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]] && ([args count] == 2)) {
				NSString *listenerName = [args objectAtIndex:0];
				if (![listenerName isKindOfClass:[NSString class]])
					return NULL;
				NSNumber *scaleObject = [args objectAtIndex:1];
				if (![scaleObject isKindOfClass:[NSNumber class]])
					return NULL;
				CGFloat scale = [scaleObject floatValue];
				NSData *resultData = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresIconDataForListenerName:listenerName scale:&scale];
				if (resultData) {
					NSMutableData *result = [[NSMutableData alloc] initWithCapacity:sizeof(CGFloat) + [resultData length]];
					[result appendBytes:&scale length:sizeof(CGFloat)];
					[result appendData:resultData];
					return (CFDataRef)result;
				}
			}
			break;
		}
		case LAMessageIdGetIconWithScaleForListenerName: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]] && ([args count] == 2)) {
				NSString *listenerName = [args objectAtIndex:0];
				if (![listenerName isKindOfClass:[NSString class]])
					return NULL;
				NSNumber *scaleObject = [args objectAtIndex:1];
				if (![scaleObject isKindOfClass:[NSNumber class]])
					return NULL;
				CGFloat scale = [scaleObject floatValue];
				UIImage *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresIconForListenerName:listenerName scale:scale];
				return (CFDataRef)[LATransformUIImageToData(result) retain];
			}
		}
		case LAMessageIdGetSmallIconDataForListenerName: {
			NSString *listenerName = LATransformDataToString(data);
			NSData *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresSmallIconDataForListenerName:listenerName];
			return (CFDataRef)[result retain];
		}
		case LAMessageIdGetSmallIconDataForListenerNameWithScale: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]] && ([args count] == 2)) {
				NSString *listenerName = [args objectAtIndex:0];
				if (![listenerName isKindOfClass:[NSString class]])
					return NULL;
				NSNumber *scaleObject = [args objectAtIndex:1];
				if (![scaleObject isKindOfClass:[NSNumber class]])
					return NULL;
				CGFloat scale = [scaleObject floatValue];
				NSData *resultData = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresSmallIconDataForListenerName:listenerName scale:&scale];
				if (resultData) {
					NSMutableData *result = [[NSMutableData alloc] initWithCapacity:sizeof(CGFloat) + [resultData length]];
					[result appendBytes:&scale length:sizeof(CGFloat)];
					[result appendData:resultData];
					return (CFDataRef)result;
				}
			}
			break;
		}
		case LAMessageIdGetSmallIconWithScaleForListenerName: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]] && ([args count] == 2)) {
				NSString *listenerName = [args objectAtIndex:0];
				if (![listenerName isKindOfClass:[NSString class]])
					return NULL;
				NSNumber *scaleObject = [args objectAtIndex:1];
				if (![scaleObject isKindOfClass:[NSNumber class]])
					return NULL;
				CGFloat scale = [scaleObject floatValue];
				UIImage *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresSmallIconForListenerName:listenerName scale:scale];
				return (CFDataRef)[LATransformUIImageToData(result) retain];
			}
		}
		case LAMessageIdGetListenerNameIsCompatibleWithEventName: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]]) {
				NSString *listenerName = nil;
				NSString *eventName = nil;
				switch ([args count]) {
					case 2:
						eventName = [args objectAtIndex:1];
						if (![eventName isKindOfClass:[NSString class]])
							eventName = nil;
					case 1:
						listenerName = [args objectAtIndex:0];
						if (![listenerName isKindOfClass:[NSString class]])
							listenerName = nil;
				}
				NSNumber *result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresIsCompatibleWithEventName:eventName listenerName:listenerName];
				return (CFDataRef)[LATransformPropertyListToData(result) retain];
			}
			break;
		}
		case LAMessageIdGetValueOfInfoDictionaryKeyForListenerName: {
			NSArray *args = LATransformDataToPropertyList(data);
			if ([args isKindOfClass:[NSArray class]]) {
				NSString *listenerName = nil;
				NSString *key = nil;
				switch ([args count]) {
					case 2:
						key = [args objectAtIndex:1];
						if (![key isKindOfClass:[NSString class]])
							key = nil;
					case 1:
						listenerName = [args objectAtIndex:0];
						if (![listenerName isKindOfClass:[NSString class]])
							listenerName = nil;
				}
				id result = [[LASharedActivator listenerForName:listenerName] activator:LASharedActivator requiresInfoDictionaryValueOfKey:key forListenerWithName:listenerName];
				return (CFDataRef)[LATransformPropertyListToData(result) retain];
			}
			break;
		}
	}
	return NULL;
}

- (id)init
{
	if ((self = [super init])) {
		CFMessagePortRef localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, kLAMessageServerName, messageServerCallback, NULL, NULL);
		CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
		trueData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)self /* can be anything, we only care about the length */, 1, kCFAllocatorNull);
		// Does not retain values!
		_listeners = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
		// Load preferences
		if (!(_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:[self settingsFilePath]]))
			_preferences = [[NSMutableDictionary alloc] init];
		_eventData = [[NSMutableDictionary alloc] init];
		// Load NewCydia notify check
		notify_register_check("com.saurik.Cydia.status", &notify_token);
		if (![[_preferences objectForKey:@"LAHasNewCydia"] boolValue]) {
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (void *)NewCydiaStatusChanged, CFSTR("com.saurik.Cydia.status"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
#ifndef SINGLE
		%init;
#endif
		SlideGestureClearAll();
	}
	return self;
}

- (void)dealloc
{
	notify_cancel(notify_token);
	[_cachedAndSortedListeners release];
	[_eventData release];
	[_preferences release];
	[_listeners release];
	[super dealloc];
}

@end
