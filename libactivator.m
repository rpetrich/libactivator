#import "libactivator.h"

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
CHDeclareClass(SBApplication);
CHDeclareClass(SBDisplayStack);

NSMutableArray *displayStacks;
#define SBWPreActivateDisplayStack        (SBDisplayStack *)[displayStacks objectAtIndex:0]
#define SBWActiveDisplayStack             (SBDisplayStack *)[displayStacks objectAtIndex:1]
#define SBWSuspendingDisplayStack         (SBDisplayStack *)[displayStacks objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack (SBDisplayStack *)[displayStacks objectAtIndex:3]

@implementation LAEvent

@synthesize name = _name;
@synthesize mode = _mode;
@synthesize handled = _handled;

+ (id)eventWithName:(NSString *)name
{
	return [[[self alloc] initWithName:name] autorelease];
}

+ (id)eventWithName:(NSString *)name mode:(NSString *)mode
{
	return [[[self alloc] initWithName:name mode:mode] autorelease];
}

- (id)initWithName:(NSString *)name
{
	if ((self = [super init])) {
		_name = [name copy];
	}
	return self;
}

- (id)initWithName:(NSString *)name mode:(NSString *)mode
{
	if ((self = [super init])) {
		_name = [name copy];
		_mode = [mode copy];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init])) {
		_name = [[coder decodeObjectForKey:@"name"] copy];
		_mode = [[coder decodeObjectForKey:@"mode"] copy];
		_handled = [coder decodeBoolForKey:@"handled"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_mode forKey:@"mode"];
	[coder encodeBool:_handled forKey:@"handled"];
}

- (id)copyWithZone:(NSZone *)zone
{
	id result = [[LAEvent allocWithZone:zone] initWithName:_name mode:_mode];
	[result setHandled:_handled];
	return result;
}

- (void)dealloc
{
	[_name release];
	[_mode release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s name=%@ mode=%@ handled=%s %p>", class_getName([self class]), _name, _mode, _handled?"YES":"NO", self];
}

@end

#define ListenerKeyForEventNameAndMode(eventName, eventMode) \
	[NSString stringWithFormat:@"LAEventListener(%@)-%@", (eventMode), (eventName)]
	
#define Localize(bundle, key, value_) ({ \
	NSBundle *_bundle = (bundle); \
	NSString *_key = (key); \
	NSString *_value = (value_); \
	(_bundle) ? [_bundle localizedStringForKey:key value:_value table:nil] : _value; \
})

@interface LARemoteListener : NSObject<LAListener> {
@private
	NSString *_listenerName;
	CPDistributedMessagingCenter *_messagingCenter;
}
@end

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

- (BOOL)respondsToSelector:(SEL)selector
{
	if (selector == @selector(activator:receiveEvent:) ||
		selector == @selector(activator:abortEvent:) ||
		selector == @selector(activator:otherListenerDidHandleEvent:)
	) {
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromSelector(selector), @"selector", _listenerName, @"listenerName", nil];
		NSNumber *result = [[_messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(_cmd) userInfo:userInfo] objectForKey:@"result"];
		return [result boolValue];
	}
	return [super respondsToSelector:selector];
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

- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event
{
	[self _performRemoteSelector:_cmd withEvent:event];
}

@end

@interface LAApplicationListener : NSObject<LAListener> {
@private
	SBApplication *_application;
}
@end

@implementation LAApplicationListener

- (id)initWithApplication:(SBApplication *)application
{
	if ((self = [super init])) {
		_application = [application retain];
	}
	return self;
}

- (void)dealloc
{
	[_application release];
	[super dealloc];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
    SBApplication *oldApplication = [SBWActiveDisplayStack topApplication];
    if (oldApplication == _application)
    	return;
    NSString *oldDisplayIdentifier = [oldApplication displayIdentifier];
	[_application setDisplaySetting:0x4 flag:YES];
	if ([oldDisplayIdentifier isEqualToString:@"com.apple.springboard"] || oldDisplayIdentifier == nil) {
		[SBWPreActivateDisplayStack pushDisplay:_application];
	} else {
		[_application setActivationSetting:0x40 flag:YES];
		[_application setActivationSetting:0x20000 flag:YES];
		[SBWPreActivateDisplayStack pushDisplay:_application];
		if ([[UIApplication sharedApplication] respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
			[[UIApplication sharedApplication] setBackgroundingEnabled:YES forDisplayIdentifier:oldDisplayIdentifier];
		[oldApplication setDeactivationSetting:0x2 flag:YES];
		[SBWActiveDisplayStack popDisplay:oldApplication];
		[SBWSuspendingDisplayStack pushDisplay:oldApplication];
    }
}

@end


static LAActivator *sharedActivator;

@interface LAActivator ()
- (void)_loadPreferences;
- (void)_savePreferences;
- (void)_reloadPreferences;
- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (id)_performRemoteMessage:(SEL)selector arg1:(id)arg1 arg2:(id)arg2;
- (void)_addApplication:(SBApplication *)application;
- (void)_removeApplication:(SBApplication *)application;
@end

#define InSpringBoard (!!_listeners)

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[sharedActivator _reloadPreferences];
}

@implementation LAActivator

#define LoadPreferences() do { if (!_preferences) [self _loadPreferences]; } while(0)

+ (LAActivator *)sharedInstance
{
	return sharedActivator;
}

+ (void)load
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
	if ((self = [super init])) {
		// Detect if we're inside SpringBoard
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
			CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
			[messagingCenter runServerOnCurrentThread];
			// Remote messages to id<LAListener>
			[messagingCenter registerForMessageName:@"respondsToSelector:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:receiveEvent:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:abortEvent:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:otherListenerDidHandleEvent:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			// Remote messages to LAActivator
			[messagingCenter registerForMessageName:@"currentEventMode" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"availableListenerNames" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"iconPathForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"smallIconPathForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"localizedTitleForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"localizedGroupForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"localizedDescriptionForListenerName:" target:self selector:@selector(_handleRemoteMessage:withUserInfo:)];
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
		_applications = [[NSMutableDictionary alloc] init];
		// Load Main Bundle
		_mainBundle = [[NSBundle alloc] initWithPath:@"/Library/Activator"];
	}
	return self;
}

- (void)dealloc
{
	[_cachedListenerNames release];
	[_mainBundle release];
	[_applications release];
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
	BOOL shouldResave = NO;
	if (!(_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:[self settingsFilePath]])) {
		/*if ((_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/User/Library/Preferences/libactivator.plist"])) {
			// Load old path
			[[NSFileManager defaultManager] removeItemAtPath:@"/User/Library/Preferences/libactivator.plist" error:NULL];
			shouldResave = YES;
		} else {*/
			// Create a new preference file
			_preferences = [[NSMutableDictionary alloc] init];
			/*return;
		}*/
	}
	// Convert old-style preferences
	/*for (NSString *eventName in [self availableEventNames]) {
		NSString *oldPref = [@"LAEventListener-" stringByAppendingString:eventName];
		NSString *oldValue = [_preferences objectForKey:oldPref];
		if (oldValue) {
			for (NSString *mode in [self compatibleEventModesForListenerWithName:oldValue])
				[_preferences setObject:oldValue forKey:ListenerKeyForEventNameAndMode(eventName, mode)];
			[_preferences removeObjectForKey:oldPref];
			shouldResave = YES;
		}
	}
	// Save if necessary
	if (shouldResave)
		[self _savePreferences];*/
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

- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	NSString *listenerName = [userInfo objectForKey:@"listenerName"];
	id<LAListener> listener = [self listenerForName:listenerName];
	id result;
	if ([message isEqualToString:@"respondsToSelector:"]) {
		SEL selector = NSSelectorFromString([userInfo objectForKey:@"selector"]);
		result = [listener respondsToSelector:selector] ? (id)kCFBooleanTrue : (id)kCFBooleanFalse;
	} else {
		LAEvent *event = [NSKeyedUnarchiver unarchiveObjectWithData:[userInfo objectForKey:@"event"]];
		[listener performSelector:NSSelectorFromString(message) withObject:self withObject:event];
		result = [NSKeyedArchiver archivedDataWithRootObject:event];
	}
	result = [NSDictionary dictionaryWithObject:result forKey:@"result"];
	return result;
}

// Faster, but only allows property list types
- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	id arg1 = [userInfo objectForKey:@"arg1"];
	id arg2 = [userInfo objectForKey:@"arg2"];
	id result = [self performSelector:NSSelectorFromString(message) withObject:arg1 withObject:arg2];
	if (!result)
		return nil;
	return [NSDictionary dictionaryWithObject:result forKey:@"result"];
}

- (id)_performRemoteMessage:(SEL)selector arg1:(id<NSCoding>)arg1 arg2:(id<NSCoding>)arg2
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:arg1, @"arg1", arg2, @"arg2", nil];
	NSDictionary *response = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	return [response objectForKey:@"result"];
}
/*
// Slower, but allows any types that implement NSCoding to be serialized
- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	id arg1 = [NSKeyedUnarchiver unarchiveObjectWithData:[userInfo objectForKey:@"arg1"]];
	id arg2 = [NSKeyedUnarchiver unarchiveObjectWithData:[userInfo objectForKey:@"arg2"]];
	id result = [self performSelector:NSSelectorFromString(message) withObject:arg1 withObject:arg2];
	if (!result)
		return nil;
	return [NSDictionary dictionaryWithObject:[NSKeyedArchiver archivedDataWithRootObject:result] forKey:@"result"];
}

- (id)_performRemoteMessage:(SEL)selector arg1:(id<NSCoding>)arg1 arg2:(id<NSCoding>)arg2
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSKeyedArchiver archivedDataWithRootObject:arg1], @"arg1", [NSKeyedArchiver archivedDataWithRootObject:arg2], @"arg2", nil];
	NSDictionary *response = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	return [NSKeyedUnarchiver unarchiveObjectWithData:[response objectForKey:@"result"]];
}*/

// SpringBoard Applications

- (void)_addApplication:(SBApplication *)application
{
	NSString *displayIdentifier = [application displayIdentifier];
	if (![_listenerData objectForKey:displayIdentifier])
		[_applications setObject:application forKey:displayIdentifier];
}

- (void)_removeApplication:(SBApplication *)application
{
	[_applications removeObjectForKey:[application displayIdentifier]];
}

// Sending Events

- (id<LAListener>)listenerForEvent:(LAEvent *)event
{
	return [self listenerForName:[self assignedListenerNameForEvent:event]];
}

- (void)sendEventToListener:(LAEvent *)event
{
	id<LAListener> listener = [self listenerForEvent:event];
	if ([listener respondsToSelector:@selector(activator:receiveEvent:)])
		[listener activator:self receiveEvent:event];
	if ([event isHandled])
		for (id<LAListener> other in [_listeners allValues])
			if (other != listener)
				if ([other respondsToSelector:@selector(activator:otherListenerDidHandleEvent:)])
					[other activator:self otherListenerDidHandleEvent:event];
}

- (void)sendAbortToListener:(LAEvent *)event
{
	id<LAListener> listener = [self listenerForEvent:event];
	if ([listener respondsToSelector:@selector(activator:abortEvent:)])
		[listener activator:self abortEvent:event];
}

// Registration of listeners

- (id<LAListener>)listenerForName:(NSString *)name
{
	LoadPreferences();
	if (!InSpringBoard)
		return [[[LARemoteListener alloc] initWithListenerName:name] autorelease];
	SBApplication *app = [_applications objectForKey:name];
	if (app)
		return [[[LAApplicationListener alloc] initWithApplication:app] autorelease];
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
	if (InSpringBoard)
		return [[_listenerData allKeys] arrayByAddingObjectsFromArray:[_applications allKeys]];
	if (_cachedListenerNames)
		return _cachedListenerNames;
	return _cachedListenerNames = [[self _performRemoteMessage:_cmd arg1:nil arg2:nil] retain];
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name
{
	return [[[_listenerData objectForKey:name] objectForInfoDictionaryKey:@"requires-event"] boolValue];
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name;
{
	return [[_listenerData objectForKey:name] objectForInfoDictionaryKey:@"compatible-modes"] ?: [self availableEventModes];
}

- (BOOL)listenerWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
	if (eventMode) {
		NSArray *compatibleModes = [[_listenerData objectForKey:eventName] objectForInfoDictionaryKey:@"compatible-modes"];
		if (compatibleModes)
			return [compatibleModes containsObject:eventMode];
	}
	return YES;
}

- (UIImage *)iconForListenerName:(NSString *)listenerName
{
	return [UIImage imageWithContentsOfFile:[self iconPathForListenerName:listenerName]];
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName
{
	return [UIImage imageWithContentsOfFile:[self smallIconPathForListenerName:listenerName]];
}

- (NSString *)iconPathForListenerName:(NSString *)listenerName
{
	NSString *path = [[_listenerData objectForKey:listenerName] pathForResource:@"icon" ofType:@"png"];
	if (path)
		return path;
	if (InSpringBoard)
		return [[_applications objectForKey:listenerName] pathForIcon];
	return [self _performRemoteMessage:_cmd arg1:listenerName arg2:nil];
}

- (NSString *)smallIconPathForListenerName:(NSString *)listenerName
{
	NSString *path = [[_listenerData objectForKey:listenerName] pathForResource:@"Icon-small" ofType:@"png"];
	if (path)
		return path;
	if (InSpringBoard)
		return [[_applications objectForKey:listenerName] pathForSmallIcon];
	return [self _performRemoteMessage:_cmd arg1:listenerName arg2:nil];
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
		return [self _performRemoteMessage:_cmd arg1:nil arg2:nil];
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
			return [[_applications objectForKey:listenerName] displayName];
		}
	} else {
		return [self _performRemoteMessage:_cmd arg1:listenerName arg2:nil];
	}
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"] ?: @"";
	return Localize(_mainBundle, [@"EVENT_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(bundle, unlocalized, unlocalized) ?: @"");
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName
{
	if (InSpringBoard) {
		NSBundle *bundle = [_listenerData objectForKey:listenerName];
		if (bundle) {
			NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"];
			if (unlocalized)
				return Localize(bundle, unlocalized, unlocalized);
			return @"";
		} else {
			return Localize(bundle, @"Applications", @"Applications");
		}
	} else {
		return [self _performRemoteMessage:_cmd arg1:listenerName arg2:nil];
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
	return Localize(_mainBundle, [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName], @"");
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName
{
	if (InSpringBoard) {
		NSBundle *bundle = [_listenerData objectForKey:listenerName];
		if (bundle) {
			NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"description"];
			return Localize(bundle, unlocalized, unlocalized);
		} else {
			return nil;
		}
	} else {
		return [self _performRemoteMessage:_cmd arg1:listenerName arg2:nil];
	}
}

@end

CHMethod(8, id, SBApplication, initWithBundleIdentifier, NSString *, bundleIdentifier, roleIdentifier, NSString *, roleIdentifier, path, NSString *, path, bundle, id, bundle, infoDictionary, NSDictionary *, infoDictionary, isSystemApplication, BOOL, isSystemApplication, signerIdentity, id, signerIdentity, provisioningProfileValidated, BOOL, validated)
{
	if ((self = CHSuper(8, SBApplication, initWithBundleIdentifier, bundleIdentifier, roleIdentifier, roleIdentifier, path, path, bundle, bundle, infoDictionary, infoDictionary, isSystemApplication, isSystemApplication, signerIdentity, signerIdentity, provisioningProfileValidated, validated))) {
		if (isSystemApplication)
			[sharedActivator _addApplication:self];
	}
	return self;
}

CHMethod(0, void, SBApplication, dealloc)
{
	[sharedActivator _removeApplication:self];
	CHSuper(0, SBApplication, dealloc);
}

CHMethod(0, id, SBDisplayStack, init)
{
	if ((self = CHSuper(0, SBDisplayStack, init))) {
		if (!displayStacks)
			displayStacks = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
		[displayStacks addObject:self];
	}
	return self;
}

CHMethod(0, void, SBDisplayStack, dealloc)
{
	[displayStacks removeObject:self];
	CHSuper(0, SBDisplayStack, dealloc);
}

CHConstructor {
	CHLoadLateClass(SBIconController);
	CHLoadLateClass(SBApplication);
	CHHook(8, SBApplication, initWithBundleIdentifier, roleIdentifier, path, bundle, infoDictionary, isSystemApplication, signerIdentity, provisioningProfileValidated);
	CHHook(0, SBApplication, dealloc);
	CHLoadLateClass(SBDisplayStack);
	CHHook(0, SBDisplayStack, init);
	CHHook(0, SBDisplayStack, dealloc);
}
