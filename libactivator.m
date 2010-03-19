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
CHDeclareClass(SBIconModel);
CHDeclareClass(SBApplicationController);
CHDeclareClass(SBApplication);
CHDeclareClass(SBDisplayStack);

static LAActivator *sharedActivator;

@interface NSObject(LAListener)
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode;
- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event;
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
@end

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
	if ([activator currentEventMode] == LAEventModeSpringBoard) {
		[activator performSelector:@selector(_activateApplication:) withObject:_application afterDelay:0.0f];
		[event setHandled:YES];
	} else if ([activator _activateApplication:_application]) {
		[event setHandled:YES];
	}
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
	if ((self = [super init])) {
		// Detect if we're inside SpringBoard
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
			CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
			[messagingCenter runServerOnCurrentThread];
			// Remote messages to id<LAListener>
			[messagingCenter registerForMessageName:@"activator:receiveEvent:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:abortEvent:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
			[messagingCenter registerForMessageName:@"activator:otherListenerDidHandleEvent:" target:self selector:@selector(_handleRemoteListenerMessage:withUserInfo:)];
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
		// Applications aren't retained
		_applications = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
		// Load Main Bundle
		_mainBundle = [[NSBundle alloc] initWithPath:@"/Library/Activator"];
	}
	return self;
}

- (void)dealloc
{
	[_cachedAndSortedListeners release];
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

- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	NSString *listenerName = [userInfo objectForKey:@"listenerName"];
	id<LAListener> listener = [self listenerForName:listenerName];
	LAEvent *event = [NSKeyedUnarchiver unarchiveObjectWithData:[userInfo objectForKey:@"event"]];
	[listener performSelector:NSSelectorFromString(message) withObject:self withObject:event];
	id result = [NSKeyedArchiver archivedDataWithRootObject:event];
	return [NSDictionary dictionaryWithObject:result forKey:@"result"];
}

- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo
{
	id withObject = [userInfo objectForKey:@"withObject"];
	id result = [self performSelector:NSSelectorFromString(message) withObject:withObject withObject:nil];
	if (!result)
		return nil;
	return [NSDictionary dictionaryWithObject:result forKey:@"result"];
}

- (id)_performRemoteMessage:(SEL)selector withObject:(id)withObject
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:withObject, @"withObject", nil];
	NSDictionary *response = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	return [response objectForKey:@"result"];
}

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

- (BOOL)_activateApplication:(SBApplication *)application
{
	SBApplication *springBoard = [CHSharedInstance(SBApplicationController) springBoard];
	application = application ?: springBoard;
    SBApplication *oldApplication = [SBWActiveDisplayStack topApplication] ?: springBoard;
    if (oldApplication == application)
    	return NO;
	SBIcon *icon = [CHSharedInstance(SBIconModel) iconForDisplayIdentifier:[application displayIdentifier]];
	if (icon && [self currentEventMode] == LAEventModeSpringBoard) {
		[icon launch];
	} else {
		if (oldApplication == springBoard) {
			[application setDisplaySetting:0x4 flag:YES];
			[SBWPreActivateDisplayStack pushDisplay:application];
		} else if (application == springBoard) {
			[oldApplication setDeactivationSetting:0x2 flag:YES];
			[SBWActiveDisplayStack popDisplay:oldApplication];
			[SBWSuspendingDisplayStack pushDisplay:oldApplication];
		} else {
			[application setDisplaySetting:0x4 flag:YES];
			[application setActivationSetting:0x40 flag:YES];
			[application setActivationSetting:0x20000 flag:YES];
			[SBWPreActivateDisplayStack pushDisplay:application];
			[oldApplication setDeactivationSetting:0x2 flag:YES];
			[SBWActiveDisplayStack popDisplay:oldApplication];
			[SBWSuspendingDisplayStack pushDisplay:oldApplication];
		}
	}
	return YES;
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
	return [self _performRemoteMessage:_cmd withObject:nil];
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name
{
	return [[_listenerData objectForKey:name] objectForInfoDictionaryKey:key];
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name
{
	return [[[_listenerData objectForKey:name] objectForInfoDictionaryKey:@"requires-event"] boolValue];
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name;
{
	NSBundle *listenerBundle = [_listenerData objectForKey:name];
	if (listenerBundle)
		return [listenerBundle objectForInfoDictionaryKey:@"compatible-modes"] ?: [self availableEventModes];
	else if (InSpringBoard)
		return [_applications objectForKey:name] ? [NSArray arrayWithObjects:LAEventModeSpringBoard, LAEventModeApplication, nil] : [NSArray array];
	else
		return [self _performRemoteMessage:_cmd withObject:name];
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
	if (InSpringBoard) {
		SBApplication *application = [_applications objectForKey:listenerName];
		SBIcon *icon = [CHSharedInstance(SBIconModel) iconForDisplayIdentifier:[application displayIdentifier]];
		return [icon icon] ?: [UIImage imageWithContentsOfFile:[application pathForIcon]];
	}
	// Marshal through SpringBoard by converting to PNG
	return [UIImage imageWithData:[self _performRemoteMessage:@selector(_iconDataForListenerName:) withObject:listenerName]];
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
	if (InSpringBoard) {
		UIImage *result = [self iconForListenerName:listenerName];
		if (!result) {
			SBApplication *application = [_applications objectForKey:listenerName];
			result = [UIImage imageWithContentsOfFile:[application pathForSmallIcon]];
			SBIcon *icon = [CHSharedInstance(SBIconModel) iconForDisplayIdentifier:[application displayIdentifier]];
			result = [icon smallIcon];
			if (!result)
				return nil;
		}
		CGSize size = [result size];
		if (size.width > 29.0f || size.height > 29.0f) {
			size.width = 29.0f;
			size.height = 29.0f;
			result = [result _imageScaledToSize:size interpolationQuality:kCGInterpolationDefault];
		}
		return result;
	}
	// Marshal through SpringBoard by converting to PNG
	return [UIImage imageWithData:[self _performRemoteMessage:@selector(_smallIconDataForListenerName:) withObject:listenerName]];
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
			return [[_applications objectForKey:listenerName] displayName];
		}
	} else {
		return [self _performRemoteMessage:_cmd withObject:listenerName];
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
			NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"] ?: @"";
			return Localize(_mainBundle, [@"LISTENER_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(bundle, unlocalized, unlocalized));
		} else {
			if ([[_applications objectForKey:listenerName] isSystemApplication])
				return Localize(_mainBundle, @"LISTENER_GROUP_TITLE_System Applications", @"System Applications");
			else
				return Localize(_mainBundle, @"LISTENER_GROUP_TITLE_User Applications", @"User Applications");
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
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"description"];
	if (unlocalized)
		return Localize(_mainBundle, [@"LISTENER_DESCRIPTION_" stringByAppendingString:listenerName], Localize(bundle, unlocalized, unlocalized));
	NSString *key = [@"LISTENER_DESCRIPTION_" stringByAppendingString:listenerName];
	NSString *result = Localize(_mainBundle, key, nil);
	return [result isEqualToString:key] ? nil : result;
}

@end

CHOptimizedMethod(8, self, id, SBApplication, initWithBundleIdentifier, NSString *, bundleIdentifier, roleIdentifier, NSString *, roleIdentifier, path, NSString *, path, bundle, id, bundle, infoDictionary, NSDictionary *, infoDictionary, isSystemApplication, BOOL, isSystemApplication, signerIdentity, id, signerIdentity, provisioningProfileValidated, BOOL, validated)
{
	if ((self = CHSuper(8, SBApplication, initWithBundleIdentifier, bundleIdentifier, roleIdentifier, roleIdentifier, path, path, bundle, bundle, infoDictionary, infoDictionary, isSystemApplication, isSystemApplication, signerIdentity, signerIdentity, provisioningProfileValidated, validated))) {
		if (isSystemApplication) {
			NSString *displayIdentifier = [self displayIdentifier];
			if ([displayIdentifier isEqualToString:@"com.apple.DemoApp"] ||
				[displayIdentifier isEqualToString:@"com.apple.fieldtest"] ||
				[displayIdentifier isEqualToString:@"com.apple.springboard"] ||
				[displayIdentifier isEqualToString:@"com.apple.WebSheet"]
			) {
				return self;
			}
			if (![[NSFileManager defaultManager] fileExistsAtPath:[bundle executablePath]]) {
				return self;
			}
		}
		[sharedActivator _addApplication:self];
	}
	return self;
}

CHOptimizedMethod(0, self, void, SBApplication, dealloc)
{
	[sharedActivator _removeApplication:self];
	CHSuper(0, SBApplication, dealloc);
}

CHOptimizedMethod(0, self, id, SBDisplayStack, init)
{
	if ((self = CHSuper(0, SBDisplayStack, init))) {
		if (!displayStacks)
			displayStacks = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
		[displayStacks addObject:self];
	}
	return self;
}

CHOptimizedMethod(0, self, void, SBDisplayStack, dealloc)
{
	[displayStacks removeObject:self];
	CHSuper(0, SBDisplayStack, dealloc);
}

CHConstructor {
	CHLoadLateClass(SBIconController);
	CHLoadLateClass(SBIconModel);
	CHLoadLateClass(SBApplicationController);
	CHLoadLateClass(SBApplication);
	CHHook(8, SBApplication, initWithBundleIdentifier, roleIdentifier, path, bundle, infoDictionary, isSystemApplication, signerIdentity, provisioningProfileValidated);
	CHHook(0, SBApplication, dealloc);
	CHLoadLateClass(SBDisplayStack);
	CHHook(0, SBDisplayStack, init);
	CHHook(0, SBDisplayStack, dealloc);
}
