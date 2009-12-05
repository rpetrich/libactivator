#import "libactivator.h"

#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>

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
	return [NSString stringWithFormat:@"<%s name=%@ handled=%s %p>", class_getName([self class]), _name, _handled, self];
}

@end

static LAActivator *sharedActivator;

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[LAActivator sharedInstance] reloadPreferences];
}

@implementation LAActivator

+ (LAActivator *)sharedInstance
{
	if (!sharedActivator)
		sharedActivator = [[LAActivator alloc] init];
	return sharedActivator;
}

- (id)init
{
	if ((self = [super init])) {
		_listeners = [[NSMutableDictionary alloc] init];
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

- (void)reloadPreferences;
{
	[_preferences release];
	_preferences = nil;
}

- (id<LAListener>)listenerForEvent:(LAEvent *)event
{
	NSString *preferenceName = [@"LAEventListener-" stringByAppendingString:[event name]];
	if (!_preferences)
		_preferences = [[NSDictionary alloc] initWithContentsOfFile:@"/User/Library/Preferences/libactivator.plist"];
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
}

- (void)unregisterListenerWithName:(NSString *)name
{
	[_listeners removeObjectForKey:name];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s listeners=%@ %p>", class_getName([self class]), _listeners, self];
}

@end
