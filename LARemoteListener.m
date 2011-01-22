#import "libactivator-private.h"

#import <CaptainHook/CaptainHook.h>

static CPDistributedMessagingCenter *springboardCenter;
static LARemoteListener *sharedInstance;

@implementation LARemoteListener

+ (void)initialize
{
	springboardCenter = [[CPDistributedMessagingCenter centerNamed:@"libactivator.springboard"] retain];
	sharedInstance = [[self alloc] init];
}

+ (LARemoteListener *)sharedInstance
{
	return sharedInstance;
}

- (void)_performRemoteSelector:(SEL)selector withEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:listenerName, @"listenerName", [NSKeyedArchiver archivedDataWithRootObject:event], @"event", nil];
	NSData *result = [[springboardCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo] objectForKey:@"result"];
	LAEvent *newEvent = [NSKeyedUnarchiver unarchiveObjectWithData:result];
	[event setHandled:[newEvent isHandled]];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	[self _performRemoteSelector:_cmd withEvent:event forListenerName:listenerName];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	[self _performRemoteSelector:_cmd withEvent:event forListenerName:listenerName];
}

- (id)_performRemoteSelector:(SEL)selector withObject:(id)object withObject:(id)object2 forListenerName:(NSString *)listenerName
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:listenerName, @"listenerName", object, @"object", object2, @"object2", nil];
	return [[springboardCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo] objectForKey:@"result"];
}

- (id)_performRemoteSelector:(SEL)selector withObject:(id)object withScalePtr:(CGFloat *)scale forListenerName:(NSString *)listenerName
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:listenerName, @"listenerName", [NSNumber numberWithFloat:*scale], @"scale", object, @"object", nil];
	NSDictionary *result = [springboardCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	*scale = [[result objectForKey:@"scale"] floatValue];
	return [result objectForKey:@"result"];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName
{
	// Read data without CPDistributedMessagingCenter if possible
	return [super activator:activator requiresIconDataForListenerName:listenerName]
		?: [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withScalePtr:scale forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName
{
	// Read data without CPDistributedMessagingCenter if possible
	return [super activator:activator requiresSmallIconDataForListenerName:listenerName]
		?: [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withScalePtr:scale forListenerName:listenerName];
}
- (NSNumber *)activator:(LAActivator *)activator requiresIsCompatibleWithEventName:(NSString *)eventName listenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:eventName withObject:listenerName forListenerName:listenerName];
}
- (id)activator:(LAActivator *)activator requiresInfoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:key withObject:listenerName forListenerName:listenerName];
}

@end
