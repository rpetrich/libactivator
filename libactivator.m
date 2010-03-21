#import "libactivator.h"
#import "libactivator-private.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>
#import <AppSupport/AppSupport.h>

#include <objc/runtime.h>
#include <sys/stat.h>
#include <notify.h>

NSString * const LAEventModeSpringBoard = @"springboard";
NSString * const LAEventModeApplication = @"application";
NSString * const LAEventModeLockScreen  = @"lockscreen";

CHDeclareClass(SBIconController);

static LAActivator *sharedActivator;

@interface NSObject(LAListener)
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode;
- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event;
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName;
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName;
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName;
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)name;
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)name;
- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName;
- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName;
- (id)activator:(LAActivator *)activator requiresInfoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)listenerName;
@end

@implementation NSObject(LAListener)
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
}
- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event
{
}
- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode
{
}
- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return nil;
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return nil;
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return nil;
}
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)name
{
	return nil;
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)name
{
	return nil;
}
- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName
{
	return nil;
}
- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName
{
	return nil;
}
- (id)activator:(LAActivator *)activator requiresInfoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)listenerName
{
	if ([key isEqualToString:@"title"])
		return [self activator:activator requiresLocalizedTitleForListenerName:listenerName];
	if ([key isEqualToString:@"description"])
		return [self activator:activator requiresLocalizedDescriptionForListenerName:listenerName];
	if ([key isEqualToString:@"group"])
		return [self activator:activator requiresLocalizedGroupForListenerName:listenerName];
	if ([key isEqualToString:@"requires-event"])
		return [self activator:activator requiresRequiresAssignmentForListenerName:listenerName];
	if ([key isEqualToString:@"compatible-modes"])
		return [self activator:activator requiresCompatibleEventModesForListenerWithName:listenerName];
	return nil;
}
@end

#define ListenerKeyForEventNameAndMode(eventName, eventMode) \
	[NSString stringWithFormat:@"LAEventListener(%@)-%@", (eventMode), (eventName)]
	
#define Localize(bundle, key, value_) ({ \
	NSBundle *_bundle = (bundle); \
	NSString *_key = (key); \
	NSString *_value = (value_); \
	(_bundle) ? [_bundle localizedStringForKey:_key value:_value table:nil] : _value; \
})

@implementation LARemoteListener

- (id)initWithListenerName:(NSString *)listenerName
{
	if ((self = [super init])) {
		_listenerName = [listenerName copy];
		_messagingCenter = [[CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"] retain];
	}
	return self;
}

- (void)dealloc
{
	[_messagingCenter release];
	[_listenerName release];
	[super dealloc];
}

- (void)_performRemoteSelector:(SEL)selector withEvent:(LAEvent *)event
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSKeyedArchiver archivedDataWithRootObject:event], @"event", _listenerName, @"listenerName", nil];
	NSData *result = [[_messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo] objectForKey:@"result"];
	LAEvent *newEvent = [NSKeyedUnarchiver unarchiveObjectWithData:result];
	[event setHandled:[newEvent isHandled]];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[self _performRemoteSelector:_cmd withEvent:event];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[self _performRemoteSelector:_cmd withEvent:event];
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
	[self _performRemoteSelector:_cmd withEvent:event];
}

- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event
{
	[self _performRemoteSelector:_cmd withEvent:event];
}

- (id)_performRemoteSelector:(SEL)selector withObject:(id)object withObject:(id)object2
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:_listenerName, @"listenerName", object, @"object", object2, @"object2", nil];
	return [[_messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo] objectForKey:@"result"];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil];
}
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil];
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil];
}
- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil];
}
- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil];
}
- (id)activator:(LAActivator *)activator requiresInfoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:key withObject:listenerName];
}

@end

#define InSpringBoard (!!_listeners)

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[sharedActivator _reloadPreferences];
}

NSInteger CompareListenerNamesCallback(id a, id b, void *context)
{
	return [[sharedActivator localizedTitleForListenerName:a] localizedCaseInsensitiveCompare:[sharedActivator localizedTitleForListenerName:b]];
}

@implementation LAActivator

#define LoadPreferences() do { if (!_preferences) [self _loadPreferences]; } while(0)

+ (LAActivator *)sharedInstance
{
	return sharedActivator;
}

+ (void)initialize
{
	sharedActivator = [[LAActivator alloc] init];
}

- (NSString *)settingsFilePath
{
	return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/libactivator.plist"];
}

- (id)init
{
	CHAutoreleasePoolForScope();
	CHLoadLateClass(SBIconController);
	if ((self = [super init])) {
		// Detect if we're inside SpringBoard
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
			CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
			[messagingCenter runServerOnCurrentThread];
			// Remote messages to id<LAListener> (with event)
			[messagingCenter registerForMessageName:@"activator:receiveEvent:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:abortEvent:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:otherListenerDidHandleEvent:" target:self selector:@selector(_handleRemoteListenerEventMessage:withUserInfo:)];
			// Remote messages to id<LAListener> (without event)
			[messagingCenter registerForMessageName:@"activator:requiresLocalizedTitleForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresLocalizedDescriptionForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresLocalizedGroupForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresRequiresAssignmentForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresCompatibleEventModesForListenerWithName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresIconForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresSmallIconForListenerName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:requiresInfoDictionaryValueOfKey:forListenerWithName:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			// Remote messages to LAActivator
			[messagingCenter registerForMessageName:@"_cachedAndSortedListeners" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"currentEventMode" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"availableListenerNames" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"compatibleEventModesForListenerWithName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"_iconDataForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"_smallIconDataForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"localizedTitleForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"localizedGroupForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			// Does not retain values!
			_listeners = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
  		}
		// Register for notification
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, PreferencesChangedCallback, CFSTR("libactivator.preferenceschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		// Cache event data
		_eventData = [[NSMutableDictionary alloc] init];
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Activator/Events" error:NULL])
			if (![fileName hasPrefix:@"."])
				[_eventData setObject:[NSBundle bundleWithPath:[@"/Library/Activator/Events" stringByAppendingPathComponent:fileName]] forKey:fileName];
		// Cache listener data
		_listenerData = [[NSMutableDictionary alloc] init];
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Activator/Listeners" error:NULL])
			if (![fileName hasPrefix:@"."])
				[_listenerData setObject:[NSBundle bundleWithPath:[@"/Library/Activator/Listeners" stringByAppendingPathComponent:fileName]] forKey:fileName];
		// Load Main Bundle
		_mainBundle = [[NSBundle alloc] initWithPath:@"/Library/Activator"];
	}
	return self;
}

- (void)dealloc
{
	[_cachedAndSortedListeners release];
	[_mainBundle release];
	[_listenerData release];
	CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, CFSTR("libactivator.preferencechanged"), NULL);
	[_preferences release];
	[_listeners release];
	[_eventData release];
	[super dealloc];
}

// Preferences

- (void)_reloadPreferences
{
	if (_suppressReload == 0) {
		[_preferences release];
		_preferences = nil;
	}
}

- (void)_loadPreferences
{
	if (!(_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:[self settingsFilePath]])) {
		// Create a new preference file
		_preferences = [[NSMutableDictionary alloc] init];
	}
}

- (void)_savePreferences
{
	if (_preferences) {
		_suppressReload++;
		CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)[self settingsFilePath], kCFURLPOSIXPathStyle, NO);
		CFWriteStreamRef stream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, url);
		CFRelease(url);
		CFWriteStreamOpen(stream);
		CFPropertyListWriteToStream((CFPropertyListRef)_preferences, stream, kCFPropertyListBinaryFormat_v1_0, NULL);
		CFWriteStreamClose(stream);
		CFRelease(stream);
		chmod([[self settingsFilePath] UTF8String], S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
		notify_post("libactivator.preferenceschanged");
		_suppressReload--;
	}
}

- (id)_getObjectForPreference:(NSString *)preference
{
	LoadPreferences();
	return [_preferences objectForKey:preference];
}

- (NSDictionary *)_handleRemoteListenerEventMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	NSString *listenerName = [userInfo objectForKey:@"listenerName"];
	id<LAListener> listener = [self listenerForName:listenerName];
	LAEvent *event = [NSKeyedUnarchiver unarchiveObjectWithData:[userInfo objectForKey:@"event"]];
	objc_msgSend(listener, NSSelectorFromString(message), self, event);
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
	id<LAListener> listener = [self listenerForEvent:event];
	[listener activator:self receiveEvent:event];
	if ([event isHandled])
		for (id<LAListener> other in [_listeners allValues])
			if (other != listener)
				[other activator:self otherListenerDidHandleEvent:event];
}

- (void)sendAbortToListener:(LAEvent *)event
{
	[[self listenerForEvent:event] activator:self abortEvent:event];
}

- (void)sendDeactivateEventToListeners:(LAEvent *)event
{
	BOOL handled = [event isHandled];
	for (id<LAListener> listener in [_listeners allValues]) {
		[listener activator:self receiveDeactivateEvent:event];
		handled |= [event isHandled];
	}
	[event setHandled:handled];
}

// Registration of listeners

- (id<LAListener>)listenerForName:(NSString *)name
{
	LoadPreferences();
	if (!InSpringBoard)
		return [[[LARemoteListener alloc] initWithListenerName:name] autorelease];
	return [_listeners objectForKey:name];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name
{
	[_listeners setObject:listener forKey:name];
	LoadPreferences();
	NSString *key = [@"LAHasSeenListener-" stringByAppendingString:name];
	if (![[_preferences objectForKey:key] boolValue]) {
		[_preferences setObject:[NSNumber numberWithBool:YES] forKey:key];
		[self _savePreferences];
	}
}

- (void)unregisterListenerWithName:(NSString *)name
{
	[_listeners removeObjectForKey:name];
}

- (BOOL)hasSeenListenerWithName:(NSString *)name
{
	LoadPreferences();
	return [[_preferences objectForKey:[@"LAHasSeenListener-" stringByAppendingString:name]] boolValue];
}

// Setting Assignments

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName
{
	LoadPreferences();
	NSString *eventName = [event name];
	NSString *eventMode = [event mode];
	if ([eventMode length]) {
		if ([self listenerWithName:listenerName isCompatibleWithMode:eventMode])
			if ([self eventWithName:eventName isCompatibleWithMode:eventMode])
				[_preferences setObject:listenerName forKey:ListenerKeyForEventNameAndMode(eventName, eventMode)];
	} else {
		for (NSString *mode in [self compatibleEventModesForListenerWithName:listenerName])
			if ([self eventWithName:eventName isCompatibleWithMode:mode])
				[_preferences setObject:listenerName forKey:ListenerKeyForEventNameAndMode(eventName, mode)];
	}
	// Save Preferences
	[self _savePreferences];
}

- (void)unassignEvent:(LAEvent *)event
{
	LoadPreferences();
	BOOL shouldSave = NO;
	NSString *eventName = [event name];
	NSString *eventMode = [event mode];
	if ([eventMode length]) {
		NSString *prefName = ListenerKeyForEventNameAndMode(eventName, eventMode);
		if ([_preferences objectForKey:prefName]) {
			[_preferences removeObjectForKey:prefName];
			shouldSave = YES;
		}
	} else {
		for (NSString *mode in [self availableEventModes]) {
			NSString *prefName = ListenerKeyForEventNameAndMode(eventName, mode);
			if ([_preferences objectForKey:prefName]) {
				[_preferences removeObjectForKey:prefName];
				shouldSave = YES;
			}
		}
	}
	if (shouldSave)
		[self _savePreferences];
}

// Getting Assignments

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event
{
	LoadPreferences();
	NSString *prefName = ListenerKeyForEventNameAndMode([event name], [event mode] ?: [self currentEventMode]);
	NSString *prefValue = [_preferences objectForKey:prefName];
	return prefValue;
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName
{
	NSArray *events = [self availableEventNames];
	NSMutableArray *result = [NSMutableArray array];
	LoadPreferences();
	for (NSString *eventMode in [self availableEventModes]) {
		for (NSString *eventName in events) {
			NSString *prefName = ListenerKeyForEventNameAndMode(eventName, eventMode);
			NSString *assignedListener = [_preferences objectForKey:prefName];
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
	if (InSpringBoard) {
		NSMutableArray *result = [[_listeners allKeys] mutableCopy];
		for (id key in [_listenerData allKeys])
			if (![result containsObject:key])
				[result addObject:key];
		return [result autorelease];
	}
	return [self _performRemoteMessage:_cmd withObject:nil];
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name
{
	NSBundle *bundle = [_listenerData objectForKey:name];
	if (bundle)
		return [bundle objectForInfoDictionaryKey:key];
	else
		return [(id<LAVirtualListener>)[self listenerForName:name] activator:self requiresInfoDictionaryValueOfKey:key forListenerWithName:name];
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name
{
	NSBundle *bundle = [_listenerData objectForKey:name];
	if (bundle)
		return [[bundle objectForInfoDictionaryKey:@"requires-event"] boolValue];
	else
		return [[(id<LAVirtualListener>)[self listenerForName:name] activator:self requiresRequiresAssignmentForListenerName:name] boolValue];
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name;
{
	NSBundle *listenerBundle = [_listenerData objectForKey:name];
	if (listenerBundle)
		return [listenerBundle objectForInfoDictionaryKey:@"compatible-modes"] ?: [self availableEventModes];
	id<LAVirtualListener> listener = (id<LAVirtualListener>)[self listenerForName:name];
	if (listener)
		return [listener activator:self requiresCompatibleEventModesForListenerWithName:name] ?: [self availableEventModes];
	return nil;
}

- (BOOL)listenerWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
	if (eventMode)
		// TODO: optimize this
		return [[self compatibleEventModesForListenerWithName:eventName] containsObject:eventMode];
	return YES;
}

- (NSData *)_iconDataForListenerName:(NSString *)listenerName
{
	return UIImagePNGRepresentation([self iconForListenerName:listenerName]);
}

- (NSData *)_smallIconDataForListenerName:(NSString *)listenerName
{
	return UIImagePNGRepresentation([self smallIconForListenerName:listenerName]);
}

- (UIImage *)iconForListenerName:(NSString *)listenerName
{
	NSBundle *bundle = [_listenerData objectForKey:listenerName];
	NSString *path = [bundle pathForResource:@"icon" ofType:@"png"];
	if (path)
		return [UIImage imageWithContentsOfFile:path];
	path = [bundle pathForResource:@"Icon" ofType:@"png"];
	if (path)
		return [UIImage imageWithContentsOfFile:path];	
	if (!InSpringBoard) {
		// Marshal through SpringBoard by converting to PNG
		return [UIImage imageWithData:[self _performRemoteMessage:@selector(_iconDataForListenerName:) withObject:listenerName]];
	}
	return [(id<LAVirtualListener>)[self listenerForName:listenerName] activator:self requiresIconForListenerName:listenerName];
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName
{
	NSBundle *bundle = [_listenerData objectForKey:listenerName];
	NSString *path = [bundle pathForResource:@"icon-small" ofType:@"png"];
	if (path)
		return [UIImage imageWithContentsOfFile:path];
	path = [bundle pathForResource:@"Icon-small" ofType:@"png"];
	if (path)
		return [UIImage imageWithContentsOfFile:path];	
	if (!InSpringBoard) {
		// Marshal through SpringBoard by converting to PNG
		return [UIImage imageWithData:[self _performRemoteMessage:@selector(_smallIconDataForListenerName:) withObject:listenerName]];
	}
	return [(id<LAVirtualListener>)[self listenerForName:listenerName] activator:self requiresSmallIconForListenerName:listenerName];
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
	return Localize(_mainBundle, key, value);
}

- (NSString *)localizedTitleForEventMode:(NSString *)eventMode
{
	if ([eventMode isEqual:LAEventModeSpringBoard])
		return Localize(_mainBundle, @"MODE_TITLE_springboard", @"At Home Screen");
	if ([eventMode isEqual:LAEventModeApplication])
		return Localize(_mainBundle, @"MODE_TITLE_application", @"In Application");
	if ([eventMode isEqual:LAEventModeLockScreen])
		return Localize(_mainBundle, @"MODE_TITLE_lockscreen", @"At Lock Screen");
	return Localize(_mainBundle, @"MODE_TITLE_all", @"Anytime");
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName
{	
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"title"] ?: eventName;
	return Localize(_mainBundle, [@"EVENT_TITLE_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized) ?: eventName);
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName
{
	if (InSpringBoard) {
		NSBundle *bundle = [_listenerData objectForKey:listenerName];
		if (bundle) {
			NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"title"] ?: listenerName;
			return Localize(_mainBundle, [@"LISTENER_TITLE_" stringByAppendingString:listenerName], Localize(bundle, unlocalized, unlocalized) ?: listenerName);
		} else {
			return [(id<LAVirtualListener>)[self listenerForName:listenerName] activator:self requiresLocalizedTitleForListenerName:listenerName];
		}
	} else {
		return [self _performRemoteMessage:_cmd withObject:listenerName];
	}
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"] ?: @"";
	if ([unlocalized length] == 0)
		return @"";
	return Localize(_mainBundle, [@"EVENT_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(bundle, unlocalized, unlocalized) ?: @"");
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName
{
	if (InSpringBoard) {
		NSBundle *bundle = [_listenerData objectForKey:listenerName];
		if (bundle) {
			NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"] ?: @"";
			if ([unlocalized length] == 0)
				return @"";
			return Localize(_mainBundle, [@"LISTENER_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(bundle, unlocalized, unlocalized));
		} else {
			return [(id<LAVirtualListener>)[self listenerForName:listenerName] activator:self requiresLocalizedGroupForListenerName:listenerName];
		}
	} else {
		return [self _performRemoteMessage:_cmd withObject:listenerName];
	}
}

- (NSString *)localizedDescriptionForEventMode:(NSString *)eventMode
{
	if ([eventMode isEqual:LAEventModeSpringBoard])
		return Localize(_mainBundle, @"MODE_DESCRIPTION_springboard", @"When SpringBoard icons are visible");
	if ([eventMode isEqual:LAEventModeApplication])
		return Localize(_mainBundle, @"MODE_DESCRIPTION_application", @"When an application is visible");
	if ([eventMode isEqual:LAEventModeLockScreen])
		return Localize(_mainBundle, @"MODE_DESCRIPTION_lockscreen", @"When is locked and lock screen is visible");
	return Localize(_mainBundle, @"MODE_DESCRIPTION_all", @"");
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"description"];
	if (unlocalized)
		return Localize(_mainBundle, [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized));
	NSString *key = [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName];
	NSString *result = Localize(_mainBundle, key, nil);
	return [result isEqualToString:key] ? nil : result;
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName
{
	NSBundle *bundle = [_listenerData objectForKey:listenerName];
	if (bundle) {
		NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"description"];
		if (unlocalized)
			return Localize(_mainBundle, [@"LISTENER_DESCRIPTION_" stringByAppendingString:listenerName], Localize(bundle, unlocalized, unlocalized));
		NSString *key = [@"LISTENER_DESCRIPTION_" stringByAppendingString:listenerName];
		NSString *result = Localize(_mainBundle, key, nil);
		return [result isEqualToString:key] ? nil : result;
	}
	return [(id<LAVirtualListener>)[self listenerForName:listenerName] activator:self requiresLocalizedDescriptionForListenerName:listenerName];
}

@end
