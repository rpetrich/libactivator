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
#include <execinfo.h>
#include <notify.h>

NSString * const LAEventModeSpringBoard = @"springboard";
NSString * const LAEventModeApplication = @"application";
NSString * const LAEventModeLockScreen  = @"lockscreen";

LAActivator *LASharedActivator;

CHDeclareClass(SBIconController);

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

static inline void LAInvalidSpringBoardOperation(SEL _cmd)
{
	CHAutoreleasePoolForScope();
	void *symbols[2];
	size_t size = backtrace(symbols, 2);
	NSString *culprit;
	if (size == 2) {
		char **strings = backtrace_symbols(symbols, size);
		NSString *description = [NSString stringWithUTF8String:strings[1]];
		free(strings);
		culprit = [[[description componentsSeparatedByString:@" "] objectAtIndex:3] stringByDeletingPathExtension];
	} else {
		culprit = nil;
	}
	[LASharedActivator performSelector:@selector(apiFailWithCulprit:) withObject:culprit afterDelay:0.0f];
	NSLog(@"Activator: %@ called -[LAActivator %s] from outside SpringBoard. This is invalid!", culprit, _cmd);
}

#define LAInvalidSpringBoardOperation() LAInvalidSpringBoardOperation(_cmd)

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
	if ((self = [super init])) {
		_availableEventModes = [[NSArray arrayWithObjects:LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen, nil] retain];
		// Caches
		_cachedListenerGroups = [[NSMutableDictionary alloc] init];
		_cachedListenerTitles = [[NSMutableDictionary alloc] init];
		_cachedListenerSmallIcons = [[NSMutableDictionary alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	[_cachedListenerSmallIcons release];
	[_cachedListenerTitles release];
	[_cachedListenerGroups release];
	[_availableEventModes release];
	[super dealloc];
}

- (void)didReceiveMemoryWarning
{
	[_cachedListenerSmallIcons removeAllObjects];
	[_cachedListenerTitles removeAllObjects];
	[_cachedListenerGroups removeAllObjects];
}

- (LAActivatorVersion)version
{
	return LAActivatorVersion_1_5;
}

- (BOOL)isRunningInsideSpringBoard
{
	return NO;
}

- (void)apiFailWithCulprit:(NSString *)culprit
{
	UIAlertView *av = [[UIAlertView alloc] init];
	av.title = @"Invalid Operation";
	av.message = [culprit stringByAppendingString:@" has called an Activator API improperly from outside SpringBoard.\nContact the developer."];
	[av addButtonWithTitle:@"OK"];
	[av show];
	[av release];
}

// Preferences

- (void)_resetPreferences
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	[messagingCenter sendMessageName:@"resetPreferences" userInfo:nil];
}

- (NSDictionary *)_getObjectForPreferenceFromMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo
{
	id result = [self _getObjectForPreference:[userInfo objectForKey:@"preference"]];
	if (result)
		return [NSDictionary dictionaryWithObject:result forKey:@"value"];
	else
		return [NSDictionary dictionary];
}

- (id)_getObjectForPreference:(NSString *)preference
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	NSDictionary *response = [messagingCenter sendMessageAndReceiveReplyName:@"getObjectForPreference" userInfo:[NSDictionary dictionaryWithObject:preference forKey:@"preference"]];
	return [response objectForKey:@"value"];
}

- (void)_setObject:(id)value forPreference:(NSString *)preference
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	[messagingCenter sendMessageName:@"setObjectForPreference" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:preference, @"preference", value, @"value", nil]];
}

- (id)_performRemoteMessage:(SEL)selector withObject:(id)withObject
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:withObject, @"withObject", nil];
	NSDictionary *response = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	return [response objectForKey:@"result"];
}

- (id)_performRemoteMessage:(SEL)selector withObject:(id)withObject withObject:(id)withObject2
{
	CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:withObject, @"withObject", withObject2, @"withObject2", nil];
	NSDictionary *response = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	return [response objectForKey:@"result"];
}

// Sending Events

- (BOOL)isInProtectedApplication
{
	SBApplication *application = [[LAApplicationListener sharedInstance] topApplication];
	NSString *displayIdentifier = [application displayIdentifier];
	if (![displayIdentifier isEqualToString:@"com.saurik.Cydia"])
		return NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Cydia.app/MobileCydia"]) {
	    int notify_token;
		if (notify_register_check("com.saurik.Cydia.status", &notify_token) != NOTIFY_STATUS_OK)
			return NO;
		uint64_t state = 1;
		notify_get_state(notify_token, &state);
		notify_cancel(notify_token);
    	if (state == 0)
    		return NO;
	}
	return ![[self _getObjectForPreference:@"LAIgnoreProtectedApplications"] boolValue];
}

- (id<LAListener>)listenerForEvent:(LAEvent *)event
{
	return [self listenerForName:[self assignedListenerNameForEvent:event]];
}

- (void)sendEventToListener:(LAEvent *)event
{
	if ([self isInProtectedApplication])
		return;
	NSString *listenerName = [self assignedListenerNameForEvent:event];
	if ([self listenerWithName:listenerName isCompatibleWithEventName:[event name]]) {
		id<LAListener> listener = [self listenerForName:listenerName];
		[listener activator:self receiveEvent:event forListenerName:listenerName];
		if ([event isHandled])
			for (NSString *other in [self availableListenerNames])
				if (![other isEqualToString:listenerName])
					[[self listenerForName:other] activator:self otherListenerDidHandleEvent:event forListenerName:other];
	}
#ifdef DEBUG
	NSLog(@"Activator: sendEventToListener:%@ (listener=%@)", event, listenerName);
#endif
}

- (void)sendAbortToListener:(LAEvent *)event
{
	NSString *listenerName = [self assignedListenerNameForEvent:event];
	if ([self listenerWithName:listenerName isCompatibleWithEventName:[event name]])
		[[self listenerForName:listenerName] activator:self abortEvent:event forListenerName:listenerName];
#ifdef DEBUG
	NSLog(@"Activator: sendAbortToListener:%@ (listener=%@)", event, listenerName);
#endif
}

- (void)sendDeactivateEventToListeners:(LAEvent *)event
{
	BOOL handled = [event isHandled];
	for (NSString *listenerName in [self availableListenerNames]) {
		[[self listenerForName:listenerName] activator:self receiveDeactivateEvent:event forListenerName:listenerName];
		handled |= [event isHandled];
	}
	[event setHandled:handled];
#ifdef DEBUG
	NSLog(@"Activator: sendDeactivateEventToListeners:%@", event);
#endif
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
		for (NSString *mode in _availableEventModes) {
			NSString *prefName = ListenerKeyForEventNameAndMode(eventName, mode);
			if ([self _getObjectForPreference:prefName])
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
	return [self _performRemoteMessage:_cmd withObject:nil];
}

- (BOOL)eventWithNameIsHidden:(NSString *)name
{
	return [[self _performRemoteMessage:_cmd withObject:name] boolValue];
}

- (NSArray *)compatibleModesForEventWithName:(NSString *)name
{
	return [self _performRemoteMessage:_cmd withObject:name];
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
	return [[self _performRemoteMessage:_cmd withObject:eventName withObject:eventMode] boolValue];
}

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName
{
	LAInvalidSpringBoardOperation();
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName
{
	LAInvalidSpringBoardOperation();
}

// Listeners

- (NSArray *)availableListenerNames
{
	return [self _performRemoteMessage:_cmd withObject:nil];
}

- (NSDictionary *)_cachedAndSortedListeners
{
	return [self _performRemoteMessage:_cmd withObject:nil];
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
	return [UIImage imageWithData:[[self listenerForName:listenerName] activator:self requiresIconDataForListenerName:listenerName]];
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName
{
	UIImage *result = [_cachedListenerSmallIcons objectForKey:listenerName];
	if (!result) {
		if ([UIImage respondsToSelector:@selector(imageWithData:scale:)]) {
			CGFloat scale = [[UIScreen mainScreen] scale];
			NSData *data = [[self listenerForName:listenerName] activator:self requiresSmallIconDataForListenerName:listenerName scale:&scale];
			result = [UIImage imageWithData:data scale:scale];
		} else {
			NSData *data = [[self listenerForName:listenerName] activator:self requiresSmallIconDataForListenerName:listenerName];
			result = [UIImage imageWithData:data];
		}
		if (result)
			[_cachedListenerSmallIcons setObject:result forKey:listenerName];
	}
	return result;
}

// Event Modes

- (NSArray *)availableEventModes
{
	return _availableEventModes;
}

- (NSString *)currentEventMode
{
	return [self _performRemoteMessage:_cmd withObject:nil];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<LAActivator listeners=%@ events=%@ modes=%@ %p>", [self availableListenerNames], [self availableEventNames], [self availableEventModes], self];
}

- (NSURL *)moreActionsURL
{
	UIDevice *device = [UIDevice currentDevice];
	NSInteger idiom = [device respondsToSelector:@selector(idiom)] ? [device idiom] : 0;
	NSString *url = [NSString stringWithFormat:@"http://rpetri.ch/cydia/activator/actions/?udid=%@&idiom=%d&version=%@&activator=%d", device.uniqueIdentifier, idiom, device.systemVersion, [LASharedActivator version]];
	return [NSURL URLWithString:url];
}

- (NSURL *)adPaneURL
{
	UIDevice *device = [UIDevice currentDevice];
	NSInteger idiom = [device respondsToSelector:@selector(idiom)] ? [device idiom] : 0;
	NSString *url = [NSString stringWithFormat:@"http://rpetri.ch/cydia/activator/ads/?udid=%@&idiom=%d&version=%@&activator=%d", device.uniqueIdentifier, idiom, device.systemVersion, [LASharedActivator version]];
	return [NSURL URLWithString:url];
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
	return [self _performRemoteMessage:_cmd withObject:eventName];
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
	return [self _performRemoteMessage:_cmd withObject:eventName];
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
	return [self _performRemoteMessage:_cmd withObject:eventName];
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName
{
	return [[self listenerForName:listenerName] activator:self requiresLocalizedDescriptionForListenerName:listenerName];
}

@end

CHConstructor
{
	CHAutoreleasePoolForScope();
	activatorBundle = [[NSBundle alloc] initWithPath:SCRootPath(@"/Library/Activator")];
	if (CHLoadLateClass(SBIconController)) {
		// Cache listener data
		listenerData = [[NSMutableDictionary alloc] init];
		NSString *listenersPath = SCRootPath(@"/Library/Activator/Listeners");
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:listenersPath error:NULL])
			if (![fileName hasPrefix:@"."])
				[listenerData setObject:[NSBundle bundleWithPath:[listenersPath stringByAppendingPathComponent:fileName]] forKey:fileName];
		LASharedActivator = [[LASpringBoardActivator alloc] init];
	} else {
		LASharedActivator = [[LAActivator alloc] init];
	}
}
