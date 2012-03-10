#import "libactivator-private.h"

#import <CoreFoundation/CoreFoundation.h>

@implementation NSObject(LAListener)

- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode
{
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	[self activator:activator receiveEvent:event];
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	[self activator:activator abortEvent:event];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	NSString *unlocalized = ListenerDictionaryValue(listenerName, @"title") ?: listenerName;
	return Localize(activatorBundle, [@"LISTENER_TITLE_" stringByAppendingString:listenerName], Localize(ListenerBundle(listenerName), unlocalized, unlocalized) ?: listenerName);
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	NSString *unlocalized = ListenerDictionaryValue(listenerName, @"description");
	if (unlocalized)
		return Localize(activatorBundle, [@"LISTENER_DESCRIPTION_" stringByAppendingString:listenerName], Localize(ListenerBundle(listenerName), unlocalized, unlocalized));
	NSString *key = [@"LISTENER_DESCRIPTION_" stringByAppendingString:listenerName];
	NSString *result = Localize(activatorBundle, key, nil);
	return [result isEqualToString:key] ? nil : result;
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	NSString *unlocalized = ListenerDictionaryValue(listenerName, @"group") ?: @"";
	if ([unlocalized length] == 0)
		return @"";
	return Localize(activatorBundle, [@"LISTENER_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(ListenerBundle(listenerName), unlocalized, unlocalized));
}
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)name
{
	return ListenerDictionaryValue(name, @"requires-event");
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)name
{
	return ListenerDictionaryValue(name, @"compatible-modes");
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName
{
	NSBundle *bundle = ListenerBundle(listenerName);
	return [NSData dataWithContentsOfFile:[bundle pathForResource:@"icon" ofType:@"png"]]
		?: [NSData dataWithContentsOfFile:[bundle pathForResource:@"Icon" ofType:@"png"]];
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	NSData *result;
	CGFloat scaleCopy = *scale;
	if (scaleCopy != 1.0f) {
		NSBundle *bundle = ListenerBundle(listenerName);
		result = [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon-fallback@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon-fallback@%.0fx", scaleCopy] ofType:@"png"]];
		if (result)
			return result;
	}
	result = [self activator:activator requiresIconDataForListenerName:listenerName];
	if (result)
		*scale = 1.0f;
	return result;
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName
{
	NSBundle *bundle = ListenerBundle(listenerName);
	return [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"icon-small" ofType:@"png"]]
		?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"Icon-small" ofType:@"png"]]
		?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"icon-small-fallback" ofType:@"png"]]
		?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"Icon-small-fallback" ofType:@"png"]];
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	NSData *result;
	CGFloat scaleCopy = *scale;
	if (scaleCopy != 1.0f) {
		NSBundle *bundle = ListenerBundle(listenerName);
		result = [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon-small@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon-small@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon-small-fallback@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon-small-fallback@%.0fx", scaleCopy] ofType:@"png"]];
		if (result)
			return result;
	}
	result = [self activator:activator requiresSmallIconDataForListenerName:listenerName];
	if (result)
		*scale = 1.0f;
	return result;
}
- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	return nil;
}
- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	return nil;
}
- (NSNumber *)activator:(LAActivator *)activator requiresIsCompatibleWithEventName:(NSString *)eventName listenerName:(NSString *)listenerName
{
	return [[ListenerBundle(listenerName) objectForInfoDictionaryKey:@"incompatible-events"] containsObject:eventName]
		? (NSNumber *)kCFBooleanFalse
		: (NSNumber *)kCFBooleanTrue;
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
	return ListenerDictionaryValue(listenerName, key);
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
}
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
}
- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event
{
}
- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
}
@end
