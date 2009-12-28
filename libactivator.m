#import "libactivator.h"

#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>

#include <sys/stat.h>
#include <notify.h>

NSString * const LAActivatorSettingsFilePath = @"/User/Library/Caches/LibActivator/libactivator.plist";

@implementation LAEvent

+ (id)eventWithName:(NSString *)name
{
	return [[[self alloc] initWithName:name] autorelease];
}

- (id)initWithName:(NSString *)name
{
	if ((self = [super init])) {
		_name = [name copy];
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[super dealloc];
}

- (NSString *)name
{
	return _name;
}

- (BOOL)isHandled
{
	return _handled;
}

- (void)setHandled:(BOOL)isHandled;
{
	_handled = isHandled;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s name=%@ handled=%s %p>", class_getName([self class]), _name, _handled?"YES":"NO", self];
}

@end

static LAActivator *sharedActivator;

@interface LAActivator ()
- (void)_loadPreferences;
- (void)_savePreferences;
- (void)_reloadPreferences;
@end

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[LAActivator sharedInstance] _reloadPreferences];
}

@implementation LAActivator

+ (LAActivator *)sharedInstance
{
	return sharedActivator;
}

+ (void)load
{
	sharedActivator = [[LAActivator alloc] init];
}

- (id)init
{
	if ((self = [super init])) {
		// Does not retain values!
		_listeners = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
		// Register for notification
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, PreferencesChangedCallback, CFSTR("libactivator.preferenceschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
	return self;
}

- (void)dealloc
{
	CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, CFSTR("libactivator.preferencechanged"), NULL);
	[_preferences release];
	[_listeners release];
	[super dealloc];
}

- (void)_reloadPreferences
{
	[_preferences release];
	_preferences = nil;
}

- (void)_loadPreferences
{
	if (!_preferences) {
		if ((_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:LAActivatorSettingsFilePath]))
			return;
		if ((_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/User/Library/Preferences/libactivator.plist"]))
			return;
		_preferences = [[NSMutableDictionary alloc] init];
	}
}

- (void)_savePreferences
{
	if (_preferences) {
		CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)LAActivatorSettingsFilePath, kCFURLPOSIXPathStyle, NO);
		CFWriteStreamRef stream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, url);
		CFRelease(url);
		CFWriteStreamOpen(stream);
		CFPropertyListWriteToStream((CFPropertyListRef)_preferences, stream, kCFPropertyListBinaryFormat_v1_0, NULL);
		CFWriteStreamClose(stream);
		CFRelease(stream);
		chmod([LAActivatorSettingsFilePath UTF8String], S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
		notify_post("libactivator.preferenceschanged");
	}
}

- (id<LAListener>)listenerForEvent:(LAEvent *)event
{
	[self _loadPreferences];
	NSString *preferenceName = [@"LAEventListener-" stringByAppendingString:[event name]];
	NSString *listenerName = [_preferences objectForKey:preferenceName];
	return [_listeners objectForKey:listenerName];
}

- (void)sendEventToListener:(LAEvent *)event
{
	id<LAListener> listener = [self listenerForEvent:event];
	if ([listener respondsToSelector:@selector(activator:receiveEvent:)])
		[listener activator:self receiveEvent:event];
}

- (void)sendAbortToListener:(LAEvent *)event
{
	id<LAListener> listener = [self listenerForEvent:event];
	if ([listener respondsToSelector:@selector(activator:abortEvent:)])
		[listener activator:self abortEvent:event];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name
{
	[_listeners setObject:listener forKey:name];
	[self _loadPreferences];
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
	[self _loadPreferences];
	return [[_preferences objectForKey:[@"LAHasSeenListener-" stringByAppendingString:name]] boolValue];
}

- (BOOL)assignEventName:(NSString *)eventName toListenerWithName:(NSString *)listenerName
{
	[self _loadPreferences];
	NSString *preferenceName = [@"LAEventListener-" stringByAppendingString:eventName];
	NSString *currentListenerName = [_preferences objectForKey:preferenceName];
	if (![currentListenerName isEqualToString:listenerName]) {
		if (![[[self infoForListenerWithName:currentListenerName] objectForKey:@"sticky"] boolValue]) {
			[_preferences setObject:listenerName forKey:preferenceName];
			[self _savePreferences];
			return YES;
		}
	}
	return NO;
}

- (void)unassignEventName:(NSString *)eventName
{
	[self _loadPreferences];
	NSString *preferenceName = [@"LAEventListener-" stringByAppendingString:eventName];	
	if ([_preferences objectForKey:preferenceName]) {
		[_preferences removeObjectForKey:preferenceName];
		[self _savePreferences];
	}
}

- (NSString *)assignedListenerNameForEventName:(NSString *)eventName
{
	[self _loadPreferences];
	return [_preferences objectForKey:[@"LAEventListener-" stringByAppendingString:eventName]];
}

- (NSArray *)availableEventNames
{
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Activator/Events" error:NULL])
		if (![fileName hasPrefix:@"."])
			[result addObject:fileName];
	return result;
}

- (NSDictionary *)infoForEventWithName:(NSString *)name
{
	return [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/Library/Activator/Events/%@/Info.plist", name]];
}

- (NSArray *)availableListenerNames
{
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Activator/Listeners" error:NULL])
		if (![fileName hasPrefix:@"."])
			[result addObject:fileName];
	return result;
}

- (NSDictionary *)infoForListenerWithName:(NSString *)name
{
	return [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/Library/Activator/Listeners/%@/Info.plist", name]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s listeners=%@ %p>", class_getName([self class]), _listeners, self];
}

@end
